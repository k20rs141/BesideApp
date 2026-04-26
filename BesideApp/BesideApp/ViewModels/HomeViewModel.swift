import Foundation

@Observable
@MainActor
final class HomeViewModel {
    var myRoom: Room?
    var isLoading = false

    private let roomService = RoomService()

    // MARK: - マイルームを取得 (起動時・ボタンタップ時に呼ぶ)

    func loadMyRoom() async {
        guard myRoom == nil else { return } // キャッシュ済みならスキップ
        isLoading = true
        defer { isLoading = false }
        do {
            myRoom = try await roomService.fetchMyRoom()
        } catch {
            print("[HomeViewModel] loadMyRoom error:", error)
        }
    }

    // MARK: - マイルームを強制リロード

    func reloadMyRoom() async {
        myRoom = nil
        await loadMyRoom()
    }
}
