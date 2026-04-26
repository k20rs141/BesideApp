import SwiftUI
import Supabase

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var screen: AppScreen = .signIn
    @State private var showCodeEntry: Bool = false
    @State private var isHost: Bool = true
    @State private var participantCount: Int = 2
    @State private var roomViewKey: UUID = UUID()
    @State private var pendingGuestJoin: Bool = false
    @State private var showSettings: Bool = false

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
            if isSignedOut { screen = .signIn }
        }
    }

    @ViewBuilder
    private var authenticatedView: some View {
        ZStack {
            switch screen {
            case .signIn:
                // セッションがある場合は home に即遷移
                Color.clear.onAppear { screen = .home }

            case .home:
                HomeView(
                    onCreate: {
                        isHost = true
                        pendingGuestJoin = false
                        roomViewKey = UUID()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            screen = .room
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
                    CodeEntrySheet(isPresented: $showCodeEntry) {
                        isHost = false
                        pendingGuestJoin = true
                        roomViewKey = UUID()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            screen = .room
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsSheet {
                        showSettings = false
                        Task { await authViewModel.signOut() }
                    }
                }

            case .room:
                RoomViewWrapper(
                    key: roomViewKey,
                    isHost: isHost,
                    participantCount: participantCount,
                    pendingGuestJoin: pendingGuestJoin,
                    onExit: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            screen = .home
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onAppear {
            if screen == .signIn { screen = .home }
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
    let key: UUID
    let isHost: Bool
    let participantCount: Int
    let pendingGuestJoin: Bool
    var onExit: () -> Void

    var body: some View {
        RoomView(
            isHost: isHost,
            participantCount: participantCount,
            guestJoining: pendingGuestJoin,
            onExit: onExit,
            onSelectTrack: { _ in }
        )
        .id(key)
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
}
