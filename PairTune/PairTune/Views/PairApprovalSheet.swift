import SwiftUI
import Combine

// MARK: - PairApprovalSheet (v0.4 ペアリング承認モーダル)
//
// 仕様: docs/PairTune_Specification_v0.4.md §5.6 / §6
// 実装ガイド: docs/PairTune_Implementation_Guide_v0.4.md §6.4
// デザイン: Claude Design v2 `screens-pairing-approval.jsx`
//
// 2 モード:
//   - .incoming: 申請受信ビュー(アバター + 期限カウントダウン + 承認/拒否/あとで)
//   - .celebrating: 承認直後の演出(twin avatars + 「ペアになりました」+ 「ふたりの部屋を開く」)

struct PairApprovalSheet: View {
    enum Mode: Equatable {
        case incoming
        case celebrating(partnerName: String, partnerInitial: String)
    }

    let request: PairRequest
    let requester: ProfileV4?
    let mode: Mode
    let myInitial: String

    var onAccept: () -> Void
    var onReject: () -> Void
    var onDefer: () -> Void
    var onEnterRoom: () -> Void

    @State private var now: Date = .now
    @State private var isProcessing: Bool = false
    @State private var pulseTrigger: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let glowIntensity: Double = mode == .incoming ? 0.17 : 0.28
        return ZStack {
            Color(red: 0x0C/255, green: 0x08/255, blue: 0x18/255).ignoresSafeArea()

            // Background glows — clipped to sheet bounds so the 520/360pt circles don't expand the parent
            Color.clear
                .overlay {
                    ZStack {
                        Circle()
                            .fill(Color.pairtunePrimary.opacity(glowIntensity))
                            .frame(width: 520, height: 520)
                            .blur(radius: 60)
                            .offset(y: -260)
                        Circle()
                            .fill(Color.pairtuneSecondary.opacity(mode == .incoming ? 0.12 : 0.22))
                            .frame(width: 360, height: 360)
                            .blur(radius: 50)
                            .offset(x: 130, y: 260)
                    }
                }
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                if mode == .incoming {
                    incomingBody
                } else if case .celebrating(let partnerName, let partnerInitial) = mode {
                    celebrationBody(partnerName: partnerName, partnerInitial: partnerInitial)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(isProcessing || isCelebrating)
        .onReceive(timer) { now = $0 }
        .onChange(of: mode) { _, newMode in
            if case .celebrating = newMode {
                isProcessing = false
                pulseTrigger += 1
            }
        }
    }

    private var isCelebrating: Bool {
        if case .celebrating = mode { return true }
        return false
    }

    // MARK: - Incoming body
    //
    // jsx の構造:
    //   - Header: 「あとで」 / 「ペアリング申請」 18pt #7A7588 / spacer
    //   - Top group(中央): avatar 72×72 + 2 重 pulse ring + name 18pt 500 + 大タイトル
    //   - Bottom group: expiry card(縦積み)+ ヒント
    //   - Footer: 承認 big + [拒否][あとで] 横並び

    @ViewBuilder
    private var incomingBody: some View {
        // Header
        HStack {
            Button(action: onDefer) {
                Text("あとで")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "A8A8A8"))
                    .padding(6)
            }
            Spacer()
            Text("ペアリング申請")
                .font(.system(size: 18))
                .tracking(0.5)
                .foregroundColor(Color(hex: "7A7588"))
            Spacer()
            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)

        // Top group(中央配置)
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            avatarWithWaves

            Text("\(displayName) さん")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .tracking(0.1)
                .padding(.top, 22)

            if let code = requester?.pairingCode, !code.isEmpty {
                Text("@\(code.lowercased())")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: "7A7588"))
                    .tracking(0.3)
                    .padding(.top, 3)
            }

            Text("\(displayName) さんがあなたと\nペアリングしたがっています")
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .tracking(0.2)
                .padding(.top, 24)
                .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)

        // Bottom group(footer 寄り)
        VStack(spacing: 18) {
            expiryCard
                .padding(.horizontal, 28)

            Text("承認すると、ふたりだけのルームが作られます。\nいつでも解消できます。")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "5A5566"))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .tracking(0.2)
        }
        .padding(.bottom, 24)

        // Footer CTAs
        VStack(spacing: 10) {
            acceptButton
            HStack(spacing: 10) {
                rejectButton
                deferButton
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 36)
    }

    /// jsx: 72×72 avatar + 2 重 pulse ring(inset -20 / -40, primary28 / primary1a)
    private var avatarWithWaves: some View {
        ZStack {
            // 外側ハロー(animated pulse、2.4s)
            Circle()
                .stroke(Color.pairtunePrimary.opacity(0.10), lineWidth: 0.5)
                .frame(width: 152, height: 152)
                .opacity(0.4 + 0.6 * sin(now.timeIntervalSinceReferenceDate * .pi / 1.2 + .pi))
            Circle()
                .stroke(Color.pairtunePrimary.opacity(0.16), lineWidth: 0.5)
                .frame(width: 112, height: 112)
                .opacity(0.4 + 0.6 * sin(now.timeIntervalSinceReferenceDate * .pi / 1.2))

            // 中央 avatar 72×72
            Circle()
                .fill(LinearGradient(
                    colors: [Color.pairtuneSecondary, Color.pairtuneSecondary.opacity(0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 72, height: 72)
                .overlay(
                    Text(requesterInitial)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color(hex: "0A0612"))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1.5))
                .shadow(color: Color.pairtuneSecondary.opacity(0.27), radius: 18, y: 14)
        }
    }

    /// jsx の縦積み expiry card(PairWaitingView と同じ構造)
    private var expiryCard: some View {
        let remaining = max(0, Int(request.expiresAt.timeIntervalSince(now)))
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        let hh = String(format: "%02d", h)
        let mm = String(format: "%02d", m)
        let ss = String(format: "%02d", s)
        return VStack(spacing: 6) {
            Text("承認期限まで")
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: "7A7588"))
                .tracking(0.6)
                .textCase(.uppercase)
            Text("\(hh):\(mm):\(ss)")
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .foregroundColor(h < 6 ? Color(hex: "F4C26A") : .white)
                .tracking(1)
                .monospacedDigit()
            Text("\(formatDate(request.createdAt)) に申請されました")
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: "7A7588"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .tracking(0.2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )
        )
    }

    private var acceptButton: some View {
        Button(action: handleAccept) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("承認してペアになる")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.pairtunePrimary.opacity(0.33), radius: 16, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            )
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1.0)
    }

    private var rejectButton: some View {
        Button(action: handleReject) {
            Text("拒否")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "E85B6B"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "E85B6B").opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "E85B6B").opacity(0.25), lineWidth: 0.5)
                        )
                )
        }
        .disabled(isProcessing)
    }

    private var deferButton: some View {
        Button(action: onDefer) {
            Text("あとで")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "A8A8A8"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
        }
        .disabled(isProcessing)
    }

    // MARK: - Celebration body
    //
    // jsx の構造:
    //   - Top group(中央): twin avatars 64×64 gap 24 + 3 重 concentric ripples 120×120 +
    //                       「ペアになりました」 21pt 500 + sub 12.5pt
    //   - Footer: primary CTA「ふたりの部屋を開く」(arrow icon + text)
    //   - 接続波 (CelebrationWaveView) は jsx では使わないので撤去

    @ViewBuilder
    private func celebrationBody(partnerName: String, partnerInitial: String) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Twin avatars + concentric ripples
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.pairtunePrimary.opacity(0.25), lineWidth: 1)
                        .frame(width: 120, height: 120)
                        .scaleEffect(rippleScale(for: i))
                        .opacity(rippleOpacity(for: i))
                        .animation(
                            .easeOut(duration: 2.4)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.6),
                            value: pulseTrigger
                        )
                }

                HStack(spacing: 24) {
                    celebrationAvatar(initial: myInitial, color: .pairtunePrimary)
                    celebrationAvatar(initial: partnerInitial, color: Color(hex: "FF6B9D"))
                }
            }
            .frame(height: 110)

            VStack(spacing: 14) {
                Text("ペアになりました")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundColor(.white)
                    .tracking(0.2)

                Text("ふたりだけの部屋ができました。\nいつでも、同じ音を。")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(hex: "7A7588"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .tracking(0.2)
            }
            .padding(.top, 32)
            .opacity(pulseTrigger > 0 ? 1 : 0)
            .animation(.easeOut(duration: 0.7).delay(1.0), value: pulseTrigger)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)

        // Primary CTA
        Button(action: onEnterRoom) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("ふたりの部屋を開く")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: Color.pairtunePrimary.opacity(0.33), radius: 16, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            )
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 36)
        .opacity(pulseTrigger > 0 ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(1.4), value: pulseTrigger)
    }

    /// 64×64 jsx の Celebration アバター
    private func celebrationAvatar(initial: String, color: Color) -> some View {
        Circle()
            .fill(LinearGradient(
                colors: [color, color.opacity(0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: 64, height: 64)
            .overlay(
                Text(initial)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "0A0612"))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1.5))
            .shadow(color: color.opacity(0.4), radius: 14, y: 8)
    }

    private func rippleScale(for i: Int) -> CGFloat {
        pulseTrigger > 0 ? 2.6 : 0.6
    }

    private func rippleOpacity(for i: Int) -> Double {
        pulseTrigger > 0 ? 0 : 0.9
    }

    // MARK: - Handlers

    private func handleAccept() {
        isProcessing = true
        onAccept()
    }

    private func handleReject() {
        isProcessing = true
        onReject()
    }

    // MARK: - Helpers

    private var displayName: String {
        requester?.displayName ?? "ユーザー"
    }

    private var requesterInitial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: date)
    }
}

// v0.5: 縦積み expiry card に統合したため、CountdownRingView は撤去。

// v0.5: jsx に合わせて Celebration 接続波(CelebrationWaveView)は撤去。
// 旧 v0.4 のドリーミー演出として twin avatar 間に dashed wave を描いていたが、
// v0.5 では concentric ripples だけに集約された(screens-pairing-approval.jsx)。
