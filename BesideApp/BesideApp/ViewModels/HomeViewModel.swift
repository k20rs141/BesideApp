import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var isCreating = false
    var currentRoom: Room?
    var restoredIsHost: Bool = false

    private let roomService = RoomService()

    // MARK: - 起動時: 既存アクティブルームを復元

    func restoreActiveRoomIfNeeded() async {
        do {
            if let result = try await roomService.fetchActiveRoom() {
                currentRoom = result.room
                restoredIsHost = result.isHost
            }
        } catch {
            print("[HomeViewModel] restoreActiveRoom error:", error)
        }
    }

    // MARK: - 新規ルーム作成

    func createRoom() async {
        isCreating = true
        defer { isCreating = false }
        do {
            currentRoom = try await roomService.createRoom()
            restoredIsHost = true
        } catch {
            print("[HomeViewModel] createRoom error:", error)
        }
    }
}
