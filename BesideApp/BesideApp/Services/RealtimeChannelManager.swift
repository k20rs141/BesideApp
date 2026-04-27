import Foundation
import Supabase

@Observable
@MainActor
final class RealtimeChannelManager {
    var onlineUsers: [PresenceUser] = []

    // Broadcast streams (available after connect)
    private(set) var playStateStream: AsyncStream<JSONObject>?
    private(set) var playEventStream: AsyncStream<JSONObject>?

    private var channel: RealtimeChannelV2?
    private var presenceTask: Task<Void, Never>?

    private let client = SupabaseManager.shared.client

    // MARK: - Connect

    func connect(roomCode: String, userId: String, isHost: Bool, displayName: String?) async {
        await disconnect()

        let ch = client.channel("room:\(roomCode)") {
            $0.presence.key = userId
            $0.broadcast.receiveOwnBroadcasts = false
        }
        channel = ch

        // Register all streams BEFORE subscribe
        let presenceStream = ch.presenceChange()
        let psStream = ch.broadcastStream(event: "play_state")
        let peStream = ch.broadcastStream(event: "play_event")

        try? await ch.subscribeWithError()

        let me = PresenceUser(userId: userId, role: isHost ? "host" : "guest", displayName: displayName)
        try? await ch.track(me)

        playStateStream = psStream
        playEventStream = peStream

        presenceTask = Task { [weak self] in
            for await action in presenceStream {
                guard let self else { return }
                self.applyPresenceAction(action)
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() async {
        presenceTask?.cancel()
        presenceTask = nil
        playStateStream = nil
        playEventStream = nil
        if let ch = channel {
            await ch.unsubscribe()
            channel = nil
        }
        onlineUsers = []
    }

    // MARK: - Reconnect

    func reconnect(roomCode: String, userId: String, isHost: Bool, displayName: String?) async {
        await connect(roomCode: roomCode, userId: userId, isHost: isHost, displayName: displayName)
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
