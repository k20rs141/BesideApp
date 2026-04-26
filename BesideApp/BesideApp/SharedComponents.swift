import SwiftUI

// MARK: - Spinner

struct SpinnerView: View {
    var color: Color = .white
    var size: CGFloat = 18
    @State private var rotating = false

    var body: some View {
        Circle()
            .trim(from: 0.15, to: 0.95)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: rotating)
            .onAppear { rotating = true }
    }
}

// MARK: - Sync Badge

struct SyncBadgeView: View {
    let state: SyncState
    var accent: Color = .besideCoral
    @State private var pulsing = false

    var body: some View {
        let c = state.color
        HStack(spacing: 7) {
            Circle()
                .fill(c)
                .frame(width: 6, height: 6)
                .shadow(color: c.opacity(0.5), radius: 4)
                .scaleEffect(pulsing ? 1.5 : 1.0)
                .opacity(pulsing ? 0.55 : 1.0)
                .animation(
                    state.pulses
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .default,
                    value: pulsing
                )

            Text(state.labelJa)
                .font(.system(size: 11))
                .foregroundColor(c)
            Text("· \(state.labelEn)")
                .font(.system(size: 10))
                .foregroundColor(c.opacity(0.55))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(c.opacity(0.08))
                .overlay(Capsule().stroke(c.opacity(0.22), lineWidth: 0.5))
        )
        .onAppear { pulsing = state.pulses }
        .onChange(of: state) { _, new in pulsing = new.pulses }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let participant: Participant
    var size: CGFloat = 36
    var showCrown: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [participant.color, participant.color.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(participant.initials)
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundColor(.besideBase)
                )
                .overlay(Circle().stroke(Color(hex: "1A1A1A"), lineWidth: 1.5))

            if showCrown && participant.role == .host {
                Circle()
                    .fill(Color.besideCream)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.besideBase)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

// MARK: - Frosted glass button style

struct FrostedCircleButton: View {
    let icon: String
    var size: CGFloat = 38
    var color: Color = .besideTextSecondary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .regular))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                )
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.besideBase)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.besideCream.opacity(0.96))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
            )
    }
}

// MARK: - Artwork card

struct ArtworkCardView: View {
    let track: Track?
    let state: SyncState

    private var dim: CGFloat {
        state == .paused || state == .idle ? 0.5 : 1.0
    }

    private var scale: CGFloat {
        state == .paused ? 0.96 : 1.0
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                track.map {
                    LinearGradient(stops: $0.gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing)
                } ?? LinearGradient(colors: [Color(hex: "1C1C1C"), Color(hex: "0A0A0A")], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .overlay(
                Group {
                    if state == .loading {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        SpinnerView(size: 28)
                    }
                }
            )
            .opacity(dim)
            .scaleEffect(scale)
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .animation(.easeInOut(duration: 0.35), value: state)
    }
}
