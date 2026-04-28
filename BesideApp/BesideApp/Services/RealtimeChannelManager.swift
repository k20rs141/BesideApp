import Foundation
import Supabase

enum RealtimeConnectionState: Equatable {
    case idle
    case connected
    case reconnecting(attempt: Int)
    case failed
}

@Observable
@MainActor
final class RealtimeChannelManager {
    var onlineUsers: [PresenceUser] = []

    /// 接続状態。RoomViewModel が観察して syncState/roomAlert に反映する。
    var connectionState: RealtimeConnectionState = .idle

    // Broadcast streams (available after connect)
    private(set) var playStateStream: AsyncStream<JSONObject>?
    private(set) var playEventStream: AsyncStream<JSONObject>?

    private var channel: RealtimeChannelV2?
    private var presenceTask: Task<Void, Never>?

    private let client = SupabaseManager.shared.client

    // 最後の接続パラメータ(自動再接続で使う)
    private var lastParams: (roomCode: String, userId: String, isHost: Bool, displayName: String?)?

    private static let maxRetries = 3
    private static let retryDelay: Duration = .seconds(3)

    // MARK: - Connect

    func connect(roomCode: String, userId: String, isHost: Bool, displayName: String?) async {
        await disconnect()
        lastParams = (roomCode, userId, isHost, displayName)

        let connected = await attemptSubscribe(roomCode: roomCode, userId: userId, isHost: isHost, displayName: displayName)
        if connected {
            connectionState = .connected
        } else {
            await runRetryLoop()
        }
    }

    /// チャネル購読の単発試行。成功なら true。
    private func attemptSubscribe(roomCode: String, userId: String, isHost: Bool, displayName: String?) async -> Bool {
        let ch = client.channel("room:\(roomCode)") {
            $0.presence.key = userId
            $0.broadcast.receiveOwnBroadcasts = false
        }
        channel = ch

        let presenceStream = ch.presenceChange()
        let psStream = ch.broadcastStream(event: "play_state")
        let peStream = ch.broadcastStream(event: "play_event")

        do {
            try await ch.subscribeWithError()
        } catch {
            print("[RealtimeChannelManager] subscribe error:", error)
            channel = nil
            return false
        }

        let me = PresenceUser(userId: userId, role: isHost ? "host" : "guest", displayName: displayName)
        try? await ch.track(me)

        playStateStream = psStream
        playEventStream = peStream

        presenceTask?.cancel()
        presenceTask = Task { [weak self] in
            for await action in presenceStream {
                guard let self else { return }
                self.applyPresenceAction(action)
            }
        }
        return true
    }

    /// 3秒 × 3回のリトライ。最終失敗で .failed をセット。
    /// 初回 connect 失敗、または retryFromFailure() からのみ呼ばれる。
    /// 通常運用中の WebSocket 切断は supabase-swift が内部的に再接続するため、
    /// アプリレベルでは介入しない(チャネル再構築すると broadcast 受信が壊れる)。
    private func runRetryLoop() async {
        guard let p = lastParams else {
            connectionState = .failed
            return
        }

        for attempt in 1...Self.maxRetries {
            connectionState = .reconnecting(attempt: attempt)
            try? await Task.sleep(for: Self.retryDelay)

            // チャネルをクリーンアップしてから再試行
            await teardownChannel()

            let ok = await attemptSubscribe(
                roomCode: p.roomCode,
                userId: p.userId,
                isHost: p.isHost,
                displayName: p.displayName
            )
            if ok {
                connectionState = .connected
                return
            }
        }

        connectionState = .failed
    }

    // MARK: - Disconnect

    func disconnect() async {
        await teardownChannel()
        connectionState = .idle
        onlineUsers = []
        lastParams = nil
    }

    private func teardownChannel() async {
        presenceTask?.cancel()
        presenceTask = nil
        playStateStream = nil
        playEventStream = nil
        if let ch = channel {
            await ch.unsubscribe()
            channel = nil
        }
    }

    // MARK: - Reconnect (manual / scenePhase)

    func reconnect(roomCode: String, userId: String, isHost: Bool, displayName: String?) async {
        await connect(roomCode: roomCode, userId: userId, isHost: isHost, displayName: displayName)
    }

    /// アラートのリトライボタンから呼ばれる。
    func retryFromFailure() async {
        guard case .failed = connectionState else { return }
        await runRetryLoop()
    }

    // MARK: - Broadcast send

    func broadcast<T: Codable>(event: String, message: T) async {
        try? await channel?.broadcast(event: event, message: message)
    }

    // MARK: - Private

    private func applyPresenceAction(_ action: any PresenceAction) {
        for presence in action.joins.values {
            if let user = try? presence.decodeState(as: PresenceUser.self) {
                onlineUsers.removeAll { $0.userId == user.userId }
                onlineUsers.append(user)
            }
        }
        for presence in action.leaves.values {
            if let user = try? presence.decodeState(as: PresenceUser.self) {
                onlineUsers.removeAll { $0.userId == user.userId }
            }
        }
    }
}
