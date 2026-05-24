import SwiftUI
import SwiftData

@main
struct PairTuneApp: App {
    @State private var authViewModel = AuthViewModel()

    // v0.5: オンボーディング完了フラグ等を端末側で管理する。
    // CloudKit 同期は Entitlements で iCloud container を追加すれば自動で有効化される。
    // 未サインイン端末ではローカル動作になる(再表示されうるがスキップ可で実害小)。
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .preferredColorScheme(.dark)
                .task { await authViewModel.restoreSession() }
        }
        .modelContainer(for: AppState.self)
    }
}
