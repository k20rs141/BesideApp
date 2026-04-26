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
                        // マイルームを開く
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
            // 認証後にマイルームをバックグラウンドで取得しておく
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
    let roomViewModel: RoomViewModel
    let authViewModel: AuthViewModel
    var onExit: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RoomView(
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
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
