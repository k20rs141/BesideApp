import SwiftUI

// MARK: - SoloContextView (v0.5 §5.7)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.7 / Decision Log §7-3
// デザイン: docs/design_v3_source/screens-solo-context.jsx (案 D タイムライン)
//
// 旧 SoloModeScreen(hub 起点)を廃止し、Solo Room から push で開く文脈画面に役割変更。
// NowPlaying は載せない(RoomScreen 側)。Push なので header は ← back。
//
// 状態:
//   .empty    ペアあり、共有履歴なし → ふたりの軌跡セクションは EmptyState
//   .full     ペアあり、共有履歴あり → 全セクション表示
//   .memory   解消後、preserve_memories=TRUE → 軌跡は閲覧専用(dim) + MemoryRibbon
//   .deleted  解消後、preserve_memories=FALSE → 軌跡セクションを撤去 + DeletedNote

enum SoloContextState {
    case empty
    case full
    case memory
    case deleted
}

/// 横スクロールカード用の軽量データ型(MyRecent / PartnerFavs)
struct SoloContextTrackCard: Identifiable {
    let id: String
    let title: String
    let artist: String
    let gradientStart: Color
    let gradientEnd: Color
}

struct SoloContextView: View {
    var state: SoloContextState = .full

    /// 「ふたりの軌跡」セクションのセッション(SharedContextView と同じ ContextSession 型)
    var sessions: [ContextSession] = []
    /// 「あなたが最近聴いた曲」(横スクロール 8 曲)
    var myRecent: [SoloContextTrackCard] = []
    /// 「さくら さんのお気に入り」(横スクロールカード、v1.1)
    var partnerFavs: [SoloContextTrackCard] = []
    /// 相手の表示名(セクションラベルに使う)
    var partnerName: String = "さくら"

    var onBack: () -> Void = {}
    var onSelectTrack: (SoloContextTrackCard) -> Void = { _ in }
    var onSelectSessionTrack: (ContextSessionTrack) -> Void = { _ in }
    var onSeeAllSessions: () -> Void = {}

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()
            ambientGlow

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    ContextHeader(title: "ふたりで聴いた曲", onBack: onBack)
                        .padding(.top, 4)

                    if state == .memory {
                        MemoryRibbon()
                            .padding(.horizontal, 18)
                    } else if state == .deleted {
                        DeletedNote()
                            .padding(.horizontal, 18)
                    }

                    // Section 1: ふたりの軌跡
                    if state != .deleted {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("ふたりの軌跡")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(0.3)
                                Spacer()
                                if state == .full {
                                    Button(action: onSeeAllSessions) {
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
                            .padding(.horizontal, 4)

                            if state == .empty {
                                ContextEmptyCard(
                                    title: "まだ一緒に聴いていません",
                                    hint: "\(partnerName) さんと部屋を開くと、ここに軌跡が描かれていきます。"
                                )
                            } else {
                                SharedTimelineView(sessions: sessions, onSelectTrack: onSelectSessionTrack)
                                    .opacity(state == .memory ? 0.6 : 1.0)
                                    .saturation(state == .memory ? 0.5 : 1.0)
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    // Section 2: あなたが最近聴いた曲
                    Section2HorizontalScroll(
                        label: "あなたが最近聴いた曲",
                        items: myRecent,
                        onSelect: onSelectTrack
                    )

                    // Section 3: 相手のお気に入り(full のみ)
                    if state == .full && !partnerFavs.isEmpty {
                        Section2HorizontalScroll(
                            label: "\(partnerName) さんのお気に入り",
                            items: partnerFavs,
                            favorite: true,
                            onSelect: onSelectTrack
                        )
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }

    private var ambientGlow: some View {
        Ellipse()
            .fill(Color.pairtunePrimary.opacity((state == .memory || state == .deleted) ? 0.09 : 0.15))
            .frame(width: 600, height: 380)
            .blur(radius: 60)
            .offset(y: -240)
            .allowsHitTesting(false)
    }
}

// MARK: - Empty / Memory / Deleted notes

private struct ContextEmptyCard: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(hint)
                .font(.system(size: 12))
                .foregroundColor(Color.pairtuneTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundColor(Color.pairtunePrimary.opacity(0.27))
                )
        )
    }
}

private struct MemoryRibbon: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.pairtuneTextSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("ペアリングは終了しました")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text("思い出は閲覧専用で残っています")
                    .font(.system(size: 11))
                    .foregroundColor(Color.pairtuneTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
    }
}

private struct DeletedNote: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "music.note")
                .font(.system(size: 12))
                .foregroundColor(.pairtunePrimary)
            Text("あなたの音楽空間です")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pairtunePrimary.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.pairtunePrimary.opacity(0.16), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Horizontal scroll section

private struct Section2HorizontalScroll: View {
    let label: String
    let items: [SoloContextTrackCard]
    var favorite: Bool = false
    var onSelect: (SoloContextTrackCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .tracking(0.3)
                .padding(.leading, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        MiniCard(item: item, favorite: favorite) { onSelect(item) }
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }
}

private struct MiniCard: View {
    let item: SoloContextTrackCard
    var favorite: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [item.gradientStart, item.gradientEnd],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 112, height: 112)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

                    if favorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .padding(6)
                    }
                }
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.artist)
                    .font(.system(size: 11))
                    .foregroundColor(Color.pairtuneTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

#Preview("full") {
    SoloContextView(
        state: .full,
        sessions: [
            ContextSession(id: "s1", kind: .session, label: "5月16日の夜",
                           count: 8, durationLabel: "42 分", icon: "🌙", special: true,
                           story: "✨ 「Never Goodbye」を初めて聴いた夜。",
                           tracks: [
                            ContextSessionTrack(id: "t1", title: "Never Goodbye", artist: "NCT DREAM",
                                                gradientStart: Color.pairtunePrimary, gradientEnd: Color(hex: "2E0E2A")),
                            ContextSessionTrack(id: "t2", title: "Smoothie", artist: "NCT DREAM",
                                                gradientStart: Color(hex: "F4C26A"), gradientEnd: Color(hex: "B8753C"))
                           ])
        ],
        myRecent: [
            SoloContextTrackCard(id: "mr1", title: "Through the Night", artist: "IU",
                                 gradientStart: Color.pairtuneSecondary, gradientEnd: Color(hex: "4A0A2E")),
            SoloContextTrackCard(id: "mr2", title: "Spring Day", artist: "BTS",
                                 gradientStart: Color(hex: "C49AF4"), gradientEnd: Color(hex: "4A1D5E"))
        ],
        partnerFavs: [
            SoloContextTrackCard(id: "pf1", title: "Smoothie", artist: "NCT DREAM",
                                 gradientStart: Color(hex: "F4C26A"), gradientEnd: Color(hex: "B8753C"))
        ]
    )
}

#Preview("empty") {
    SoloContextView(state: .empty)
}

#Preview("memory") {
    SoloContextView(
        state: .memory,
        sessions: [
            ContextSession(id: "s1", kind: .session, label: "5月16日の夜",
                           count: 8, durationLabel: "42 分", icon: "🌙",
                           tracks: [])
        ]
    )
}

#Preview("deleted") {
    SoloContextView(state: .deleted)
}
