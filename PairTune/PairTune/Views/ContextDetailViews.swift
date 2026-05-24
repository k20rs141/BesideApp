import SwiftUI

// MARK: - Context Detail Views (v0.5)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.7 / Design Handoff §1
// デザイン: docs/design_v3_source/screens-context-detail.jsx
//
// SoloContextView / SharedContextView の「すべて見る」「開く」から push される 3 つの詳細画面:
//   1. AllSessionsView         — 「ふたりの軌跡」全期間タイムライン
//   2. SessionDetailView       — セッション 1 つの全曲リスト
//   3. PairPlaylistDetailView  — 「ふたりのプレイリスト」全曲リスト
//
// ContextHeader は SharedContextView.swift で定義済みのものを共通利用。

// MARK: - AllSessionsView

struct AllSessionsView: View {
    let sessions: [ContextSession]
    let totalDays: Int
    let totalSongs: Int
    let totalDurationLabel: String

    var onBack: () -> Void = {}
    var onSelectSession: (ContextSession) -> Void = { _ in }

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // ambient glow を Color.clear.overlay でラップし、frame(600) で layout box を
            // 引き伸ばさないようにする(直接 ZStack の子に置くと右側にはみ出す)
            Color.clear
                .overlay {
                    Ellipse()
                        .fill(Color.pairtunePrimary.opacity(0.13))
                        .frame(width: 600, height: 380)
                        .blur(radius: 60)
                        .offset(y: -240)
                        .allowsHitTesting(false)
                }
                .clipped()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ContextHeader(title: "ふたりの軌跡", onBack: onBack)
                        .padding(.top, 4)
                        .padding(.bottom, 14)

                    statsCard
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)

                    SharedTimelineView(sessions: sessions)
                        .padding(.horizontal, 18)

                    Text("ここから、ふたりの音楽が始まりました。")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "5A5566"))
                        .padding(.leading, 64)
                        .padding(.top, 6)
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipped()
        }
        .clipped()
    }

    private var statsCard: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            stat(num: "\(totalDays)", label: "日")
            stat(num: "\(totalSongs)", label: "曲")
            stat(num: totalDurationLabel.isEmpty ? "—" : totalDurationLabel, label: "一緒に")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [Color.pairtunePrimary.opacity(0.09), Color.pairtuneSecondary.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(Color.pairtunePrimary.opacity(0.16), lineWidth: 0.5)
                )
        )
    }

    private func stat(num: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(num)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: "7A7588"))
                .tracking(0.3)
        }
    }
}

// MARK: - SessionDetailView

struct SessionDetailView: View {
    let session: ContextSession
    /// セッション内の全曲(ContextSessionTrack の prefix 3 ではなく、全部)
    let allTracks: [ContextSessionTrack]

    var onBack: () -> Void = {}
    var onSelectTrack: (ContextSessionTrack) -> Void = { _ in }
    var onPlayAll: () -> Void = {}

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            Color.clear
                .overlay {
                    Ellipse()
                        .fill(Color.pairtunePrimary.opacity(0.13))
                        .frame(width: 600, height: 380)
                        .blur(radius: 60)
                        .offset(y: -240)
                        .allowsHitTesting(false)
                }
                .clipped()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ContextHeader(title: "セッション", onBack: onBack)
                        .padding(.top, 4)

                    // hero
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 9) {
                            Text(session.icon).font(.system(size: 22))
                            Text(session.label)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("\(session.count) 曲 · \(session.durationLabel)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.pairtuneTextSecondary)

                        if let story = session.story {
                            Text(story)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "C9C2DD"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    HStack(spacing: 0) {
                                        Rectangle().fill(Color.pairtunePrimary.opacity(0.45)).frame(width: 2)
                                        Color.pairtunePrimary.opacity(0.08)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                )
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 22)

                    Button(action: onPlayAll) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("全曲を再生")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(
                                    colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 12, y: 6)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)

                    // tracks
                    VStack(spacing: 0) {
                        ForEach(Array(allTracks.enumerated()), id: \.element.id) { idx, t in
                            Button { onSelectTrack(t) } label: {
                                TrackRowSmall(index: idx + 1, track: t)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipped()
        }
        .clipped()
    }
}

// MARK: - PairPlaylistDetailView

struct PairPlaylistDetailView: View {
    let tracks: [PairPlaylistTrack]

    var onBack: () -> Void = {}
    var onSelectTrack: (PairPlaylistTrack) -> Void = { _ in }
    var onPlayAll: () -> Void = {}
    var onShuffle: () -> Void = {}
    var onRemove: ((PairPlaylistTrack) -> Void)? = nil

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            Color.clear
                .overlay {
                    Ellipse()
                        .fill(Color.pairtunePrimary.opacity(0.13))
                        .frame(width: 600, height: 380)
                        .blur(radius: 60)
                        .offset(y: -240)
                        .allowsHitTesting(false)
                }
                .clipped()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ContextHeader(title: "ふたりのプレイリスト", onBack: onBack)
                        .padding(.top, 4)

                    hero
                        .padding(.horizontal, 22)

                    HStack(spacing: 10) {
                        Button(action: onPlayAll) {
                            playPill(icon: "play.fill", text: "全曲再生", primary: true)
                        }
                        .buttonStyle(.plain)
                        Button(action: onShuffle) {
                            playPill(icon: "shuffle", text: "シャッフル", primary: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)

                    if tracks.isEmpty {
                        Text("まだ何も追加されていません。\nRoom で ★ ボタンを押して残しましょう。")
                            .font(.system(size: 12))
                            .foregroundColor(Color.pairtuneTextSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, t in
                                PlaylistRow(
                                    index: idx + 1,
                                    track: t,
                                    onTap: { onSelectTrack(t) },
                                    onRemove: onRemove.map { remove in { remove(t) } }
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 60)
            }
            .clipped()
        }
        .clipped()
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            mosaic
            VStack(alignment: .leading, spacing: 4) {
                Text("ふたりのプレイリスト")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("\(tracks.count) 曲")
                    .font(.system(size: 11))
                    .foregroundColor(Color.pairtuneTextSecondary)
                Text("追加順 · ふたりだけ")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "7A7588"))
            }
            Spacer(minLength: 0)
        }
    }

    private var mosaic: some View {
        let display = Array(tracks.prefix(4))
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                mosaicTile(display.first)
                mosaicTile(display.indices.contains(1) ? display[1] : nil)
            }
            HStack(spacing: 0) {
                mosaicTile(display.indices.contains(2) ? display[2] : nil)
                mosaicTile(display.indices.contains(3) ? display[3] : nil)
            }
        }
        .frame(width: 108, height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
    }

    @ViewBuilder
    private func mosaicTile(_ t: PairPlaylistTrack?) -> some View {
        if let t {
            LinearGradient(
                colors: [t.gradientStart, t.gradientEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(width: 54, height: 54)
        } else {
            Color.white.opacity(0.04).frame(width: 54, height: 54)
        }
    }

    private func playPill(icon: String, text: String, primary: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(text).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(primary ? .white : .pairtunePrimary)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(primary
                      ? AnyShapeStyle(LinearGradient(
                            colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.white.opacity(0.04)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(primary ? Color.white.opacity(0.18) : Color.pairtunePrimary.opacity(0.27), lineWidth: 0.5)
                )
        )
    }

}

// MARK: - Track row (Session / Playlist 共通の小行)

private struct TrackRowSmall: View {
    let index: Int
    let track: ContextSessionTrack

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "5A5566"))
                .frame(width: 24, alignment: .center)
            TrackArtworkTile(
                url: track.artworkUrl,
                gradientStart: track.gradientStart,
                gradientEnd: track.gradientEnd,
                size: 38,
                cornerRadius: 6
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 11))
                    .foregroundColor(Color.pairtuneTextSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

private struct PlaylistRow: View {
    let index: Int
    let track: PairPlaylistTrack
    var onTap: () -> Void
    var onRemove: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "5A5566"))
                    .frame(width: 24, alignment: .center)
                TrackArtworkTile(
                    url: track.artworkUrl,
                    gradientStart: track.gradientStart,
                    gradientEnd: track.gradientEnd,
                    size: 42,
                    cornerRadius: 6
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(track.artist)
                            .font(.system(size: 11))
                            .foregroundColor(Color.pairtuneTextSecondary)
                            .lineLimit(1)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(Color.pairtuneTextTertiary)
                        Text(track.addedByLabel)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(track.addedByLabel == "あなた" ? Color.pairtunePrimary : Color.pairtuneSecondary)
                    }
                }
                Spacer(minLength: 0)
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Color.pairtuneTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("AllSessions") {
    AllSessionsView(
        sessions: [
            ContextSession(id: "s1", kind: .session, label: "5月16日の夜", count: 8, durationLabel: "42 分", icon: "🌙", special: true)
        ],
        totalDays: 32, totalSongs: 47, totalDurationLabel: "5 時間 23 分"
    )
}

#Preview("SessionDetail") {
    SessionDetailView(
        session: ContextSession(id: "s1", kind: .session, label: "5月16日の夜",
                                count: 3, durationLabel: "12 分", icon: "🌙", special: true,
                                story: "✨ 「Never Goodbye」を初めて聴いた夜。"),
        allTracks: [
            ContextSessionTrack(id: "t1", title: "Never Goodbye", artist: "NCT DREAM",
                                gradientStart: Color.pairtunePrimary, gradientEnd: Color(hex: "2E0E2A")),
            ContextSessionTrack(id: "t2", title: "Through the Night", artist: "IU",
                                gradientStart: Color.pairtuneSecondary, gradientEnd: Color(hex: "4A0A2E"))
        ]
    )
}

#Preview("PairPlaylistDetail") {
    PairPlaylistDetailView(
        tracks: [
            PairPlaylistTrack(id: "p1", title: "Never Goodbye", artist: "NCT DREAM",
                              gradientStart: Color.pairtunePrimary, gradientEnd: Color(hex: "2E0E2A"),
                              addedByLabel: "あなた"),
            PairPlaylistTrack(id: "p2", title: "Through the Night", artist: "IU",
                              gradientStart: Color.pairtuneSecondary, gradientEnd: Color(hex: "4A0A2E"),
                              addedByLabel: "さくら")
        ]
    )
}
