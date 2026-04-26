import SwiftUI

struct CodeEntrySheet: View {
    @Binding var isPresented: Bool
    var onJoin: () -> Void
    /// 本番バリデーション closure。nil のときはモックで動作 (Preview 用)。
    /// 引数: 入力コード、戻り値: エラーメッセージ or nil (成功)
    var validateCode: ((String) async -> String?)? = nil

    @State private var code: String = ""
    @State private var errorMessage: String? = nil
    @State private var isValidating: Bool = false
    @FocusState private var isInputFocused: Bool

    private let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    var body: some View {
        ZStack {
            Color.besideSurfaceSheet.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 22)

                // Title
                Text("コードを入力")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(0.3)

                Text("Enter the 6-letter code")
                    .font(.system(size: 12.5))
                    .foregroundColor(.besideTextTertiary)
                    .tracking(0.4)
                    .padding(.top, 6)

                // Pin boxes + hidden field
                ZStack {
                    TextField("", text: $code)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isInputFocused)
                        .opacity(0.001)
                        .frame(width: 1, height: 1)
                        .onChange(of: code) { _, newVal in
                            let filtered = String(
                                newVal
                                    .uppercased()
                                    .unicodeScalars
                                    .filter { allowed.contains($0) }
                                    .map(Character.init)
                                    .prefix(6)
                            )
                            if filtered != newVal { code = filtered }
                            errorMessage = nil
                            if filtered.count == 6 && !isValidating {
                                validate(filtered)
                            }
                        }

                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { i in
                            let char: String = code.count > i
                                ? String(code[code.index(code.startIndex, offsetBy: i)])
                                : ""
                            let filled = code.count > i
                            let hasError = errorMessage != nil

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: "0F0F0F"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            hasError ? Color.besideSyncBad :
                                                filled ? Color.besideCoral :
                                                Color.white.opacity(0.12),
                                            lineWidth: 1.5
                                        )
                                )
                                .overlay(
                                    Text(char)
                                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                )
                                .frame(width: 44, height: 56)
                                .animation(.easeInOut(duration: 0.15), value: filled)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isInputFocused = true }
                }
                .padding(.top, 36)

                // Error / hint line
                Group {
                    if isValidating {
                        HStack(spacing: 6) {
                            SpinnerView(color: .besideTextTertiary, size: 12)
                            Text("確認中…")
                        }
                    } else if let err = errorMessage {
                        Text(err)
                            .foregroundColor(.besideSyncBad)
                    } else {
                        Text("大文字小文字は問いません · O / I は使われません")
                            .foregroundColor(.besideTextTertiary)
                    }
                }
                .font(.system(size: 12))
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .frame(height: 20)
                .padding(.top, 14)

                // Paste hint
                Button {
                    code = mockCode
                    validate(mockCode)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12))
                        Text("クリップボードから貼り付け · \(mockCode)")
                            .font(.system(size: 12.5))
                            .tracking(0.3)
                    }
                    .foregroundColor(.besideTextSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                    )
                }
                .padding(.top, 18)

                Spacer()

                Text("1文字入力ごとに haptic feedback · Auto-advances on input")
                    .font(.system(size: 11))
                    .foregroundColor(.besideTextQuaternary)
                    .tracking(0.4)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 22)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            code = ""
            errorMessage = nil
            isValidating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                isInputFocused = true
            }
        }
    }

    private func validate(_ full: String) {
        isValidating = true
        if let asyncValidate = validateCode {
            Task {
                let errMsg = await asyncValidate(full)
                isValidating = false
                if errMsg == nil {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onJoin() }
                } else {
                    errorMessage = errMsg
                }
            }
        } else {
            // モックバリデーション (Preview / デザイン確認用)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                isValidating = false
                if full == mockCode {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onJoin() }
                } else {
                    errorMessage = "コードが正しくないか、ルームが終了しています"
                }
            }
        }
    }
}
