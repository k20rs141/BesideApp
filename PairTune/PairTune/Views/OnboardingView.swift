import SwiftUI
import SwiftData

// MARK: - OnboardingView (v0.5 §5.0)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.0 / docs/PairTune_Decision_Log_v0.5.md §1
// デザイン: docs/design_v3_source/screens-onboarding.jsx (Claude Design v3)
//
// サインイン直後・初回のみ表示。3 ステップ、各画面スキップ可。
// 完了フラグは AppState (SwiftData + CloudKit) で端末側管理。
//
// Step 1: 今、つながる — リアルタイム性の訴求(2 アバター + 接続波)
// Step 2: 一度だけのペアリング — CodeChip ビジュアル + 未来予告 1 行
// Step 3: さあ、はじめよう — 分岐(コードで参加 / まず自分で見てみる)
//
// CTA:
//   - Step 1/2: 「次へ」(主)
//   - Step 3:   「コードで参加する」(主) / 「まず自分で見てみる」(副)
//   - 任意のステップで「スキップ」

struct OnboardingView: View {
    let myPairingCode: String?

    /// 「コードで参加する」(主 CTA, step 3) — Home でコード入力 sheet を開く
    var onJoinWithCode: () -> Void
    /// 「まず自分で見てみる」(副 CTA, step 3) — Home に遷移して Solo に進める
    var onSolo: () -> Void
    /// スキップ(任意のステップで Home へ)
    var onSkip: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]
    @State private var step: Int = 1

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // ambient glow
            RadialGradient(
                colors: [Color.pairtunePrimary.opacity(0.16), .clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .blur(radius: 60)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // top bar
                HStack {
                    Color.clear.frame(width: 38, height: 38)
                    Spacer()
                    DotsIndicator(count: 3, active: step - 1)
                    Spacer()
                    Button(action: skip) {
                        Text("スキップ")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.pairtuneTextSecondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)

                Spacer(minLength: 0)

                // visual + copy
                VStack(spacing: 0) {
                    ZStack {
                        currentVisual
                    }
                    .frame(width: 280, height: 180)
                    .padding(.bottom, 36)

                    Text(currentTitle)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(currentBody)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pairtuneTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 18)
                        .frame(maxWidth: 300)

                    if let hint = currentHint {
                        Text(hint)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(hex: "C9C2DD"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.pairtunePrimary.opacity(0.08))
                                    .overlay(
                                        Capsule().stroke(Color.pairtunePrimary.opacity(0.16), lineWidth: 0.5)
                                    )
                            )
                            .padding(.top, 18)
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 0)

                // CTAs
                VStack(spacing: 10) {
                    if step < 3 {
                        Button(action: nextStep) {
                            HStack(spacing: 8) {
                                Text("次へ")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LinearGradient(
                                        colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                            )
                            .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 14, y: 8)
                        }
                    } else {
                        Button(action: joinWithCode) {
                            HStack(spacing: 9) {
                                Image(systemName: "door.left.hand.open")
                                    .font(.system(size: 16))
                                Text("コードで参加する")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LinearGradient(
                                        colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                            )
                            .shadow(color: Color.pairtunePrimary.opacity(0.33), radius: 16, y: 10)
                        }
                        Button(action: solo) {
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 14))
                                Text("まず自分で見てみる")
                            }
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(Color.pairtuneTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 42)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    // MARK: - Step content

    private var currentTitle: String {
        switch step {
        case 1: return "今、つながる"
        case 2: return "一度だけのペアリング"
        default: return "さあ、はじめよう"
        }
    }

    private var currentBody: String {
        switch step {
        case 1: return "離れていても、同じ音を。\nこの瞬間、同じ曲が 2 人に流れる。\n通話は、いりません。"
        case 2: return "はじめに、一度だけペアリング。\nあなたのコードを送るか、\n相手のコードを入力するだけ。"
        default: return "コードで参加するか、\nまずひとりで触ってみるか。\n好きな方から。"
        }
    }

    private var currentHint: String? {
        step == 2 ? "使うほどに、2 人だけの音楽が育っていきます。" : nil
    }

    @ViewBuilder
    private var currentVisual: some View {
        switch step {
        case 1: ConnectVisual()
        case 2: CodeVisual(code: myPairingCode ?? "KTOMSO")
        default: BranchVisual()
        }
    }

    // MARK: - Actions

    private func nextStep() {
        step = min(3, step + 1)
    }

    private func skip() {
        markCompleted()
        onSkip()
    }

    private func joinWithCode() {
        markCompleted()
        onJoinWithCode()
    }

    private func solo() {
        markCompleted()
        onSolo()
    }

    private func markCompleted() {
        let state: AppState
        if let existing = appStates.first {
            state = existing
        } else {
            state = AppState()
            modelContext.insert(state)
        }
        state.onboardingCompleted = true
        state.onboardingCompletedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Dots indicator

private struct DotsIndicator: View {
    let count: Int
    let active: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Color.pairtunePrimary : Color.white.opacity(0.22))
                    .frame(width: i == active ? 24 : 8, height: 8)
                    .shadow(color: i == active ? Color.pairtunePrimary.opacity(0.4) : .clear, radius: 6)
                    .animation(.easeInOut(duration: 0.25), value: active)
            }
        }
    }
}

// MARK: - Visuals

private struct ConnectVisual: View {
    var body: some View {
        ZStack {
            RippleHalo(color: .pairtunePrimary)
                .offset(x: -84)
            RippleHalo(color: .pairtuneSecondary, delay: 1.2)
                .offset(x: 84)

            OnboardingAvatar(initials: "YO", color: .pairtunePrimary)
                .offset(x: -84)
            OnboardingAvatar(initials: "SA", color: .pairtuneSecondary)
                .offset(x: 84)

            // connecting wave
            ConnectingWave()
                .frame(width: 108, height: 42)
        }
    }
}

private struct CodeVisual: View {
    let code: String

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("あなたのコード")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(Color.pairtuneTextTertiary)
                    .textCase(.uppercase)
                Text(code)
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .tracking(7)
                    .foregroundStyle(Color.pairtunePrimary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [Color.pairtunePrimary.opacity(0.12), Color.pairtuneSecondary.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.pairtunePrimary.opacity(0.21), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.pairtunePrimary.opacity(0.16), radius: 12, y: 8)
        }
    }
}

private struct BranchVisual: View {
    var body: some View {
        ZStack {
            // dashed Y-shaped paths
            BranchPaths()
                .frame(width: 280, height: 170)

            // bottom dot (origin)
            Circle()
                .fill(LinearGradient(
                    colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 8, height: 8)
                .shadow(color: Color.pairtunePrimary.opacity(0.53), radius: 8)
                .offset(y: 71)

            // left: door
            BranchEnd(color: .pairtunePrimary, label: "コードで参加", glyph: "door.left.hand.open")
                .offset(x: -70, y: -35)

            // right: music
            BranchEnd(color: .pairtuneSecondary, label: "ひとりで聴く", glyph: "music.note")
                .offset(x: 70, y: -35)
        }
    }
}

private struct BranchPaths: View {
    var body: some View {
        Canvas { ctx, size in
            let origin = CGPoint(x: size.width / 2, y: size.height - 20)
            let left = CGPoint(x: 70, y: 50)
            let right = CGPoint(x: size.width - 70, y: 50)

            var lPath = Path()
            lPath.move(to: origin)
            lPath.addQuadCurve(to: left, control: CGPoint(x: origin.x - 10, y: origin.y - 40))

            var rPath = Path()
            rPath.move(to: origin)
            rPath.addQuadCurve(to: right, control: CGPoint(x: origin.x + 10, y: origin.y - 40))

            let dashStyle = StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2.5, 5])
            ctx.stroke(lPath, with: .color(Color.pairtunePrimary.opacity(0.4)), style: dashStyle)
            ctx.stroke(rPath, with: .color(Color.pairtuneSecondary.opacity(0.4)), style: dashStyle)
        }
    }
}

private struct BranchEnd: View {
    let color: Color
    let label: String
    let glyph: String

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [color.opacity(0.16), color.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(color.opacity(0.27), lineWidth: 0.5)
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: color.opacity(0.2), radius: 12, y: 8)
                Image(systemName: glyph)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }
}

private struct ConnectingWave: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            wavePath(amplitude: 12)
                .stroke(
                    LinearGradient(
                        colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .opacity(animating ? 1.0 : 0.5)
            wavePath(amplitude: -12)
                .stroke(
                    LinearGradient(
                        colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .opacity(animating ? 0.75 : 0.3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                animating.toggle()
            }
        }
    }

    private func wavePath(amplitude: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 4, y: 21))
            p.addQuadCurve(to: CGPoint(x: 28, y: 21), control: CGPoint(x: 16, y: 21 - amplitude))
            p.addQuadCurve(to: CGPoint(x: 52, y: 21), control: CGPoint(x: 40, y: 21 + amplitude))
            p.addQuadCurve(to: CGPoint(x: 76, y: 21), control: CGPoint(x: 64, y: 21 - amplitude))
            p.addQuadCurve(to: CGPoint(x: 104, y: 21), control: CGPoint(x: 90, y: 21 + amplitude))
        }
    }
}

private struct OnboardingAvatar: View {
    let initials: String
    let color: Color

    var body: some View {
        Text(initials)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(Color(hex: "0A0612"))
            .frame(width: 72, height: 72)
            .background(
                Circle().fill(LinearGradient(
                    colors: [color, color.opacity(0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1.5)
            )
            .shadow(color: color.opacity(0.27), radius: 14, y: 8)
    }
}

private struct RippleHalo: View {
    let color: Color
    var delay: Double = 0

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(color.opacity(0.33), lineWidth: 1)
                    .frame(width: 120, height: 120)
                    .scaleEffect(0.6 + (phase + CGFloat(i) * 0.33).truncatingRemainder(dividingBy: 1.0) * 2.0)
                    .opacity(Double(1.0 - (phase + CGFloat(i) * 0.33).truncatingRemainder(dividingBy: 1.0)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false).delay(delay)) {
                phase = 1
            }
        }
    }
}

#Preview("Step 1") {
    OnboardingView(myPairingCode: "KTOMSO", onJoinWithCode: {}, onSolo: {}, onSkip: {})
        .modelContainer(for: AppState.self, inMemory: true)
}
