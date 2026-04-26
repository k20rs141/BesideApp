import Foundation

@Observable
@MainActor
final class JoinRoomViewModel {
    var isValidating = false
    var joinedRoom: Room?

    private let roomService = RoomService()

    /// コードを検証してルームに参加する。
    /// - Returns: エラーメッセージ文字列、成功時は nil
    func joinRoom(code: String) async -> String? {
        isValidating = true
        defer { isValidating = false }
        do {
            joinedRoom = try await roomService.joinRoom(code: code)
            return nil
        } catch let roomErr as RoomError {
            return roomErr.errorDescription
        } catch {
            return "接続エラー。リトライしてください"
        }
    }
}
