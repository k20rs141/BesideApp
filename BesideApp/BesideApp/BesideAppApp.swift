import SwiftUI

@main
struct BesideAppApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .preferredColorScheme(.dark)
                .task { await authViewModel.restoreSession() }
        }
    }
}
