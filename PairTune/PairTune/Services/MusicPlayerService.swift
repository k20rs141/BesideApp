import Foundation
import MusicKit
import SwiftUI

@Observable
@MainActor
final class MusicPlayerService {
    var currentSong: Song?
    var playbackStatus: MusicPlayer.PlaybackStatus = .stopped
    var currentPlaybackTime: TimeInterval = 0

    var isPlaying: Bool { playbackStatus == .playing }

    private let player = ApplicationMusicPlayer.shared
    private var pollTask: Task<Void, Never>?

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }

    // MARK: - Playback

    /// Apple Music カタログ検索して最初にヒットした曲の ID を返す。
    func searchSongId(title: String, artist: String) async throws -> String? {
        var request = MusicCatalogSearchRequest(term: "\(title) \(artist)", types: [Song.self])
        request.limit = 1
        let response = try await request.response()
        return response.songs.first?.id.rawValue
    }

    /// 指定 songId の曲を time 秒から再生する。5秒以内に開始できなければタイムアウト。
    func load(songId: String, at time: TimeInterval = 0) async throws {
        try await withTimeout(seconds: 5) { [self] in
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id, equalTo: MusicItemID(rawValue: songId)
            )
            let response = try await request.response()
            guard let song = response.items.first else {
                throw MusicLoadError.notFound
            }
            currentSong = song
            player.queue = [song]
            try await player.play()
            if time > 0.5 {
                player.playbackTime = time
            }
            startPolling()
        }
    }

    func play() async throws {
        try await player.play()
        startPolling()
    }

    func pause() {
        player.pause()
    }

    func seek(to time: TimeInterval) {
        player.playbackTime = time
        currentPlaybackTime = time
    }

    func currentTime() -> TimeInterval {
        player.playbackTime
    }

    func stop() {
        player.stop()
        pollTask?.cancel()
        pollTask = nil
        currentSong = nil
        currentPlaybackTime = 0
        playbackStatus = .stopped
    }

    // MARK: - Private

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                currentPlaybackTime = player.playbackTime
                playbackStatus = player.state.playbackStatus
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
}

// MARK: - Errors

enum MusicLoadError: Error {
    case notFound
    case timeout
}

/// `body` を seconds 以内で完了させる。超過したら timeout を throw する。
@MainActor
private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    body: @escaping @MainActor () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await body() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw MusicLoadError.timeout
        }
        guard let result = try await group.next() else {
            throw MusicLoadError.timeout
        }
        group.cancelAll()
        return result
    }
}

// MARK: - Song → Track mapping

extension Song {
    func toTrack() -> Track {
        Track(
            id: id.rawValue,
            title: title,
            artist: artistName,
            album: albumTitle ?? "",
            duration: Int(duration ?? 0),
            gradientStops: [
                .init(color: .pairtuneCoral, location: 0.0),
                .init(color: Color(hex: "4A1D3D"), location: 1.0),
            ],
            dominant: .pairtuneCoral,
            artworkURL: artwork?.url(width: 100, height: 100)
        )
    }
}
