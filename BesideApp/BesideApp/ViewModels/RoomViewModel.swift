import Foundation
import Supabase

@Observable
@MainActor
final class RoomViewModel {
    let currentRoom: Room
    let isHost: Bool
    var participants: [RoomParticipant] = []

    let channelManager = RealtimeChannelManager()

    var onlineParticipants: [PresenceUser] { channelManager.onlineUsers }

    private let roomService = RoomService()

    init(room: Room, isHost: Bool) {
        self.currentRoom = room
        self.isHost = isHost
    }

    // MARK: - Lifecycle

    func enterRoom(userId: String, displayName: String?) async {
        await channelManager.connect(
            roomCode: currentRoom.code,
            userId: userId,
            isHost: isHost,
            displayName: displayName
        )
    }

    func reconnect(userId: String, displayName: String?) async {
        await channelManager.reconnect(
            roomCode: currentRoom.code,
            userId: userId,
            isHost: isHost,
            displayName: displayName
        )
    }

    func leaveRoom() async {
        await channelManager.disconnect()
        try? await roomService.leaveRoom(roomId: currentRoom.id, isHost: isHost)
    }
}
