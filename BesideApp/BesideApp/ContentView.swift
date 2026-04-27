import SwiftUI
import Supabase

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var screen: AppScreen = .signIn
    @State private var showCodeEntry: Bool = false
    @State private var showSettings: Bool = false

    @State private var homeViewModel = HomeViewModel()
    @State private var joinViewModel = JoinRoomViewModel()
    @State private var roomViewModel: RoomViewModel?

    var body: some View {
        @Bindable var auth = authViewModel
        ZStack {
            if authViewModel.session == nil {
                SignInView {
                    Task { await authViewModel.signInWithApple() }
                }
                .transition(.opacity)
            } else {
                authenticatedView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.session == nil)
        .onChange(of: authViewModel.session == nil) { _, isSignedOut in
            if isSignedOut {
                screen = .signIn
                homeViewModel = HomeViewModel()
            }
        }
        .alert(
            authViewModel.lastError ?? "",
            isPresented: Binding(
                get: { auth.lastError != nil },
                set: { if !$0 { auth.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { auth.lastError = nil }
        }
    }

    @ViewBuilder
    private var authenticatedView: some View {
        ZStack {
            switch screen {
            case .signIn:
                Color.clear.onAppear { screen = .home }

            case .home:
                HomeView(
                    onCreate: {
                        Task {
                            await homeViewModel.loadMyRoom()
                            guard let room = homeViewModel.myRoom else { return }
                            let vm = RoomViewModel(room: room, isHost: true)
                            roomViewModel = vm
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .room
                            }
                            let userId = authViewModel.session?.user.id.uuidString ?? ""
                            let name = authViewModel.session?.user.userMetadata["full_name"]?.stringValue
                            await vm.enterRoom(userId: userId, displayName: name)
                        }
                    },
                    onJoin: {
                        showCodeEntry = true
                    },
                    onProfile: {
                        showSettings = true
                    }
                )
                .transition(.opacity)
                .sheet(isPresented: $showCodeEntry) {
                    CodeEntrySheet(
                        isPresented: $showCodeEntry,
                        onJoin: {
                            if let room = joinViewModel.joinedRoom {
                                let vm = RoomViewModel(room: room, isHost: false)
                                roomViewModel = vm
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    screen = .room
                                }
                                let userId = authViewModel.session?.user.id.uuidString ?? ""
                                let name = authViewModel.session?.user.userMetadata["full_name"]?.stringValue
                                Task { await vm.enterRoom(userId: userId, displayName: name) }
                            }
                        },
                        validateCode: { code in
                            await joinViewModel.joinRoom(code: code)
                        }
                    )
                }
                .sheet(isPresented: $showSettings) {
                    SettingsSheet {
                        showSettings = false
                        Task { await authViewModel.signOut() }
                    }
                }
                .alert(
                    homeViewModel.lastError ?? "",
                    isPresented: Binding(
                        get: { homeViewModel.lastError != nil },
                        set: { if !$0 { homeViewModel.lastError = nil } }
                    )
                ) {
                    Button("リトライ") {
                        homeViewModel.lastError = nil
                        Task { await homeViewModel.reloadMyRoom() }
                    }
                    Button("キャンセル", role: .cancel) {
                        homeViewModel.lastError = nil
                    }
                }

            case .room:
                if let vm = roomViewModel {
                    RoomViewWrapper(
                        roomViewModel: vm,
                        authViewModel: authViewModel,
                        onExit: {
                            Task {
                                await vm.leaveRoom()
                                roomViewModel = nil
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    screen = .home
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            if screen == .signIn { screen = .home }
        }
        .task(id: authViewModel.session?.user.id) {
            guard authViewModel.session != nil else { return }
            await homeViewModel.loadMyRoom()
        }
    }
}

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    var onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.besideBase.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    Button(role: .destructive) {
                        onSignOut()
                    } label: {
                        Text("ログアウト")
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                    )
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - RoomView Wrapper

private struct RoomViewWrapper: View {
    @Bindable var roomViewModel: RoomViewModel
    let authViewModel: AuthViewModel
    var onExit: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RoomView(
            roomViewModel: roomViewModel,
            isHost: roomViewModel.isHost,
            participantCount: max(1, roomViewModel.onlineParticipants.count),
            guestJoining: !roomViewModel.isHost,
            onExit: onExit,
            onSelectTrack: { _ in }
        )
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let userId = authViewModel.session?.user.id.uuidString ?? ""
                let name = authViewModel.session?.user.userMetadata["full_name"]?.stringValue
                Task {
                    await roomViewModel.reconnect(userId: userId, displayName: name)
                }
            }
        }
        .alert(item: $roomViewModel.roomAlert) { alert in
            switch alert {
            case .appleMusicNotSubscribed:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("設定を開く")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("閉じる"))
                )
            case .reconnectFailed:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("リトライ")) {
                        Task { await roomViewModel.retryConnection() }
                    },
                    secondaryButton: .cancel(Text("閉じる"))
                )
            default:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
