import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var myRoom: Room?
    var isLoading = false
    var lastError: String?

    private let roomService = RoomService()

    // MARK: - マイルームを取得 (起動時・ボタンタップ時に呼ぶ)

    func loadMyRoom() async {
        guard myRoom == nil else { return } // キャッシュ済みならスキップ
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            myRoom = try await roomService.fetchMyRoom()
        } catch let roomErr as RoomError {
            switch roomErr {
            case .notAuthenticated:
                lastError = "セッションが切れました。サインインし直してください"
            default:
                lastError = "接続できません。リトライしますか?"
            }
            print("[HomeViewModel] loadMyRoom error:", roomErr)
        } catch {
            lastError = "接続できません。リトライしますか?"
            print("[HomeViewModel] loadMyRoom error:", error)
        }
    }

    // MARK: - マイルームを強制リロード

    func reloadMyRoom() async {
        myRoom = nil
        await loadMyRoom()
    }
}
