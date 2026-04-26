import SwiftUI

struct SignInView: View {
    var onSignIn: () -> Void
    @State private var busy = false

    var body: some View {
        ZStack {
            Color.besideBase.ignoresSafeArea()

            // Atmospheric glow
            RadialGradient(
                colors: [Color.besideCoral.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Logo + wordmark + tagline
                VStack(spacing: 0) {
                    BesideLogoView(size: 92, color: .besideCoral, glow: true)
                        .opacity(busy ? 0.6 : 1)
                        .animation(.easeInOut(duration: 0.3), value: busy)

                    BesideWordmark(size: 42)
                        .padding(.top, 20)

                    VStack(spacing: 6) {
                        Text("通話せずに、同じ曲を、あの人と。")
                            .font(.system(size: 14))
                            .foregroundColor(.besideTextSecondary)
                            .multilineTextAlignment(.center)
                            .tracking(0.4)

                        Text("The same song, beside someone — without a call.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.besideTextTertiary)
                            .tracking(0.6)
                    }
                    .padding(.top, 14)
                    .lineSpacing(4)
                }

                Spacer()

                // Bottom section
                VStack(spacing: 18) {
                    Button {
                        guard !busy else { return }
                        busy = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
                            onSignIn()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if busy {
                                SpinnerView(color: .black, size: 17)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 17, weight: .medium))
                                Text("Sign in with Apple")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.white.opacity(0.08), radius: 16, y: 4)
                        .opacity(busy ? 0.6 : 1)
                    }
                    .disabled(busy)
                    .animation(.easeInOut(duration: 0.2), value: busy)

                    HStack(spacing: 4) {
                        Text("続行することで")
                        Text("利用規約")
                            .foregroundColor(.besideTextSecondary)
                            .underline()
                        Text("と")
                        Text("プライバシー")
                            .foregroundColor(.besideTextSecondary)
                            .underline()
                        Text("に同意")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.besideTextTertiary)
                    .tracking(0.4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
            }
        }
    }
}

#Preview {
    SignInView(onSignIn: {})
}
