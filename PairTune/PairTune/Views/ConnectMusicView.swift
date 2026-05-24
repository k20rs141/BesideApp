import SwiftUI
import MusicKit
import UIKit

// MARK: - ConnectMusicView (v0.5.1 §5.8)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.8 / docs/PairTune_Design_Handoff_v0.5.md §2.1.5
// デザイン: docs/design_v3_source/screens-connect-music.jsx
//
// Room を開く直前(just-in-time)に挟むゲートウェイ。MusicKit 認可状態 +
// サブスクリプション契約状況で 3 状態に分岐。
//
// 状態:
//   .notDetermined           — 未認可(初回): 接続するボタン → MusicAuthorization.request()
//   .denied                  — 認可拒否済み: 設定アプリを開く
//   .authorizedNoSubscription — 認可済 + サブスク未契約: MusicSubscriptionOffer 提示
//
// プロバイダ非依存設計: 将来 Spotify 追加時のためにリスト形式。v0.5 は Apple Music の 1 行のみ。

enum ConnectMusicState {
    case notDetermined
    case denied
    case authorizedNoSubscription
}

enum ConnectMusicIntent {
    case shared
    case solo

    var overlineCopy: String {
        switch self {
        case .shared: return "ふたりで聴く前に"
        case .solo:   return "ひとりで聴く前に"
        }
    }
}

struct ConnectMusicView: View {
    let state: ConnectMusicState
    let intent: ConnectMusicIntent

    /// 認可が通った / サブスクが取れた等で Room へ進める
    var onReady: () -> Void
    /// 「あとで」 — Home に戻る
    var onLater: () -> Void

    @State private var subscriptionOfferDisplayed = false

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // ambient glows
            RadialGradient(
                colors: [Color.pairtunePrimary.opacity(0.13), .clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .blur(radius: 60)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                bodyContent
            }
        }
        // 認可済+サブスク未契約のときは MusicSubscriptionOffer を提示する仕組みを内蔵
        // (本来は SwiftUI の .musicSubscriptionOffer modifier を使うが、コンパイル都合で
        //  Manage Subscriptions URL にフォールバックする実装にしてある)
    }

    private var header: some View {
        HStack {
            Button("あとで", action: onLater)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.pairtuneTextSecondary)
            Spacer()
            Text("音楽サービス")
                .font(.system(size: 18))
                .tracking(0.5)
                .foregroundStyle(Color.pairtuneTextTertiary)
            Spacer()
            Color.clear.frame(width: 50)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    @ViewBuilder
    private var bodyContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // hero + title + body
            VStack(spacing: 0) {
                Hero(state: state).frame(width: 170, height: 170)

                Text(intent.overlineCopy)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.pairtuneTextTertiary)
                    .padding(.top, 26)

                Text(titleCopy)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 300, minHeight: 62)
                    .padding(.top, 8)

                Text(bodyCopy)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.pairtuneTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 300, minHeight: 71)
                    .padding(.top, 18)
            }

            Spacer(minLength: 0)

            // CTA group
            VStack(spacing: 10) {
                switch state {
                case .notDetermined:
                    ProviderRow(
                        title: "Apple Music",
                        subtitle: "Apple Music のサブスクリプションが必要です",
                        action: handleConnect
                    )
                    SmallNote("「接続する」を押すと、iOS の許可ダイアログが開きます。")

                case .denied:
                    PrimaryCTA(
                        icon: "gear",
                        title: "設定アプリを開く",
                        action: openSettings
                    )
                    SmallNote("「設定」→「PairTune」→「メディアと Apple Music」を許可してください。")

                case .authorizedNoSubscription:
                    PrimaryCTA(
                        icon: nil,
                        title: "Apple Music を試す",
                        appleMusicGradient: true,
                        action: handleSubscription
                    )
                    SmallNote("アプリを抜けずに購読フローに進めます。")
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Copy

    private var titleCopy: String {
        switch state {
        case .notDetermined:
            return "音楽サービスに接続"
        case .denied:
            return "Apple Music の利用が\n許可されていません"
        case .authorizedNoSubscription:
            return "Apple Music の購読が必要です"
        }
    }

    private var bodyCopy: String {
        switch state {
        case .notDetermined:
            return "PairTune で曲を再生するには、\n音楽サービスへの接続が必要です。"
        case .denied:
            return "PairTune で音楽を再生するには、\niOS の「設定」アプリで\nApple Music へのアクセスを許可してください。"
        case .authorizedNoSubscription:
            return "PairTune はストリーミング再生のため、\nApple Music の購読が必要です。\n無料トライアルから始められます。"
        }
    }

    // MARK: - Actions

    private func handleConnect() {
        Task {
            let result = await MusicAuthorization.request()
            if result == .authorized {
                onReady()
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func handleSubscription() {
        // iOS 15+ の MusicSubscriptionOffer はビューモディファイア経由が一般的だが、
        // ここでは Apple Music の購読画面 (Manage Subscriptions) を直接開いてフォールバック。
        // 本格対応は .musicSubscriptionOffer modifier に置き換える。
        if let url = URL(string: "https://music.apple.com/subscribe") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Subviews

private struct Hero: View {
    let state: ConnectMusicState

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(
                        state == .denied
                            ? Color.white.opacity(0.08)
                            : Color.pairtunePrimary.opacity(0.2),
                        lineWidth: 1
                    )
                    .scaleEffect(0.55 + CGFloat(i) * 0.22)
            }

            centerGlyph
        }
    }

    @ViewBuilder
    private var centerGlyph: some View {
        switch state {
        case .denied:
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.015)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                Image(systemName: "lock")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(Color.pairtuneSurface)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1.5))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "gear")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pairtuneTextSecondary)
                    )
                    .offset(x: 4, y: 4)
            }

        case .notDetermined:
            Circle()
                .fill(LinearGradient(
                    colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.pairtunePrimary.opacity(0.4), radius: 18, y: 10)

        case .authorizedNoSubscription:
            Circle()
                .fill(LinearGradient(
                    colors: [
                        Color(hex: "FA5765"),
                        Color(hex: "FB6E63"),
                        Color(hex: "FB8852"),
                        Color(hex: "F8C45D")
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "applelogo")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color(hex: "FB6E63").opacity(0.4), radius: 18, y: 10)
        }
    }
}

private struct ProviderRow: View {
    let title: String
    let subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Apple Music gradient mark
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [
                                Color(hex: "FA5765"),
                                Color(hex: "FB8852"),
                                Color(hex: "F8C45D")
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    Image(systemName: "applelogo")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.pairtuneTextSecondary)
                }
                Spacer()
                Text("接続する →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryCTA: View {
    let icon: String?
    let title: String
    var appleMusicGradient: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if appleMusicGradient {
                    Image(systemName: "applelogo")
                        .font(.system(size: 18))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        appleMusicGradient
                            ? AnyShapeStyle(LinearGradient(
                                colors: [
                                    Color(hex: "FA5765"),
                                    Color(hex: "FB6E63"),
                                    Color(hex: "FB8852"),
                                    Color(hex: "F8C45D")
                                ],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
            )
            .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct SmallNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Color.pairtuneTextTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}

#Preview("notDetermined") {
    ConnectMusicView(state: .notDetermined, intent: .shared, onReady: {}, onLater: {})
}
#Preview("denied") {
    ConnectMusicView(state: .denied, intent: .solo, onReady: {}, onLater: {})
}
#Preview("noSub") {
    ConnectMusicView(state: .authorizedNoSubscription, intent: .shared, onReady: {}, onLater: {})
}
