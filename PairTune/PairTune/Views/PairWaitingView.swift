import SwiftUI
import Combine

// MARK: - PairWaitingView (v0.5 §5.6 / A 側 申請待ち)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.6
// デザイン: docs/design_v3_source/screens-pair-flow.jsx PairWaitingScreen
//
// コード入力 → 申請送信(`pairViewModel.sendState == .waiting`)の間表示される画面。
// レイアウト:
//   - Header: 「閉じる」(左) / 「申請中」(中央) / 空(右)
//   - Hero(上半分): 自分アバター(リップル波 3 重)+ gap 80 + 相手アバター(dim + dashed)
//                   + 「相手 さんの承認を\n待っています」21pt 500 中央
//   - Bottom group(footer 寄り): expiry card(縦積み: "有効期限まで" / HH:MM:SS / 説明)
//                                  + 「このまま閉じても大丈夫です…」ヒント
//   - Footer: 「申請を取り消す」(secondary red 50pt)
//
// 24h カウントダウンは outgoingRequest.expiresAt ベースで計算。
// jsx は接続波線を avatar 間に置かない設計に変わったため Canvas wave は撤去。

struct PairWaitingView: View {
    let targetCode: String?
    let expiresAt: Date?
    let myInitial: String
    /// 相手の表示名(不明なら nil 'or "相手"' として generic 表記)
    var partnerName: String? = nil

    var onCancel: () -> Void
    var onClose: () -> Void

    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // ambient glow(jsx: top -15%, primary26, blur 60)
            Color.clear
                .overlay(alignment: .top) {
                    Circle()
                        .fill(Color.pairtunePrimary.opacity(0.15))
                        .frame(width: 480, height: 480)
                        .blur(radius: 60)
                        .offset(y: -200)
                }
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                heroBlock
                bottomBlock
                footerButton
            }
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Text("閉じる")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "A8A8A8"))
                    .padding(6)
            }
            Spacer()
            Text("申請中")
                .font(.system(size: 18))
                .tracking(0.5)
                .foregroundColor(Color(hex: "7A7588"))
            Spacer()
            Color.clear.frame(width: 50, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    // MARK: - Hero block(上半分中央)

    private var heroBlock: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 2 アバターと waiting コピー
            HStack(spacing: 80) {
                meAvatarWithRipples
                partnerAvatarDim
            }
            .frame(height: 110)

            Text("\(partnerName ?? "相手") さんの承認を\n待っています")
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .tracking(0.2)
                .padding(.top, 32)
                .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Bottom block(expiry card + hint)

    private var bottomBlock: some View {
        VStack(spacing: 18) {
            expiryCard
                .padding(.horizontal, 28)

            Text("このまま閉じても大丈夫です。\n承認されたら通知でお知らせします。")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "5A5566"))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .tracking(0.2)
        }
        .padding(.bottom, 24)
    }

    private var expiryCard: some View {
        VStack(spacing: 6) {
            Text("有効期限まで")
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: "7A7588"))
                .tracking(0.6)
                .textCase(.uppercase)
            Text(countdownString)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .tracking(1)
                .monospacedDigit()
            Text("24 時間以内に承認されないと自動的に失効します。")
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

    // MARK: - Footer

    private var footerButton: some View {
        Button(action: onCancel) {
            Text("申請を取り消す")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.pairtuneSyncBad)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.pairtuneSyncBad.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.pairtuneSyncBad.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 36)
    }

    // MARK: - Avatars

    private var meAvatarWithRipples: some View {
        ZStack {
            // 3 重リップル(jsx: 80×80 circle, primary44, 2.4s, 0/0.6/1.2 delay)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.pairtunePrimary.opacity(0.27), lineWidth: 1)
                    .frame(width: 80, height: 80)
                    .scaleEffect(rippleScale(seed: i))
                    .opacity(rippleOpacity(seed: i))
            }

            Circle()
                .fill(LinearGradient(
                    colors: [Color.pairtunePrimary, Color.pairtunePrimary.opacity(0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(myInitial)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: "0A0612"))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1.5))
                .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 14, y: 6)
        }
        .frame(width: 80, height: 80)
    }

    private var partnerAvatarDim: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.pairtuneSecondary, Color.pairtuneSecondary.opacity(0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: 64, height: 64)
            .overlay(
                Text(String(partnerName?.prefix(2) ?? "SA").uppercased())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "0A0612"))
            )
            .overlay(
                Circle().stroke(
                    Color.white.opacity(0.20),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
            )
            .opacity(0.45)
            .saturation(0.6)
    }

    // MARK: - Helpers

    private var countdownString: String {
        guard let expiresAt else { return "--:--:--" }
        let remaining = max(0, Int(expiresAt.timeIntervalSince(now)))
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func rippleScale(seed: Int) -> CGFloat {
        let phase = (now.timeIntervalSinceReferenceDate + Double(seed) * 0.6)
            .truncatingRemainder(dividingBy: 2.4) / 2.4
        return 0.6 + CGFloat(phase) * 2.0
    }

    private func rippleOpacity(seed: Int) -> Double {
        let phase = (now.timeIntervalSinceReferenceDate + Double(seed) * 0.6)
            .truncatingRemainder(dividingBy: 2.4) / 2.4
        return 0.9 * (1 - phase)
    }
}

