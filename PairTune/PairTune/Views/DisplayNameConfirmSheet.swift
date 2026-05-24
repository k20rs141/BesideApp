import SwiftUI
import SwiftData

// MARK: - DisplayNameConfirmSheet (v0.5.1 §5.9)
//
// 仕様: docs/PairTune_Specification_v0.5.md §5.9 / Design Handoff §2.1.6
//
// 初回プロフィール入力画面は作らない。代わりに「相手に名前が見える初回操作時」に
// 1 回だけソフト確認シートを出す:
//   1. 自分のコードを ShareLink でコピー/共有する初回
//   2. ペアリング申請を送る初回(コード入力後)
//   3. ペアリング申請を承認する初回(承認モーダル直前)
//
// 表示後は AppState.displayNameConfirmedAt を埋めて、2 回目以降は出さない。
// Profile からはいつでも変更できる。

struct DisplayNameConfirmSheet: View {
    /// 初期値(Apple Sign In 由来 → なければ「あなた」)
    let initialName: String
    /// 「これで進む」を押した時、確定した名前で続行する
    var onConfirm: (String) -> Void
    /// 戻る/閉じる(元の操作をキャンセル)
    var onCancel: () -> Void

    @State private var name: String = ""
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    var body: some View {
        VStack(spacing: 0) {
            // grabber
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 38, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 18)

            VStack(spacing: 6) {
                Text("相手に表示する名前を確認")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(0.2)
                Text("相手にはこの名前で表示されます")
                    .font(.system(size: 12))
                    .foregroundColor(Color.pairtuneTextSecondary)
            }
            .padding(.bottom, 18)

            HStack(spacing: 11) {
                TextField("", text: $name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.pairtunePrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.pairtunePrimary.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 22)
            .padding(.bottom, 22)

            Button(action: confirm) {
                Text("これで進む")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.pairtunePrimary, Color.pairtuneSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: Color.pairtunePrimary.opacity(0.3), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)

            Text("この確認は今回だけ。あとでプロフィールから変更できます")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "5A5566"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 24)
        }
        .background(Color.pairtuneSurface)
        .onAppear {
            name = name.isEmpty ? initialName : name
        }
    }

    private func confirm() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "あなた" : trimmed
        markConfirmed()
        onConfirm(finalName)
    }

    private func markConfirmed() {
        let state: AppState
        if let existing = appStates.first {
            state = existing
        } else {
            state = AppState()
            modelContext.insert(state)
        }
        state.displayNameConfirmedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Helper: 表示名確認が必要か?

extension AppState {
    /// 「相手に名前が見える初回操作」の前に確認シートを出すべきか
    var needsDisplayNameConfirmation: Bool {
        displayNameConfirmedAt == nil
    }
}

#Preview {
    DisplayNameConfirmSheet(
        initialName: "さくら",
        onConfirm: { _ in },
        onCancel: {}
    )
    .modelContainer(for: AppState.self, inMemory: true)
}
