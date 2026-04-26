import Foundation

@Observable
@MainActor
final class RoomViewModel {
    let currentRoom: Room
    let isHost: Bool
    var participants: [RoomParticipant] = []

    private let roomService = RoomService()

    init(room: Room, isHost: Bool) {
        self.currentRoom = room
        self.isHost = isHost
    }

    func leaveRoom() async {
        try? await roomService.leaveRoom(roomId: currentRoom.id, isHost: isHost)
    }
}
