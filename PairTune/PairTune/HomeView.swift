import SwiftUI
import UIKit

// MARK: - HomeView (v0.5 Claude Design v3)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.2 / Decision Log §5
// デザイン: docs/design_v3_source/screens-home-v05.jsx
//
// v0.5 で 3 状態 → 2 状態に簡素化:
//   A. pre     — ペアリング前 (partnerName == nil)
//      CodeChip(コピーボタン付き) + 「コードで参加」(primary) + 「ひとりで聴く」(secondary)
//   B. paired  — ペア済み (partnerName != nil)
//      2 アバター hero + 「○○ さんと聴く」(big primary) + 「ひとりで聴く」(secondary)
//      online/offline はステータスドットとサブテキストだけが変わる(CTA は同一)
//
// v0.5 で廃止:
//   - 「部屋を開いて待つ」CTA: shared_room に入ってから相手を待つ動線に統合
//   - オフライン時の Solo Promoted CTA(分岐ロジックそのものを撤廃)
//   - OR Divider(視覚ノイズ)
//   - 接続波 (2 アバター間): Decision Log により削除済み
//   - 英語サブタイトル(Hiragino で日本語のみに統一)

struct HomeView: View {
    /// 自分の pairing_code(state A 表示用)。nil なら "------"
    var pairingCode: String?

    /// 自分の表示名(paired hero のアバター initial 用)
    var myName: String? = nil

    /// パートナーの表示名(state B 表示用)。nil なら state A。
    var partnerName: String? = nil
    /// 自分の avatar 画像 URL(profiles.avatar_url)。nil の時はイニシャル fallback。
    var myAvatarUrl: String? = nil
    /// 相手の avatar 画像 URL。
    var partnerAvatarUrl: String? = nil

    /// パートナーのオンライン状況。CTA は変わらず、ステータスドットとテキストだけ反映。
    var partnerOnline: Bool = true

    /// オフライン時に表示する「最終オンライン日時」表示用テキスト(任意)
    var partnerLastSeen: String? = nil

    /// 記念日バッジ(該当日のみ表示。常設しない)
    var anniversary: Bool = false

    /// CTA ハンドラ
    var onShareCode: () -> Void = {}
    var onJoin: () -> Void = {}
    var onListenWithPartner: () -> Void = {}
    var onSolo: () -> Void = {}
    var onProfile: () -> Void = {}

    private var isPaired: Bool { partnerName != nil }

    @State private var toastMessage: String?

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // ── ambient glows ── partnerOnline の状態で輝度を調整 (jsx の 2c/22 vs 18/12)
            GeometryReader { _ in
                ZStack {
                    Circle()
                        .fill(Color.pairtunePrimary.opacity(partnerOnline ? 0.17 : 0.09))
                        .frame(width: 420, height: 420)
                        .blur(radius: 55)
                        .offset(x: 140, y: -120)
                    Circle()
                        .fill(Color.pairtuneSecondary.opacity(partnerOnline ? 0.13 : 0.07))
                        .frame(width: 340, height: 340)
                        .blur(radius: 50)
                        .offset(x: -160, y: 240)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                hero
                Spacer(minLength: 0)
                ctaStack
            }

            // Toast overlay (コードコピー時の確認用)
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: msg)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .padding(.bottom, 130)
                }
                .animation(.easeOut(duration: 0.25), value: toastMessage != nil)
                .allowsHitTesting(false)
            }
        }
    }

    /// pairingCode をクリップボードへコピーし、haptic + トーストで確認表示する。
    private func copyPairingCode() {
        let code = (pairingCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        UIPasteboard.general.string = code
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { toastMessage = "コードをコピーしました" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: - Top bar (logo lockup + profile avatar)

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                PairTuneLogoView(size: 48)
                    .frame(height: 17)
                PairTuneWordmark(size: 16, color: .white.opacity(0.82))
            }
            Spacer()
            Button(action: onProfile) {
                RemoteAvatarView(
                    url: myAvatarUrl.flatMap(URL.init(string:)),
                    initials: initialOf(myName ?? "YO"),
                    color: .pairtunePrimary,
                    size: 36,
                    strokeColor: Color.white.opacity(0.08),
                    strokeWidth: 0.5
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        if isPaired, let partnerName {
            pairedHero(partnerName: partnerName)
                .padding(.horizontal, 24)
        } else {
            preHero
                .padding(.horizontal, 24)
        }
    }

    private var preHero: some View {
        VStack(spacing: 0) {
            PairTuneLogoView(size: 170, glow: true)

            Text("離れていても、\n同じ音を。")
                .font(.system(size: 21, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .tracking(0.1)
                .padding(.top, 24)
        }
    }

    /// v0.5: 2 アバターを並べる(接続波は削除済み)。online/offline は相手アバターの dim と
    /// ステータス行(ドット色 + テキスト)だけが変わり、CTA や構造は変わらない。
    private func pairedHero(partnerName: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                AvatarWithStatusDot(
                    url: myAvatarUrl.flatMap(URL.init(string:)),
                    initials: initialOf(myName ?? "YO"),
                    color: .pairtunePrimary,
                    online: true,
                    dim: false
                )
                AvatarWithStatusDot(
                    url: partnerAvatarUrl.flatMap(URL.init(string:)),
                    initials: initialOf(partnerName),
                    color: Color(hex: "FF6B9D"),
                    online: partnerOnline,
                    dim: !partnerOnline
                )
            }
            .frame(height: 88)

            // partner name + anniversary badge
            HStack(spacing: 10) {
                Text("\(partnerName) さん")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .tracking(0.1)
                if anniversary {
                    AnniversaryBadge()
                }
            }
            .padding(.top, 16)

            // status row (online/offline はここだけが変わる)
            HStack(spacing: 7) {
                Circle()
                    .fill(partnerOnline ? Color.pairtunePrimary : Color(hex: "5A5566"))
                    .frame(width: 6, height: 6)
                    .shadow(color: partnerOnline ? Color.pairtunePrimary.opacity(0.8) : .clear, radius: 4)
                Text(partnerOnline
                     ? "オンライン"
                     : "最後にオンライン: \(partnerLastSeen ?? "—")")
                    .font(.system(size: 11.5))
                    .foregroundColor(partnerOnline ? Color.pairtunePrimary : Color(hex: "5A5566"))
                    .tracking(0.4)
            }
            .padding(.top, 5)
        }
    }

    private func initialOf(_ name: String) -> String {
        String(name.prefix(2)).uppercased()
    }

    // MARK: - CTA stack

    @ViewBuilder
    private var ctaStack: some View {
        if isPaired {
            pairedCtaStack
        } else {
            unpairedCtaStack
        }
    }

    private var unpairedCtaStack: some View {
        VStack(spacing: 12) {
            codeChip
            joinButton
            soloButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 38)
    }

    /// v0.5: online/offline で分岐しない。常に「○○ さんと聴く」+「ひとりで聴く」の 2 ボタン。
    private var pairedCtaStack: some View {
        VStack(spacing: 12) {
            listenWithPartnerButton(partnerName: partnerName ?? "")
            soloButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 38)
    }

    // MARK: - Code chip (v0.5 で「コードを送って、相手に参加してもらう」hint を追加)

    /// 表示すべき code 文字列。プロフィール未ロードや空文字なら「------」プレースホルダを返す。
    private var displayCode: String {
        let trimmed = (pairingCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "------" : trimmed
    }

    private var hasValidCode: Bool {
        !(pairingCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var codeChip: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("あなたのコード")
                    .font(.system(size: 11))
                    .foregroundColor(Color.pairtuneTextSecondary)
                    .tracking(0.6)
                    .textCase(.uppercase)
                Text(displayCode)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(.pairtunePrimary)
                    .tracking(6)
                Text("コードを送って、相手に参加してもらう")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: "7A7588"))
                    .tracking(0.2)
            }
            Spacer(minLength: 0)
            Button(action: copyPairingCode) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.pairtunePrimary.opacity(0.33), radius: 12, y: 6)
                    )
            }
            .disabled(!hasValidCode)
            .opacity(hasValidCode ? 1.0 : 0.5)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.pairtunePrimary.opacity(0.13),
                            Color.pairtuneSecondary.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.pairtunePrimary.opacity(0.23), lineWidth: 0.5)
                )
                .shadow(color: Color.pairtunePrimary.opacity(0.10), radius: 12, y: 6)
        )
    }

    // MARK: - Buttons

    private var joinButton: some View {
        Button(action: onJoin) {
            HStack(spacing: 10) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 16))
                Text("コードで参加")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 16, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            )
        }
    }

    private func listenWithPartnerButton(partnerName: String) -> some View {
        Button(action: onListenWithPartner) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 17))
                Text("\(partnerName) さんと聴く")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 16, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
            )
        }
    }

    /// v0.5: SecondaryButton — primary-tinted outline、Ghost より「ボタン」と認識できる
    private var soloButton: some View {
        Button(action: onSolo) {
            HStack(spacing: 9) {
                Image(systemName: "music.note")
                    .font(.system(size: 15))
                    .foregroundColor(.pairtunePrimary)
                Text("ひとりで聴く")
                    .font(.system(size: 14.5, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.pairtunePrimary.opacity(0.23), lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Anniversary badge
// jsx 仕様: padding '4px 10px 4px 8px', borderRadius 999, background
// `linear-gradient(135deg, accent24, accent2_24)`, border 0.5px accent40,
// sparkle 11pt + label 10.5pt fontWeight 500 letterSpacing .3

private struct AnniversaryBadge: View {
    var label: String = "1ヶ月記念"

    var body: some View {
        HStack(spacing: 5) {
            Text("✨")
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .tracking(0.3)
        }
        .foregroundColor(.white)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.pairtunePrimary.opacity(0.14),
                            Color.pairtuneSecondary.opacity(0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule().stroke(Color.pairtunePrimary.opacity(0.25), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - AvatarWithStatusDot
//
// jsx PartnerAvatar 相当。RemoteAvatarView の上に bottom-right の
// オンライン/オフラインドットを重ねる。
//   - dot size = avatarSize * 0.27
//   - online: #7BD389 + 0 0 8px の glow
//   - offline: #3F3F4A
//   - 2px ベース色ボーダー(背景に溶け込ませる)

private struct AvatarWithStatusDot: View {
    let url: URL?
    let initials: String
    let color: Color
    var size: CGFloat = 62
    let online: Bool
    let dim: Bool

    private var dotSize: CGFloat { size * 0.27 }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RemoteAvatarView(
                url: url,
                initials: initials,
                color: color,
                size: size,
                strokeColor: Color.white.opacity(0.08),
                strokeWidth: 1.5,
                dim: dim
            )

            Circle()
                .fill(online ? Color.pairtuneSyncOk : Color(hex: "3F3F4A"))
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    Circle().stroke(Color.pairtuneBase, lineWidth: 2)
                )
                .shadow(color: online ? Color.pairtuneSyncOk.opacity(0.6) : .clear, radius: 4)
                .offset(x: 1, y: 1)
        }
    }
}

#Preview("State A (pre-pairing)") {
    HomeView(pairingCode: "KP3X7M")
}

#Preview("State B online") {
    HomeView(pairingCode: "KP3X7M", myName: "あなた", partnerName: "さくら", partnerOnline: true)
}

#Preview("State B offline") {
    HomeView(
        pairingCode: "KP3X7M",
        myName: "あなた",
        partnerName: "さくら",
        partnerOnline: false,
        partnerLastSeen: "2 時間前"
    )
}

#Preview("State B online + anniversary") {
    HomeView(
        pairingCode: "KP3X7M",
        myName: "あなた",
        partnerName: "さくら",
        partnerOnline: true,
        anniversary: true
    )
}
