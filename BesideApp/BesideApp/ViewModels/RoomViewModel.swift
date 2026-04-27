import Foundation
import MusicKit
import Supabase

@Observable
@MainActor
final class RoomViewModel {
    // MARK: - Room info

    let currentRoom: Room
    let isHost: Bool

    // MARK: - Display state (RoomView が読む)

    var syncState: SyncState = .idle
    var currentTrack: Track?
    var isPaused: Bool = false
    var progress: Int { Int(musicService.currentPlaybackTime) }

    // MARK: - Presence

    let channelManager = RealtimeChannelManager()
    var onlineParticipants: [PresenceUser] { channelManager.onlineUsers }

    // MARK: - Services

    let musicService = MusicPlayerService()
    private let roomService = RoomService()

    // MARK: - Internal

    private(set) var activeSongId: String = ""
    private var hostBroadcastTask: Task<Void, Never>?
    private var stateListenerTask: Task<Void, Never>?
    private var eventListenerTask: Task<Void, Never>?

    // デバッグ用
    var debugLastDriftMs: Double = 0
    var debugLastSeq: Int = 0

    init(room: Room, isHost: Bool) {
        self.currentRoom = room
        self.isHost = isHost
    }

    // MARK: - Lifecycle

    func enterRoom(userId: String, displayName: String?) async {
        _ = await musicService.requestAuthorization()

        await channelManager.connect(
            roomCode: currentRoom.code,
            userId: userId,
            isHost: isHost,
            displayName: displayName
        )

        if isHost {
            startHostBroadcast()
        } else {
            startGuestListeners()
            // ホストがすでに再生中かチェック
            await syncToCurrentRoomState()
        }
    }

    func reconnect(userId: String, displayName: String?) async {
        await channelManager.reconnect(
            roomCode: currentRoom.code,
            userId: userId,
            isHost: isHost,
            displayName: displayName
        )
        if isHost {
            startHostBroadcast()
        } else {
            startGuestListeners()
        }
    }

    func leaveRoom() async {
        hostBroadcastTask?.cancel()
        stateListenerTask?.cancel()
        eventListenerTask?.cancel()
        musicService.stop()
        await channelManager.disconnect()
        try? await roomService.leaveRoom(roomId: currentRoom.id, isHost: isHost)
    }

    // MARK: - Host actions

    /// SearchSheet から曲が選ばれた時に呼ばれる
    func playAsHost(_ track: Track) async {
        syncState = .loading
        currentTrack = track
        isPaused = false

        do {
            // Apple Music カタログで検索
            guard let songId = try await musicService.searchSongId(title: track.title, artist: track.artist) else {
                syncState = .idle
                return
            }
            activeSongId = songId
            try await musicService.load(songId: songId, at: 0)

            // MusicKit Song で Track を上書き (duration を実データに更新)
            if let song = musicService.currentSong {
                currentTrack = song.toTrack()
            }

            syncState = .playing

            // DB に current_song_id を保存 (遅延参加ゲスト用)
            try? await roomService.updateCurrentSong(roomId: currentRoom.id, songId: songId)

            // PlayEvent を即時2連投
            let event = PlayEvent(type: .play, songId: songId, playbackTime: musicService.currentTime())
            await channelManager.broadcast(event: "play_event", message: event)
            await channelManager.broadcast(event: "play_event", message: event)

        } catch {
            print("[RoomViewModel] playAsHost error:", error)
            syncState = .idle
        }
    }

    func togglePlayback() async {
        guard syncState != .idle, syncState != .loading else { return }

        if musicService.isPlaying {
            musicService.pause()
            isPaused = true
            syncState = .paused
            let event = PlayEvent(type: .pause, songId: activeSongId, playbackTime: musicService.currentTime())
            await channelManager.broadcast(event: "play_event", message: event)
            await channelManager.broadcast(event: "play_event", message: event)
        } else {
            try? await musicService.play()
            isPaused = false
            syncState = .playing
            let event = PlayEvent(type: .play, songId: activeSongId, playbackTime: musicService.currentTime())
            await channelManager.broadcast(event: "play_event", message: event)
            await channelManager.broadcast(event: "play_event", message: event)
        }
    }

    // MARK: - Host broadcast loop

    private func startHostBroadcast() {
        hostBroadcastTask?.cancel()
        hostBroadcastTask = Task { [weak self] in
            var seq = 0
            while !Task.isCancelled {
                guard let self else { return }
                if !self.activeSongId.isEmpty {
                    let state = PlayState(
                        songId: self.activeSongId,
                        playbackTime: self.musicService.currentTime(),
                        isPlaying: self.musicService.isPlaying,
                        hostTimestampMs: Int64(Date().timeIntervalSince1970 * 1000),
                        seq: seq
                    )
                    await self.channelManager.broadcast(event: "play_state", message: state)
                }
                seq += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: - Guest listeners

    private func startGuestListeners() {
        stateListenerTask?.cancel()
        eventListenerTask?.cancel()

        guard let psStream = channelManager.playStateStream,
              let peStream = channelManager.playEventStream else { return }

        stateListenerTask = Task { [weak self] in
            for await json in psStream {
                guard let self else { return }
                if let state = try? json.decode(as: PlayState.self) {
                    await self.applyPlayState(state)
                }
            }
        }

        eventListenerTask = Task { [weak self] in
            for await json in peStream {
                guard let self else { return }
                if let event = try? json.decode(as: PlayEvent.self) {
                    await self.applyPlayEvent(event)
                }
            }
        }
    }

    /// ゲスト後入室: DB の current_song_id があれば再生開始
    private func syncToCurrentRoomState() async {
        guard let songId = currentRoom.currentSongId, !songId.isEmpty else { return }
        guard activeSongId != songId else { return }

        activeSongId = songId
        syncState = .loading
        do {
            // 開始位置 0 でロード。最初の PlayState で正確な位置に補正される
            try await musicService.load(songId: songId, at: 0)
            if let song = musicService.currentSong {
                currentTrack = song.toTrack()
            }
            syncState = .playing
        } catch {
            print("[RoomViewModel] syncToCurrentRoomState error:", error)
            syncState = .idle
        }
    }

    // MARK: - PlayState correction (guest)

    private func applyPlayState(_ state: PlayState) async {
        debugLastSeq = state.seq

        // 曲が変わった場合はロード
        if state.songId != activeSongId, !state.songId.isEmpty {
            activeSongId = state.songId
            syncState = .loading
            do {
                let estimatedPos = estimatedHostTime(state)
                try await musicService.load(songId: state.songId, at: max(0, estimatedPos))
                if let song = musicService.currentSong {
                    currentTrack = song.toTrack()
                }
                syncState = state.isPlaying ? .playing : .paused
                isPaused = !state.isPlaying
            } catch {
                print("[RoomViewModel] applyPlayState load error:", error)
                syncState = .idle
            }
            return
        }

        guard !activeSongId.isEmpty else { return }

        // 再生状態の同期
        if state.isPlaying && !musicService.isPlaying {
            try? await musicService.play()
            syncState = .playing
            isPaused = false
        } else if !state.isPlaying && musicService.isPlaying {
            musicService.pause()
            syncState = .paused
            isPaused = true
        }

        // ドリフト補正
        if state.isPlaying {
            let hostPos = estimatedHostTime(state)
            let localPos = musicService.currentTime()
            let drift = hostPos - localPos
            debugLastDriftMs = drift * 1000

            if abs(drift) > 2.0 {
                // 強制 seek
                musicService.seek(to: max(0, hostPos))
                syncState = .outOfSync
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    if self?.syncState == .outOfSync { self?.syncState = .playing }
                }
            } else if abs(drift) > 0.2 {
                // 静かに補正 (100ms バッファ)
                musicService.seek(to: max(0, hostPos + 0.1))
            }
        }
    }

    // MARK: - PlayEvent handler (guest)

    private func applyPlayEvent(_ event: PlayEvent) async {
        switch event.type {
        case .play:
            let sid = event.songId ?? activeSongId
            if !sid.isEmpty && sid != activeSongId {
                activeSongId = sid
                syncState = .loading
                do {
                    try await musicService.load(songId: sid, at: max(0, event.playbackTime))
                    if let song = musicService.currentSong {
                        currentTrack = song.toTrack()
                    }
                    syncState = .playing
                    isPaused = false
                } catch {
                    print("[RoomViewModel] applyPlayEvent load error:", error)
                }
            } else if !activeSongId.isEmpty {
                musicService.seek(to: max(0, event.playbackTime))
                try? await musicService.play()
                syncState = .playing
                isPaused = false
            }

        case .pause:
            musicService.pause()
            musicService.seek(to: max(0, event.playbackTime))
            syncState = .paused
            isPaused = true

        case .skip:
            if let sid = event.songId, !sid.isEmpty {
                activeSongId = sid
                syncState = .loading
                do {
                    try await musicService.load(songId: sid, at: max(0, event.playbackTime))
                    if let song = musicService.currentSong {
                        currentTrack = song.toTrack()
                    }
                    syncState = .playing
                    isPaused = false
                } catch {
                    print("[RoomViewModel] applyPlayEvent skip error:", error)
                }
            }
        }
    }

    // MARK: - Helper

    private func estimatedHostTime(_ state: PlayState) -> TimeInterval {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let elapsed = Double(nowMs - state.hostTimestampMs) / 1000.0
        return state.playbackTime + (state.isPlaying ? elapsed : 0)
    }
}
