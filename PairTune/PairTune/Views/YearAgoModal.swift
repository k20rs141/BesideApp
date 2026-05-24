import SwiftUI

// MARK: - YearAgoModal (v0.5 §8-5-1)
//
// 仕様: docs/PairTune_Specification_v0.5.md §8-5-1 / Design Handoff §2.10
// デザイン: docs/design_v3_source/screens-memory.jsx
//
// 「過去のふたり」体験の最も emotional な機能。1 年前の今日、ふたりで聴いていた曲を提示する。
// 全画面、グラデーション背景、半透明グラスカード上にアートワーク + 曲名。
//
// データソース: shared_room_play_history で played_at が約 365 日前のレコードを抽出して提示。

struct YearAgoModal: View {
    /// 1 年前に聴いた曲(代表 1 曲)
    let songTitle: String
    let artistName: String
    let artworkUrl: String?
    /// 「2025年5月8日 22:47」のような表示用日時
    let whenLabel: String

    /// 「ふたりでもう一度聴く」(Shared room)
    var onListenShared: () -> Void = {}
    /// 「ひとりで聴く」(Solo room)
    var onListenSolo: () -> Void = {}
    /// 閉じる
    var onClose: () -> Void = {}

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                // close button
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)

                Spacer(minLength: 0)

                envelopeIcon
                    .padding(.bottom, 18)

                Text("1 年前の今日")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.white)
                    .tracking(0.4)

                Text(whenLabel)
                    .font(.system(size: 13))
                    .foregroundColor(Color.pairtuneTextSecondary)
                    .padding(.top, 6)

                Text("ふたりで聴いていた曲")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "7A7588"))
                    .tracking(0.4)
                    .padding(.top, 18)

                glassCard
                    .padding(.horizontal, 32)
                    .padding(.top, 22)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button(action: onListenShared) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14))
                            Text("ふたりでもう一度聴く")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(
                                    colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .shadow(color: Color.pairtunePrimary.opacity(0.33), radius: 16, y: 8)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onListenSolo) {
                        Text("ひとりで聴く")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 38)
            }
        }
    }

    private var envelopeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.pairtunePrimary.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(Color.pairtunePrimary.opacity(0.19), lineWidth: 0.5)
                )
                .frame(width: 50, height: 50)
            Image(systemName: "envelope.fill")
                .font(.system(size: 22))
                .foregroundColor(.pairtunePrimary)
        }
    }

    private var glassCard: some View {
        VStack(spacing: 14) {
            artwork
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 12)

            VStack(spacing: 4) {
                Text(songTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(artistName)
                    .font(.system(size: 13))
                    .foregroundColor(Color.pairtuneTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .background(
                    // simulated glass via blur underlay (実機では .ultraThinMaterial を使うと良い)
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.black.opacity(0.18))
                )
        )
    }

    @ViewBuilder
    private var artwork: some View {
        if let urlString = artworkUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: placeholderGradient
                }
            }
        } else {
            placeholderGradient
        }
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "FFA76C"),
                Color(hex: "B85B3C"),
                Color(hex: "5A1F2E")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var background: some View {
        ZStack {
            Color.pairtuneBase
            RadialGradient(
                colors: [Color.pairtunePrimary.opacity(0.19), .clear],
                center: UnitPoint(x: 0.6, y: 0.1),
                startRadius: 0, endRadius: 400
            )
            RadialGradient(
                colors: [Color.pairtuneSecondary.opacity(0.16), .clear],
                center: UnitPoint(x: 0.2, y: 0.8),
                startRadius: 0, endRadius: 400
            )
        }
    }
}

#Preview {
    YearAgoModal(
        songTitle: "Cruel Summer",
        artistName: "Taylor Swift",
        artworkUrl: nil,
        whenLabel: "2025年5月8日 22:47"
    )
}
