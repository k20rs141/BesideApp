import SwiftUI

// MARK: - PairTune Logo (two overlapping circles — shared space)

struct PairTuneLogoView: View {
    var size: CGFloat = 48
    var color: Color = .pairtuneCoral
    var glow: Bool = false

    var body: some View {
        let circle: CGFloat = size * 0.60
        let shift: CGFloat  = size * 0.20

        ZStack {
            if glow {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: circle * 1.5, height: circle * 1.5)
                    .blur(radius: 18)
                    .offset(x: -shift * 0.6)
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: circle * 1.5, height: circle * 1.5)
                    .blur(radius: 18)
                    .offset(x:  shift * 0.6)
            }

            Circle()
                .stroke(color, lineWidth: 2.4 * (size / 48))
                .frame(width: circle, height: circle)
                .offset(x: -shift)
            Circle()
                .stroke(color, lineWidth: 2.4 * (size / 48))
                .frame(width: circle, height: circle)
                .offset(x:  shift)
        }
        .frame(width: circle + shift * 2, height: circle)
    }
}

// MARK: - Wordmark

struct PairTuneWordmark: View {
    var size: CGFloat = 22
    var color: Color = .white
    var subdued: Bool = false

    var body: some View {
        Text("pairtune")
            .font(.system(size: size, weight: .light, design: .default))
            .tracking(size * 0.04)
            .foregroundColor(color.opacity(subdued ? 0.85 : 1))
    }
}

// MARK: - Lockup (logo + wordmark)

struct PairTuneLockup: View {
    var size: CGFloat = 28
    var color: Color = .white
    var accent: Color = .pairtuneCoral

    var body: some View {
        HStack(spacing: size * 0.5) {
            PairTuneLogoView(size: size * 1.6, color: accent)
            PairTuneWordmark(size: size, color: color)
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        PairTuneLogoView(size: 92, color: .pairtuneCoral, glow: true)
        PairTuneWordmark(size: 36)
        PairTuneLockup(size: 28)
    }
    .padding(40)
    .background(Color.pairtuneBase)
}
