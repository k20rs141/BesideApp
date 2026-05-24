import SwiftUI

// MARK: - SharedContextView (v0.5 §5.7)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.7 / Decision Log §7
// デザイン: docs/design_v3_source/screens-shared-context.jsx
//
// Shared Room から push で開く文脈画面。Solo と対称(レイアウトの骨格は共通)。
// セクション構成:
//   1. 思い出アルバム入口     — しきい値到達で出現(v1.2 で UI 化)
//   2. ふたりの軌跡          — Timeline(セッション単位グルーピング)
//   3. ふたりのプレイリスト   — アルバム風ヒーロー(v1.1、タップで全曲画面へ)
//
// アニバーサリーバナーは発生時のみ最上部に控えめに出る。常設しない。

// MARK: - Models

/// 文脈画面のタイムラインに表示するセッション(またはマーカー)。
/// 実データへの接続は Phase 2 後半 / ViewModel 側で行う。
struct ContextSession: Identifiable {
    enum Kind { case session, monthMark }
    let id: String
    let kind: Kind
    /// セッション: "5月16日の夜" / マーカー: "2026 - 5" 等
    let label: String
    /// セッション専用: 曲数 / マーカーでは無視
    var count: Int = 0
    /// セッション専用: "42 分" など
    var durationLabel: String = ""
    /// アイコン(セッション。絵文字を想定。"🌙" "☕" "🎵" など)
    var icon: String = "🎵"
    /// 「特別なセッション」フラグ(ペア成立日 / 100日記念 など)。ドットを大きく/グラデにする。
    var special: Bool = false
    /// ストーリー文(任意)。「初めて一緒に聴いた朝」など。
    var story: String? = nil
    /// セッション内の代表トラック(最大 3 つ表示 + 残数)
    var tracks: [ContextSessionTrack] = []
}

struct ContextSessionTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    /// アートワーク色(プレースホルダーグラデの始点 / 終点)
    let gradientStart: Color
    let gradientEnd: Color
}

/// ふたりのプレイリストの 1 曲(v1.1)
struct PairPlaylistTrack: Identifiable {
    let id: String
    let title: String
    let artist: String
    let gradientStart: Color
    let gradientEnd: Color
    /// 誰が追加したか("あなた" / "さくら" 等)
    let addedByLabel: String
}

// MARK: - View

struct SharedContextView: View {
    var sessions: [ContextSession]
    var pairPlaylist: [PairPlaylistTrack]
    var totalDays: Int = 0
    var totalSongs: Int = 0
    var totalDurationLabel: String = ""

    /// 思い出アルバム入口を出すか(しきい値到達でのみ)
    var showMemoryEntry: Bool = false
    /// アニバーサリーバナー
    var anniversary: Bool = false
    var anniversaryLabel: String = "ペアリング 1 ヶ月。一緒に 47 曲。"

    var onBack: () -> Void = {}
    var onOpenMemory: () -> Void = {}
    var onSeeAllSessions: () -> Void = {}
    var onOpenPlaylist: () -> Void = {}
    var onSelectTrack: (ContextSessionTrack) -> Void = { _ in }

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // ambient glow を Color.clear.overlay でラップし、layout box を引き伸ばさない
            Color.clear
                .overlay {
                    Ellipse()
                        .fill(Color.pairtunePrimary.opacity(0.15))
                        .frame(width: 600, height: 380)
                        .blur(radius: 60)
                        .offset(y: -240)
                        .allowsHitTesting(false)
                }
                .clipped()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    ContextHeader(title: "ふたりの音楽", onBack: onBack)
                        .padding(.top, 4)

                    if anniversary {
                        AnniversaryBanner(label: anniversaryLabel)
                            .padding(.horizontal, 18)
                    }

                    if showMemoryEntry {
                        MemoryEntryCard(
                            days: totalDays,
                            songs: totalSongs,
                            durationLabel: totalDurationLabel,
                            action: onOpenMemory
                        )
                        .padding(.horizontal, 18)
                    }

                    // ふたりの軌跡
                    SharedSectionHeader(label: "ふたりの軌跡", onSeeAll: onSeeAllSessions)
                        .padding(.horizontal, 22)
                    SharedTimelineView(sessions: sessions, onSelectTrack: onSelectTrack)
                        .padding(.horizontal, 18)

                    // ふたりのプレイリスト
                    SharedSectionHeader(label: "ふたりのプレイリスト", onSeeAll: pairPlaylist.isEmpty ? nil : onOpenPlaylist)
                        .padding(.horizontal, 22)
                    Group {
                        if pairPlaylist.isEmpty {
                            PlaylistEmptyCard()
                        } else {
                            PlaylistAlbumHero(tracks: pairPlaylist, onOpen: onOpenPlaylist)
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 60)
            }
            .clipped()
        }
        .clipped()
    }
}

// MARK: - Context header (Shared と Solo で共通)

struct ContextHeader: View {
    let title: String
    var onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                    )
            }
            Spacer()
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
    }
}

// MARK: - Section header

private struct SharedSectionHeader: View {
    let label: String
    var onSeeAll: (() -> Void)?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .tracking(0.3)
            Spacer()
            if let onSeeAll {
                Button(action: onSeeAll) {
                    HStack(spacing: 3) {
                        Text("すべて見る")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.pairtunePrimary)
                }
            }
        }
    }
}

// MARK: - Anniversary banner

private struct AnniversaryBanner: View {
    let label: String

    var body: some View {
        HStack(spacing: 9) {
            Text("✨").font(.system(size: 13))
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.white)
                .tracking(0.2)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.pairtunePrimary.opacity(0.1), Color.pairtuneSecondary.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pairtunePrimary.opacity(0.19), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Memory entry card

private struct MemoryEntryCard: View {
    let days: Int
    let songs: Int
    let durationLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 54, height: 54)
                        .shadow(color: Color.pairtunePrimary.opacity(0.33), radius: 12, y: 6)
                    Text("✨").font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("ふたりの思い出アルバム")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        statValue("\(days) 日")
                        Text("· 一緒に").foregroundColor(Color.white.opacity(0.65))
                        statValue("\(songs) 曲")
                        Text("·").foregroundColor(Color.white.opacity(0.65))
                        statValue(durationLabel.isEmpty ? "—" : durationLabel)
                    }
                    .font(.system(size: 11))
                    .tracking(0.2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.pairtunePrimary.opacity(0.13),
                                Color.pairtuneSecondary.opacity(0.09)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18).stroke(Color.pairtunePrimary.opacity(0.21), lineWidth: 0.5)
                    )
                    .shadow(color: Color.pairtunePrimary.opacity(0.10), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private func statValue(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white)
            .fontWeight(.medium)
    }
}

// MARK: - Timeline

struct SharedTimelineView: View {
    let sessions: [ContextSession]
    var onSelectTrack: (ContextSessionTrack) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // vertical gradient line(2pt 幅、左寄せ x=16 で描画)
            LinearGradient(
                colors: [
                    Color.pairtunePrimary,
                    Color.pairtuneSecondary,
                    Color.pairtuneSecondary.opacity(0.6),
                    Color.pairtunePrimary.opacity(0.15)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 2)
            .offset(x: 16, y: 18)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(sessions) { s in
                    switch s.kind {
                    case .monthMark:
                        MonthMark(label: s.label)
                    case .session:
                        SessionNode(session: s, onTrack: onSelectTrack)
                    }
                }
                Text("この先にもっと、ふたりの時間が。")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "5A5566"))
                    .padding(.leading, 46)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SessionNode: View {
    let session: ContextSession
    var onTrack: (ContextSessionTrack) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        session.special
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.pairtunePrimary)
                    )
                    .frame(width: session.special ? 14 : 12, height: session.special ? 14 : 12)
                    .overlay(
                        Circle()
                            .stroke(
                                session.special
                                    ? Color.pairtuneSecondary.opacity(0.18)
                                    : Color.pairtunePrimary.opacity(0.2),
                                lineWidth: 4
                            )
                    )
                    .shadow(
                        color: session.special
                            ? Color.pairtunePrimary.opacity(0.7)
                            : Color.pairtunePrimary.opacity(0.7),
                        radius: 8
                    )
            }
            .frame(width: 32, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(session.icon).font(.system(size: 16))
                    Text(session.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("\(session.count) 曲 · \(session.durationLabel)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "7A7588"))
                    .padding(.top, 3)

                if let story = session.story {
                    Text(story)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "C9C2DD"))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.pairtunePrimary.opacity(0.45))
                                    .frame(width: 2)
                                Color.pairtunePrimary.opacity(0.08)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        )
                        .padding(.top, 8)
                }

                if !session.tracks.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(session.tracks.prefix(3)) { t in
                            Button { onTrack(t) } label: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(
                                        colors: [t.gradientStart, t.gradientEnd],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                        if session.count > session.tracks.count {
                            Text("+\(session.count - session.tracks.count)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "7A7588"))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                                .foregroundColor(Color.white.opacity(0.18))
                                        )
                                )
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.leading, 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MonthMark: View {
    let label: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.pairtunePrimary.opacity(0.4))
                .frame(width: 12, height: 2)
                .padding(.leading, 11)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(Color(hex: "7A7588"))
                .padding(.leading, 23)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Playlist album-style hero

private struct PlaylistAlbumHero: View {
    let tracks: [PairPlaylistTrack]
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                mosaicCover

                VStack(alignment: .leading, spacing: 4) {
                    Text("ふたりのプレイリスト")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(0.2)
                    Text("\(tracks.count) 曲 · ふたりだけ")
                        .font(.system(size: 11))
                        .foregroundColor(Color.pairtuneTextSecondary)
                        .tracking(0.2)
                    HStack(spacing: 4) {
                        Text("開く")
                            .font(.system(size: 11.5, weight: .medium))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.pairtunePrimary)
                    .padding(.top, 6)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [Color.pairtunePrimary.opacity(0.2), Color.pairtuneSecondary.opacity(0.14)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18).stroke(Color.pairtunePrimary.opacity(0.23), lineWidth: 0.5)
                    )
                    .shadow(color: Color.pairtunePrimary.opacity(0.10), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private var mosaicCover: some View {
        let display = Array(tracks.prefix(4))
        return ZStack(alignment: .bottomTrailing) {
            // 2x2 grid using padding-based layout
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    mosaicTile(display.first)
                    mosaicTile(display.indices.contains(1) ? display[1] : nil)
                }
                HStack(spacing: 0) {
                    mosaicTile(display.indices.contains(2) ? display[2] : nil)
                    mosaicTile(display.indices.contains(3) ? display[3] : nil)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 8)

            // small ♡ badge
            Image(systemName: "heart.fill")
                .font(.system(size: 11))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(Color.black.opacity(0.55))
                )
                .padding(5)
        }
    }

    @ViewBuilder
    private func mosaicTile(_ t: PairPlaylistTrack?) -> some View {
        if let t {
            LinearGradient(
                colors: [t.gradientStart, t.gradientEnd],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(width: 48, height: 48)
        } else {
            Color.white.opacity(0.04).frame(width: 48, height: 48)
        }
    }
}

// MARK: - Empty playlist

private struct PlaylistEmptyCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("2 人で残したい曲を、ここに。")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .tracking(0.2)
            Text("Room の再生中に「プレイリストに追加」を押すか、\n曲を長押し→「ふたりのプレイリストに残す」")
                .font(.system(size: 10.5))
                .foregroundColor(Color(hex: "7A7588"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundColor(Color.pairtuneSecondary.opacity(0.19))
                )
        )
    }
}

// MARK: - Preview

#Preview {
    SharedContextView(
        sessions: [
            ContextSession(id: "m1", kind: .monthMark, label: "2026 - 5"),
            ContextSession(
                id: "s1", kind: .session,
                label: "5月16日の夜",
                count: 8, durationLabel: "42 分",
                icon: "🌙",
                special: true,
                story: "初めて、夜更けまで一緒に。",
                tracks: [
                    ContextSessionTrack(id: "t1", title: "Never Goodbye", artist: "NCT DREAM",
                                        gradientStart: Color.pairtunePrimary, gradientEnd: Color(hex: "2E0E2A")),
                    ContextSessionTrack(id: "t2", title: "Through the Night", artist: "IU",
                                        gradientStart: Color.pairtuneSecondary, gradientEnd: Color(hex: "4A0A2E")),
                    ContextSessionTrack(id: "t3", title: "Smoothie", artist: "NCT DREAM",
                                        gradientStart: Color(hex: "F4C26A"), gradientEnd: Color(hex: "B8753C")),
                ]
            ),
            ContextSession(
                id: "s2", kind: .session,
                label: "5月14日の朝",
                count: 3, durationLabel: "14 分",
                icon: "☕",
                tracks: [
                    ContextSessionTrack(id: "t4", title: "Spring Day", artist: "BTS",
                                        gradientStart: Color(hex: "C49AF4"), gradientEnd: Color(hex: "4A1D5E"))
                ]
            )
        ],
        pairPlaylist: [
            PairPlaylistTrack(id: "p1", title: "Never Goodbye", artist: "NCT DREAM",
                              gradientStart: Color.pairtunePrimary, gradientEnd: Color(hex: "2E0E2A"),
                              addedByLabel: "あなた"),
            PairPlaylistTrack(id: "p2", title: "Through the Night", artist: "IU",
                              gradientStart: Color.pairtuneSecondary, gradientEnd: Color(hex: "4A0A2E"),
                              addedByLabel: "さくら"),
            PairPlaylistTrack(id: "p3", title: "Smoothie", artist: "NCT DREAM",
                              gradientStart: Color(hex: "F4C26A"), gradientEnd: Color(hex: "B8753C"),
                              addedByLabel: "あなた"),
            PairPlaylistTrack(id: "p4", title: "Eight", artist: "IU, SUGA",
                              gradientStart: Color.pairtuneSyncOk, gradientEnd: Color(hex: "1D4A2E"),
                              addedByLabel: "さくら"),
        ],
        totalDays: 32,
        totalSongs: 47,
        totalDurationLabel: "5 時間 23 分",
        showMemoryEntry: true,
        anniversary: true
    )
}
