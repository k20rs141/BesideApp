import SwiftUI
import SwiftData
import Supabase
import MusicKit

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    // v0.5: オンボーディング完了フラグ (SwiftData)
    // 未完了の間は OnboardingView を表示し、Home/その他には進ませない。
    @Query private var appStates: [AppState]
    @Environment(\.modelContext) private var modelContext

    @State private var showCodeEntry: Bool = false
    @State private var showSettings: Bool = false
    @State private var showPairWaiting: Bool = false

    // v0.5.1 §5.8: Connect Music ゲートウェイ
    // Home から Room へ進む直前に MusicKit 認可 + サブスク状態を確認する
    @State private var connectGate: ConnectGate? = nil

    @State private var homeViewModel = HomeViewModel()
    @State private var pairViewModel = PairViewModel()
    @State private var soloHistoryVM = SoloHistoryViewModel()
    @State private var roomViewModel: RoomViewModel?

    @State private var pendingSendAlert: PairSendAlert?

    /// バックグラウンド復帰時に pendingRequest を再取得するためのフック。
    /// Realtime 購読がスリープ等で取りこぼした申請を必ず拾えるようにする。
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var auth = authViewModel
        ZStack {
            if authViewModel.session == nil {
                SignInView(isProcessing: authViewModel.isLoading) {
                    Task { await authViewModel.signInWithApple() }
                }
                .transition(.opacity)
            } else if !onboardingCompleted {
                // v0.5 §5.0: サインイン直後 / 初回のみ表示
                OnboardingView(
                    myPairingCode: authViewModel.pairingCode,
                    onJoinWithCode: { showCodeEntry = true },
                    onSolo: {
                        // 「まず自分で見てみる」: Home に着地。次の Solo ボタンタップで Solo Room へ進める。
                    },
                    onSkip: {}
                )
                .transition(.opacity)
            } else {
                authenticatedView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.session == nil)
        .animation(.easeInOut(duration: 0.3), value: onboardingCompleted)
        .onChange(of: scenePhase) { _, newPhase in
            // フォアグラウンド復帰時に申請の最新状態を取り直す。Realtime 購読が
            // バックグラウンド中に切れていても、ここで pendingRequest が拾われて
            // ホーム画面上で承認モーダルが立ち上がる。
            guard newPhase == .active, authViewModel.session != nil else { return }
            Task { await pairViewModel.refreshAll() }
        }
        .onChange(of: authViewModel.session?.user.id) { _, newUserId in
            if let uid = newUserId {
                Task { await pairViewModel.start(myUserId: uid.uuidString) }
                // observeAuthState の signedIn パスは loadProfile を呼ばないため、
                // セッションが立ったらここで保険として再ロードする。
                // 既にロード済みなら fetchMyProfile が同じ値を返すだけで冪等。
                Task { await authViewModel.loadProfile() }
            } else {
                Task { await pairViewModel.stop() }
                roomViewModel = nil
                homeViewModel = HomeViewModel()
                soloHistoryVM = SoloHistoryViewModel()
                // ナビゲーション状態をリセット（再サインイン時に設定画面が残らないよう）
                showSettings = false
                showCodeEntry = false
                showPairWaiting = false
            }
        }
        .onChange(of: pairViewModel.sendState) { _, newState in
            switch newState {
            case .waiting:
                // 申請が DB に INSERT 成功した直後 → コード入力 sheet を閉じて
                // 承認待ち fullScreenCover を表示する
                showCodeEntry = false
                showPairWaiting = true
            case .accepted:
                // 相手が承認(activePair も立つ) → 承認待ち画面を閉じる
                showPairWaiting = false
            case .rejected:
                showPairWaiting = false
                pendingSendAlert = PairSendAlert(
                    title: "申請が拒否されました",
                    message: "残念ながら相手はペアリングに同意しませんでした。"
                )
            case .expired:
                showPairWaiting = false
                pendingSendAlert = PairSendAlert(
                    title: "申請の有効期限が切れました",
                    message: "申請から 24 時間が経過したため失効しました。もう一度送信してください。"
                )
            case .error(let msg):
                showPairWaiting = false
                pendingSendAlert = PairSendAlert(title: "申請エラー", message: msg)
            default:
                break
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
        .alert(item: $pendingSendAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    pairViewModel.clearSendState()
                }
            )
        }
        // v0.5.1 §5.8: Connect Music ゲートウェイ
        .fullScreenCover(item: $connectGate) { gate in
            ConnectMusicView(
                state: gate.state,
                intent: gate.intent,
                onReady: {
                    connectGate = nil
                    gate.proceed()
                },
                onLater: {
                    connectGate = nil
                }
            )
        }
    }

    // MARK: - Authenticated root

    @ViewBuilder
    private var authenticatedView: some View {
        @Bindable var pairVM = pairViewModel

        ZStack {
            // ホーム + 設定: NavigationStack
            NavigationStack {
                HomeView(
                    pairingCode: authViewModel.pairingCode,
                    myName: authViewModel.currentProfile?.displayName,
                    partnerName: pairViewModel.partnerProfile?.displayName,
                    myAvatarUrl: authViewModel.currentProfile?.avatarUrl,
                    partnerAvatarUrl: pairViewModel.partnerProfile?.avatarUrl,
                    // MVP: presence 未実装。partnerProfile が解決した時点で online とする。
                    // 将来は Realtime Presence や `last_seen_at` で実装。
                    partnerOnline: pairViewModel.partnerProfile != nil,
                    partnerLastSeen: nil,
                    onShareCode: {},
                    onJoin: { showCodeEntry = true },
                    onListenWithPartner: {
                        gateThenRun(intent: .shared) {
                            Task {
                                guard let pair = pairViewModel.activePair else { return }
                                await homeViewModel.loadSharedRoom(roomId: pair.sharedRoomId)
                                guard let sharedRoom = homeViewModel.sharedRoom else { return }
                                roomViewModel = RoomViewModel(sharedRoomV4: sharedRoom, pairId: pair.id)
                            }
                        }
                    },
                    onSolo: {
                        // v0.5: Solo は Room 起点。Home → Solo ボタン → Solo Room に直行する
                        // (旧 SoloModeView の push 経路は廃止)
                        gateThenRun(intent: .solo) {
                            // 履歴ロードは Room 表示と並行で進めたいが、`async let _` で
                            // 結果を捨てると囲い Task の出口で暗黙キャンセルが走り、
                            // soloHistoryVM 側で CancellationError が出る。
                            // 独立 Task に切り出して投げっぱなしにする(ライフタイムを呼び出し側 Task から切る)。
                            let userId = authViewModel.session?.user.id.uuidString ?? ""
                            let partnerId = pairViewModel.activePair?.partnerUserId(meId: userId.lowercased())
                            let pairId = pairViewModel.activePair?.id
                            Task {
                                await soloHistoryVM.load(
                                    pairId: pairId,
                                    userId: userId,
                                    partnerUserId: partnerId
                                )
                            }
                            Task {
                                await homeViewModel.loadMyRoom()
                                guard let myRoom = homeViewModel.myRoom else { return }
                                roomViewModel = RoomViewModel(myRoom: myRoom)
                            }
                        }
                    },
                    onProfile: { showSettings = true }
                )
                .toolbar(.hidden, for: .navigationBar)
                // 設定: Navigation push（HIG — 階層的ドリルダウン）
                .navigationDestination(isPresented: $showSettings) {
                    ProfileView(
                        authViewModel: authViewModel,
                        pairViewModel: pairViewModel,
                        sharingPairingCode: authViewModel.pairingCode
                    )
                }
                // v0.5: 旧 SoloModeView の push 経路は撤去。Solo は Room 起点に変更され、
                // Home → Solo ボタンが直接 RoomViewModel を生成して RoomView オーバーレイを開く。
                // 文脈画面(SoloContextView)は Room の文脈ボタン → fullScreenCover で開く。
                // コード入力: Modal sheet（HIG — 独立した完結タスク）
                .sheet(isPresented: $showCodeEntry) {
                    CodeEntrySheet(
                        isPresented: $showCodeEntry,
                        submitCode: { code in
                            await pairViewModel.requestPair(targetCode: code)
                        },
                        onRequested: {}
                    )
                }
                // ペア申請中: 承認待ち画面（fullScreenCover）
                // sendState == .waiting の間、A 側に表示。相手の承認(activePair が立つ)で
                // 自動 dismiss → home が paired 状態へ。`requestPair` 直後は code entry の sheet
                // と重なるので、code entry が閉じた後に表示するよう .onChange 監視で開く。
                .fullScreenCover(isPresented: $showPairWaiting) {
                    PairWaitingView(
                        targetCode: nil,
                        expiresAt: pairViewModel.outgoingRequest?.expiresAt,
                        myInitial: String((authViewModel.currentProfile?.displayName ?? "Y").prefix(1)).uppercased(),
                        onCancel: {
                            // 申請を取り消す: cancel_pair_request RPC で DB の status を
                            // 'cancelled' に更新し、B 側が承認できない状態にする
                            Task { await pairViewModel.cancelOutgoingRequest() }
                            showPairWaiting = false
                        },
                        onClose: { showPairWaiting = false }
                    )
                }
                // ペア承認: Modal sheet（HIG — 割り込み通知）
                .sheet(item: $pairVM.pendingRequest) { request in
                    PairApprovalSheet(
                        request: request,
                        requester: pairViewModel.pendingRequester,
                        mode: pairViewModel.showingCelebration
                            ? .celebrating(
                                partnerName: pairViewModel.partnerProfile?.displayName ?? "パートナー",
                                partnerInitial: String((pairViewModel.partnerProfile?.displayName ?? "P").prefix(1)).uppercased()
                            )
                            : .incoming,
                        myInitial: String((authViewModel.currentProfile?.displayName ?? "Y").prefix(1)).uppercased(),
                        onAccept: { Task { await pairViewModel.acceptIncoming() } },
                        onReject: { Task { await pairViewModel.rejectIncoming() } },
                        onDefer: { pairViewModel.dismissIncoming() },
                        onEnterRoom: {
                            Task {
                                guard let pair = pairViewModel.activePair else {
                                    pairViewModel.finishCelebration()
                                    return
                                }
                                await homeViewModel.loadSharedRoom(roomId: pair.sharedRoomId)
                                pairViewModel.finishCelebration()
                                guard let sharedRoom = homeViewModel.sharedRoom else { return }
                                roomViewModel = RoomViewModel(sharedRoomV4: sharedRoom, pairId: pair.id)
                            }
                        }
                    )
                }
            }

            // ルーム: ZStack オーバーレイ(fullScreenCover 内の .sheet 競合を回避)
            if let vm = roomViewModel {
                RoomViewWrapper(
                    roomViewModel: vm,
                    authViewModel: authViewModel,
                    pairViewModel: pairViewModel,
                    soloHistoryVM: soloHistoryVM,
                    onExit: {
                        // 再生中の閉じるは RoomView のダイアログで「閉じる(再生は続ける)」を選んだ後のみ
                        // 到達する。leaveRoom は keepPlaying=true で呼び、ApplicationMusicPlayer.shared
                        // による再生は継続させる。停止したい場合はユーザーが一時停止してから閉じる。
                        let leavingVM = vm
                        let stillPlaying = leavingVM.musicService.isPlaying
                        roomViewModel = nil
                        Task { await leavingVM.leaveRoom(keepPlaying: stillPlaying) }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: roomViewModel != nil)
    }

    // v0.5: Solo は Room 起点。Home → Solo ボタンで RoomViewModel を直接生成し、
    // 内部で SearchSheet / 検索 / 履歴 / 文脈画面の動線が完結する。
    // 旧 SoloModeView を経由した中間 search-sheet ハンドリングは撤去。
}

// MARK: - Pair send alert payload

private struct PairSendAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Connect Music gate (v0.5.1 §5.8)

/// Room に入る直前に提示する音楽サービス接続ゲート。
/// state は MusicKit 認可 + サブスク状態から導出する。
struct ConnectGate: Identifiable {
    let id = UUID()
    let state: ConnectMusicState
    let intent: ConnectMusicIntent
    let proceed: () -> Void
}

extension ContentView {
    /// オンボーディング完了したか
    fileprivate var onboardingCompleted: Bool {
        appStates.first?.onboardingCompleted ?? false
    }

    /// Room 起動前に Connect Music ゲートを挟む。
    /// 認可済 + サブスク有なら即時 run、それ以外は ConnectMusicView を提示する。
    fileprivate func gateThenRun(intent: ConnectMusicIntent, run: @escaping () -> Void) {
        let authStatus = MusicAuthorization.currentStatus
        switch authStatus {
        case .authorized:
            // サブスクは MusicSubscription で取得すれば厳密だが、ここでは認可済なら通す。
            // MusicPlayerService 側で再生時に subscription エラーになれば既存の Alert で
            // 対処されるので、ゲートとしては「認可されていれば素通り」で OK。
            run()
        case .notDetermined:
            connectGate = ConnectGate(state: .notDetermined, intent: intent, proceed: run)
        case .denied, .restricted:
            connectGate = ConnectGate(state: .denied, intent: intent, proceed: run)
        @unknown default:
            connectGate = ConnectGate(state: .notDetermined, intent: intent, proceed: run)
        }
    }
}

// MARK: - RoomView Wrapper

private struct RoomViewWrapper: View {
    @Bindable var roomViewModel: RoomViewModel
    let authViewModel: AuthViewModel
    let pairViewModel: PairViewModel
    let soloHistoryVM: SoloHistoryViewModel
    var onExit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    /// v0.5: Room から push される文脈画面の表示状態
    @State private var showContext: Bool = false

    /// v1.1: ふたりのプレイリスト(★ ボタン INSERT 用にここで保持)
    @State private var pairPlaylistService = PairPlaylistService()
    @State private var pairPlaylist: PairPlaylist? = nil
    @State private var pairPlaylistItems: [PairPlaylistItem] = []

    /// Solo Context の状態判定。pair あり = full / empty、pair なし = deleted。
    /// memory(preserve_memories=TRUE で ended)は将来追加(pair_relationships の status を見るため別途取得が必要)。
    private var soloContextState: SoloContextState {
        if pairViewModel.activePair == nil {
            return soloHistoryVM.sharedHistory.isEmpty ? .deleted : .memory
        }
        return soloHistoryVM.sharedHistory.isEmpty ? .empty : .full
    }

    /// ペアリングしてからの日数(0 起算)。activePair なしの時は 0。
    private func daysSincePair() -> Int {
        guard let pair = pairViewModel.activePair else { return 0 }
        let interval = Date().timeIntervalSince(pair.pairedAt)
        return max(0, Int(interval / 86400))
    }

    /// shared history の総再生時間ラベル("5 時間 23 分" など)。
    private func totalDurationLabel(_ entries: [PlayHistoryEntry]) -> String {
        let totalSeconds = entries.reduce(0) { $0 + $1.playedDurationSeconds }
        let m = totalSeconds / 60
        if m < 60 { return "\(m) 分" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) 時間" : "\(h) 時間 \(rem) 分"
    }

    /// 現在再生中の曲を「ふたりのプレイリスト」に追加する(★ ボタン)
    private func saveCurrentToPlaylist() async {
        guard let pair = pairViewModel.activePair,
              let track = roomViewModel.currentTrack,
              let userId = authViewModel.session?.user.id.uuidString
        else { return }

        let playlist: PairPlaylist?
        if let cached = pairPlaylist {
            playlist = cached
        } else {
            playlist = await pairPlaylistService.fetchOrCreatePlaylist(pairId: pair.id)
        }
        guard let resolved = playlist else { return }

        let ok = await pairPlaylistService.addItem(
            playlistId: resolved.id,
            songId: track.id,
            songTitle: track.title,
            artistName: track.artist,
            artworkUrl: track.artworkURL?.absoluteString,
            addedBy: userId
        )

        if ok {
            pairPlaylistItems = await pairPlaylistService.fetchItems(playlistId: resolved.id)
            if pairPlaylist == nil { pairPlaylist = resolved }
        }
    }

    var body: some View {
        RoomView(
            roomViewModel: roomViewModel,
            isHost: roomViewModel.isHost,
            participantCount: max(1, roomViewModel.onlineParticipants.count),
            guestJoining: !roomViewModel.isHost,
            meName: authViewModel.currentProfile?.displayName ?? "あなた",
            partnerName: pairViewModel.partnerProfile?.displayName,
            myAvatarUrl: authViewModel.currentProfile?.avatarUrl,
            partnerAvatarUrl: pairViewModel.partnerProfile?.avatarUrl,
            onExit: onExit,
            onSelectTrack: { _ in },
            onOpenContext: {
                Task {
                    let userId = authViewModel.session?.user.id.uuidString ?? ""
                    let partnerId = pairViewModel.activePair?.partnerUserId(meId: userId.lowercased())
                    await soloHistoryVM.load(
                        pairId: pairViewModel.activePair?.id,
                        userId: userId,
                        partnerUserId: partnerId
                    )
                    showContext = true
                }
            },
            onSaveToPlaylist: roomViewModel.mode == .shared ? {
                Task { await saveCurrentToPlaylist() }
            } : nil
        )
        .task {
            // Shared モードに入った時に、ペアのデフォルトプレイリストを取得しておく(★ ボタン用)
            guard roomViewModel.mode == .shared, let pairId = pairViewModel.activePair?.id else { return }
            if pairPlaylist == nil {
                pairPlaylist = await pairPlaylistService.fetchOrCreatePlaylist(pairId: pairId)
            }
            if let pid = pairPlaylist?.id {
                pairPlaylistItems = await pairPlaylistService.fetchItems(playlistId: pid)
            }
        }
        .fullScreenCover(isPresented: $showContext) {
            if roomViewModel.mode == .shared {
                SharedContextView(
                    sessions: ContextSessionGrouping.sessions(from: soloHistoryVM.sharedHistory),
                    pairPlaylist: pairPlaylistItems.map { $0.toViewTrack(
                        myUserId: authViewModel.session?.user.id.uuidString ?? "",
                        partnerName: pairViewModel.partnerProfile?.displayName
                    ) },
                    totalDays: daysSincePair(),
                    totalSongs: soloHistoryVM.sharedHistory.count,
                    totalDurationLabel: totalDurationLabel(soloHistoryVM.sharedHistory),
                    showMemoryEntry: soloHistoryVM.sharedHistory.count >= 20 || daysSincePair() >= 7,
                    anniversary: false,
                    onBack: { showContext = false }
                )
            } else {
                SoloContextView(
                    state: soloContextState,
                    sessions: ContextSessionGrouping.sessions(from: soloHistoryVM.sharedHistory),
                    myRecent: soloHistoryVM.myRecent.map { $0.toContextTrackCard() },
                    partnerFavs: soloHistoryVM.partnerFavorites.map { $0.toContextTrackCard() },
                    partnerName: pairViewModel.partnerProfile?.displayName ?? "さくら",
                    onBack: { showContext = false }
                )
            }
        }
        .task {
            let userId = authViewModel.session?.user.id.uuidString ?? ""
            let name = authViewModel.session?.user.userMetadata["full_name"]?.stringValue
            await roomViewModel.enterRoom(userId: userId, displayName: name)
        }
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
