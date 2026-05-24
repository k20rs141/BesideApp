import Foundation
import SwiftUI

// MARK: - PlayHistoryEntry → ContextSession グルーピング
//
// 仕様: docs/PairTune_Specification_v0.5.md §7-3 / docs/PairTune_Decision_Log_v0.5.md §7-1
//   - shared_room_play_history を「セッション単位」にまとめる
//   - セッション境界: 連続再生の間隔が 30 分以上空いたら別セッション
//   - 時間帯ラベル: 朝(5-11) / 昼(11-17) / 夜(17-23) / 深夜(23-5)
//   - 月境界には MonthMark を挿入(2026 - 5 のように表示)
//
// クライアント側集約(差分取得 + SwiftData キャッシュ)を想定した軽量実装。

enum ContextSessionGrouping {
    private static let sessionGapSeconds: TimeInterval = 30 * 60

    /// shared_room_play_history を ContextSession 配列に変換する。
    /// `entries` は playedAt 降順を想定(newest first)。
    static func sessions(from entries: [PlayHistoryEntry]) -> [ContextSession] {
        guard !entries.isEmpty else { return [] }

        // playedAt 昇順に直してから 30 分ギャップで切る(時系列が自然に進むため)
        let chrono = entries.sorted { $0.playedAt < $1.playedAt }

        var raw: [[PlayHistoryEntry]] = []
        var current: [PlayHistoryEntry] = []
        var lastPlayedAt: Date?

        for e in chrono {
            if let last = lastPlayedAt, e.playedAt.timeIntervalSince(last) > sessionGapSeconds {
                raw.append(current)
                current = []
            }
            current.append(e)
            lastPlayedAt = e.playedAt
        }
        if !current.isEmpty { raw.append(current) }

        // newest-first に戻す(画面では新しいセッションを上に出す)
        let descGroups = raw.reversed()

        // Month marker は「月が切り替わるとき」に挿入する
        let cal = Calendar(identifier: .gregorian)
        var result: [ContextSession] = []
        var prevMonth: DateComponents? = nil

        for group in descGroups {
            guard let firstEntry = group.first else { continue }
            let comps = cal.dateComponents([.year, .month], from: firstEntry.playedAt)
            if let prev = prevMonth, prev != comps {
                let label = "\(prev.year ?? 0) - \(String(format: "%d", prev.month ?? 0))"
                result.append(ContextSession(id: "month-\(prev.year ?? 0)-\(prev.month ?? 0)", kind: .monthMark, label: label))
            }
            result.append(buildSession(from: group))
            prevMonth = comps
        }
        return result
    }

    // MARK: - Session 構築

    private static func buildSession(from group: [PlayHistoryEntry]) -> ContextSession {
        guard let head = group.first, let tail = group.last else {
            return ContextSession(id: UUID().uuidString, kind: .session, label: "")
        }

        let totalSeconds = group.reduce(0) { $0 + $1.playedDurationSeconds }
        let dateLabel = formatDateWithBucket(head.playedAt)
        let bucket = timeBucket(of: head.playedAt)
        let hasFirstPlay = group.contains { $0.isFirstPlay == true }

        let id = "session-\(Int(tail.playedAt.timeIntervalSince1970))-\(Int(head.playedAt.timeIntervalSince1970))"

        let story: String? = hasFirstPlay
            ? "✨ \(group.first(where: { $0.isFirstPlay == true })?.songTitle ?? "新しい曲")を初めて聴いた\(bucket.name)。"
            : nil

        let tracks = group.prefix(3).map { entry -> ContextSessionTrack in
            ContextSessionTrack(
                id: entry.id,
                title: entry.songTitle,
                artist: entry.artistName,
                gradientStart: gradientStart(for: entry.songId),
                gradientEnd: gradientEnd(for: entry.songId)
            )
        }

        return ContextSession(
            id: id,
            kind: .session,
            label: dateLabel,
            count: group.count,
            durationLabel: formatDuration(seconds: totalSeconds),
            icon: bucket.icon,
            special: hasFirstPlay,
            story: story,
            tracks: tracks
        )
    }

    // MARK: - 時間帯バケット

    private struct TimeBucket {
        let name: String
        let icon: String
    }

    private static func timeBucket(of date: Date) -> TimeBucket {
        let hour = Calendar(identifier: .gregorian).component(.hour, from: date)
        switch hour {
        case 5..<11:  return TimeBucket(name: "朝", icon: "☀️")
        case 11..<17: return TimeBucket(name: "昼", icon: "☀️")
        case 17..<23: return TimeBucket(name: "夜", icon: "🌙")
        default:      return TimeBucket(name: "深夜", icon: "✨")
        }
    }

    private static func formatDateWithBucket(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return "\(f.string(from: date))の\(timeBucket(of: date).name)"
    }

    private static func formatDuration(seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m) 分" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) 時間" : "\(h) 時間 \(rem) 分"
    }

    // MARK: - グラデーション(songId のハッシュから決定的に選ぶ)

    private static let palette: [(Color, Color)] = [
        (Color(hex: "9B7BFF"), Color(hex: "2E0E2A")),
        (Color(hex: "FF6B9D"), Color(hex: "4A0A2E")),
        (Color(hex: "F4C26A"), Color(hex: "B8753C")),
        (Color(hex: "7BD389"), Color(hex: "1D4A2E")),
        (Color(hex: "6BB6F0"), Color(hex: "1D3B4A")),
        (Color(hex: "C49AF4"), Color(hex: "4A1D5E")),
        (Color(hex: "A8D8E4"), Color(hex: "1D3B4A"))
    ]

    private static func paletteIndex(for songId: String) -> Int {
        let hash = songId.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0x7FFFFFFF }
        return hash % palette.count
    }

    static func gradientStart(for songId: String) -> Color {
        palette[paletteIndex(for: songId)].0
    }
    static func gradientEnd(for songId: String) -> Color {
        palette[paletteIndex(for: songId)].1
    }
}

// MARK: - PlayHistoryEntry → SoloContextTrackCard

extension PlayHistoryEntry {
    /// 横スクロールカード用の軽量データに変換
    func toContextTrackCard() -> SoloContextTrackCard {
        SoloContextTrackCard(
            id: id,
            title: songTitle,
            artist: artistName,
            gradientStart: ContextSessionGrouping.gradientStart(for: songId),
            gradientEnd: ContextSessionGrouping.gradientEnd(for: songId)
        )
    }
}
