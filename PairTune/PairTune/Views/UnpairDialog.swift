import SwiftUI

// MARK: - UnpairDialog (v0.5 Design Handoff §2.12 / 仕様書 §8-5-2)
//
// 3 step modal:
//   1. Confirm   : heart-broken icon (neutral) +「ペアリングを解消しますか?」
//                 「相手 さんとのルームは閉じられ、以後の同期再生はできなくなります。」
//                 「次へ」(赤系 secondary) / キャンセル
//   2. Memories  : タイトルのみ(サブコピーなし) + 3 オプション
//                 - 残す(おすすめ chip / primary outline)
//                 - 保留する(90 日後に自動削除)
//                 - 完全に削除(danger red, door-out icon)
//                 末尾に「← 戻る」(矢印付き transparent)
//   3. Done      : check icon(primary) +「ペアリングを解消しました」
//                 + choice 別動的コピー(下記)
//                 完了 CTA はニュートラル(gradient なし)
//
// 「残す」 → preserveMemories = TRUE / 「保留する」「完全に削除」 → preserveMemories = FALSE
// DB レベルでは後者 2 つは同じ(90 日後物理削除)。文言で意思決定の確度を区別。
//
// 完了 → Home が pre state, Solo は memory state へ移行(active_pair_id が NULL)。

enum UnpairChoice {
    case keep
    case later
    case delete

    var preserveMemories: Bool {
        self == .keep
    }
}

private enum UnpairStep {
    case confirm
    case memories
    case done
}

struct UnpairDialog: View {
    let partnerName: String?
    /// 「思い出はどうしますか?」で選択された時に呼ばれる。caller が PairViewModel 経由で
    /// endActivePair(preserveMemories:) を実行し、Bool を返す(成功なら true)。
    var onCommit: (UnpairChoice) async -> Bool
    /// 完了画面で「閉じる」を押した時、または confirm step で「キャンセル」を押した時。
    var onDismiss: () -> Void

    @State private var step: UnpairStep = .confirm
    @State private var choice: UnpairChoice? = nil
    @State private var bgOpacity: Double = 0
    @State private var scale: CGFloat = 0.92
    @State private var isCommitting: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .opacity(bgOpacity)
                .ignoresSafeArea()
                // タップ無効=明示的キャンセルのみ(handoff §2.12 Dialog 共通)

            card
                .scaleEffect(scale)
                .opacity(bgOpacity)
                .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                bgOpacity = 1
                scale = 1
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.18)) {
            bgOpacity = 0
            scale = 0.94
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onDismiss() }
    }

    // MARK: - Card

    private var card: some View {
        ZStack {
            confirmStep.opacity(step == .confirm ? 1 : 0).allowsHitTesting(step == .confirm)
            memoriesStep.opacity(step == .memories ? 1 : 0).allowsHitTesting(step == .memories)
            doneStep.opacity(step == .done ? 1 : 0).allowsHitTesting(step == .done)
        }
        .animation(.easeInOut(duration: 0.22), value: step)
        .frame(maxWidth: 340)
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.pairtuneSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.7), radius: 30, y: 16)
        )
    }

    // MARK: - Step 1: Confirm

    private var confirmStep: some View {
        VStack(spacing: 0) {
            roundIcon(systemName: "heart.slash",
                      tint: Color(hex: "A8A8A8"),
                      bg: Color.white.opacity(0.04),
                      border: Color.white.opacity(0.08))

            Text("ペアリングを解消しますか?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .tracking(0.2)
                .padding(.top, 14)

            Text(confirmMessage)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "A8A8A8"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .tracking(0.2)
                .padding(.top, 10)

            VStack(spacing: 10) {
                Button {
                    step = .memories
                } label: {
                    Text("次へ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.pairtuneSecondary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.pairtuneSecondary.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.pairtuneSecondary.opacity(0.30), lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button(action: dismiss) {
                    Text("キャンセル")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "A8A8A8"))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 18)
        }
    }

    private var confirmMessage: String {
        let prefix = partnerName.map { "\($0) さんとの" } ?? "ふたりの"
        return "\(prefix)ルームは閉じられ、\n以後の同期再生はできなくなります。"
    }

    // MARK: - Step 2: Memories

    private var memoriesStep: some View {
        VStack(spacing: 0) {
            Text("思い出はどうしますか?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .tracking(0.2)

            VStack(spacing: 8) {
                memoryOption(
                    choice: .keep,
                    icon: "music.note",
                    title: "残す",
                    desc: "ふたりで聴いた曲を Solo モードでいつでも見返せます。",
                    recommend: true
                )
                memoryOption(
                    choice: .later,
                    icon: "clock",
                    title: "保留する",
                    desc: "それまでに Profile から『残す』に変更できます。"
                )
                memoryOption(
                    choice: .delete,
                    icon: "door.left.hand.open",
                    title: "完全に削除",
                    desc: "すべての履歴が削除されます。元には戻せません。",
                    danger: true
                )
            }
            .padding(.top, 20)

            Button {
                step = .confirm
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("戻る")
                        .font(.system(size: 13))
                }
                .foregroundColor(Color(hex: "7A7588"))
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .disabled(isCommitting)
        }
    }

    private func memoryOption(
        choice: UnpairChoice,
        icon: String,
        title: String,
        desc: String,
        recommend: Bool = false,
        danger: Bool = false
    ) -> some View {
        let iconBg: Color = danger
            ? Color.pairtuneSyncBad.opacity(0.10)
            : (recommend ? Color.pairtunePrimary.opacity(0.11) : Color.white.opacity(0.04))
        let iconBorder: Color = danger
            ? Color.pairtuneSyncBad.opacity(0.25)
            : (recommend ? Color.pairtunePrimary.opacity(0.30) : Color.white.opacity(0.06))
        let iconTint: Color = danger
            ? .pairtuneSyncBad
            : (recommend ? .pairtunePrimary : Color(hex: "A8A8A8"))

        return Button {
            commit(choice)
        } label: {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(iconBorder, lineWidth: 0.5)
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconTint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.white)
                            .tracking(0.2)
                        if recommend {
                            Text("おすすめ")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.pairtunePrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.pairtunePrimary.opacity(0.11))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .stroke(Color.pairtunePrimary.opacity(0.30), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                    Text(desc)
                        .font(.system(size: 10.5))
                        .foregroundColor(danger ? Color.pairtuneSyncBad.opacity(0.85) : Color(hex: "7A7588"))
                        .tracking(0.2)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                recommend ? Color.pairtunePrimary.opacity(0.27) : Color.white.opacity(0.06),
                                lineWidth: 0.5
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCommitting)
    }

    private func commit(_ c: UnpairChoice) {
        guard !isCommitting else { return }
        isCommitting = true
        choice = c
        Task {
            let ok = await onCommit(c)
            isCommitting = false
            if ok { step = .done }
        }
    }

    // MARK: - Step 3: Done

    private var doneStep: some View {
        VStack(spacing: 0) {
            roundIcon(systemName: "checkmark",
                      tint: .pairtunePrimary,
                      bg: Color.pairtunePrimary.opacity(0.11),
                      border: Color.pairtunePrimary.opacity(0.30),
                      size: 54)

            Text("ペアリングを解消しました")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .tracking(0.2)
                .padding(.top, 14)

            Text(doneMessage)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "A8A8A8"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .tracking(0.2)
                .padding(.top, 10)

            Button(action: dismiss) {
                Text("閉じる")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(
                        // v0.5: 完了 CTA はニュートラル(gradient なし)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
        }
    }

    /// choice 別の完了画面コピー(handoff §2.12)
    private var doneMessage: String {
        switch choice ?? .later {
        case .keep:
            return "思い出は Solo モードで閲覧専用に残してあります。\nMemory Album からいつでも見返せます。\nいつでも、また始められます。"
        case .later:
            return "思い出は 90 日間保留されます。\nProfile から『残す』に変更できます。\nいつでも、また始められます。"
        case .delete:
            return "思い出は 90 日後に削除されます。\nお互いの履歴もタイムラインも消えます。"
        }
    }

    // MARK: - Icon

    private func roundIcon(systemName: String, tint: Color, bg: Color, border: Color, size: CGFloat = 48) -> some View {
        ZStack {
            Circle()
                .fill(bg)
                .overlay(Circle().stroke(border, lineWidth: 0.5))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(tint)
        }
    }
}
