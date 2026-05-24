import Foundation
import SwiftData

// MARK: - AppState (SwiftData / CloudKit)
//
// 仕様: docs/PairTune_Decision_Log_v0.5.md §1, §8-2
//   - オンボーディング完了フラグは Supabase に持たない(個人設定なので端末側で管理)
//   - SwiftData + CloudKit で端末間同期(複数端末で再表示しない)
//   - 表示名の初回確認フラグも同様に SwiftData で持つ(`displayNameConfirmedAt`)
//
// CloudKit 同期前提:
//   - 全プロパティに既定値必須 (CloudKit 制約) — 準拠済み
//   - .modelContainer(for: AppState.self) を CloudKit option 付きで導入する
//   - 実際の CloudKit container 設定は Entitlements / Capabilities で別途必要
//
// 単一行モデル: ユーザーごとに 1 つだけ存在する想定。
// 初回ロード時に存在しなければ作成する。

@Model
final class AppState {
    // オンボーディング完了
    var onboardingCompleted: Bool = false
    var onboardingCompletedAt: Date? = nil

    // 相手に表示する名前を最後に確認した時刻
    // nil = まだ一度も確認していない(初回操作時にソフトシートを出す)
    // 仕様: v0.5.1 §5.9 / Design Handoff §2.1.6
    var displayNameConfirmedAt: Date? = nil

    init(
        onboardingCompleted: Bool = false,
        onboardingCompletedAt: Date? = nil,
        displayNameConfirmedAt: Date? = nil
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.onboardingCompletedAt = onboardingCompletedAt
        self.displayNameConfirmedAt = displayNameConfirmedAt
    }
}
