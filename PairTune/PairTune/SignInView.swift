import SwiftUI

struct SignInView: View {
    /// 進行中フラグ(AuthViewModel.isLoading から流す)。失敗時は呼び出し側で false に戻る。
    var isProcessing: Bool = false
    var onSignIn: () -> Void
    @State private var logoAnimKey: Int = 0

    var body: some View {
        ZStack {
            Color.pairtuneBase.ignoresSafeArea()

            // 上部 glow(jsx: top -20%, primary2a, blur 50)+ 下部 glow(jsx: secondary1e)
            Color.clear
                .overlay(alignment: .top) {
                    Circle()
                        .fill(Color.pairtunePrimary.opacity(0.16))
                        .frame(width: 500, height: 500)
                        .blur(radius: 50)
                        .offset(y: -150)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.pairtuneSecondary.opacity(0.12))
                        .frame(width: 320, height: 320)
                        .blur(radius: 45)
                        .offset(x: 60, y: 60)
                }
                .clipped()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // jsx: ロゴ 200×72 / wordmark 38pt / tagline 15pt #A8A8A8(英語サブなし)
                VStack(spacing: 0) {
                    PairTuneLogoView(size: 200, glow: true)
                        .opacity(isProcessing ? 0.6 : 1)
                        .animation(.easeInOut(duration: 0.3), value: isProcessing)

                    PairTuneWordmark(size: 38)
                        .padding(.top, 20)

                    Text("音楽を、いちばん近い人と。")
                        .font(.system(size: 15))
                        .foregroundColor(.pairtuneTextSecondary)
                        .multilineTextAlignment(.center)
                        .tracking(0.3)
                        .lineSpacing(4)
                        .padding(.top, 22)
                }

                Spacer()

                // Bottom: Sign in with Apple + 続行同意
                VStack(spacing: 16) {
                    Button {
                        guard !isProcessing else { return }
                        onSignIn()
                    } label: {
                        HStack(spacing: 8) {
                            if isProcessing {
                                SpinnerView(color: .black, size: 18)
                                Text("サインイン中…")
                                    .font(.system(size: 16, weight: .semibold))
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18, weight: .medium))
                                Text("Sign in with Apple")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(14)
                        .opacity(isProcessing ? 0.6 : 1)
                    }
                    .disabled(isProcessing)
                    .animation(.easeInOut(duration: 0.2), value: isProcessing)

                    // 続行することで 利用規約 と プライバシー に同意
                    HStack(spacing: 4) {
                        Text("続行することで")
                        Text("利用規約")
                            .foregroundColor(Color(hex: "C9C2DD"))
                            .underline()
                        Text("と")
                        Text("プライバシー")
                            .foregroundColor(Color(hex: "C9C2DD"))
                            .underline()
                        Text("に同意")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "7A7A7A"))
                    .tracking(0.4)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 56)
            }
            .frame(maxWidth: .infinity)
        }
        .clipped()
    }
}

#Preview {
    SignInView(onSignIn: {})
}
