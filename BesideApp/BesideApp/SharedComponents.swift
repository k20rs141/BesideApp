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

// MARK: - Artwork (vinyl)

struct ArtworkCardView: View {
    let track: Track?
    let state: SyncState

    private var playing: Bool { state == .playing }
    private var dim: Double { (state == .paused || state == .idle) ? 0.5 : 1.0 }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                vinylDisc(size: size)
                TonearmView(size: size, playing: playing)
                if state == .loading {
                    SpinnerView(size: 28)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(dim)
        .saturation(state == .idle ? 0.4 : 1.0)
        .brightness(state == .idle ? -0.15 : 0)
        .animation(.easeInOut(duration: 0.4), value: state)
    }

    private func vinylDisc(size: CGFloat) -> some View {
        let discDiam = size * 0.92
        return TimelineView(.animation(paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = t.truncatingRemainder(dividingBy: 14.0) / 14.0 * 360.0
            VinylDiscBody(diameter: discDiam, labelStops: track?.gradientStops)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: discDiam, height: discDiam)
        .shadow(color: .black.opacity(0.75), radius: 30, y: 14)
    }
}

// MARK: - Vinyl disc body

private struct VinylDiscBody: View {
    let diameter: CGFloat
    let labelStops: [Gradient.Stop]?

    var body: some View {
        ZStack {
            // base disc
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "2A2018"), Color(hex: "0A0806"), Color(hex: "050402")]),
                        center: .center, startRadius: 0, endRadius: diameter * 0.5
                    )
                )

            // top-left gloss
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0)]),
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0, endRadius: diameter * 0.25
                    )
                )

            // bottom-right subtle highlight
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0)]),
                        center: UnitPoint(x: 0.65, y: 0.75),
                        startRadius: 0, endRadius: diameter * 0.30
                    )
                )

            // groove rings (14 thin concentric)
            ForEach(0..<14, id: \.self) { i in
                let r = 0.30 + Double(i) * 0.045
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    .frame(width: diameter * r, height: diameter * r)
            }

            // splatter / smear streaks
            AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "F5E8D0").opacity(0.0),  location: 0.000),
                    .init(color: Color(hex: "F5E8D0").opacity(0.15), location: 0.033),
                    .init(color: Color(hex: "F5E8D0").opacity(0.0),  location: 0.078),
                    .init(color: Color(hex: "FFB48C").opacity(0.18), location: 0.222),
                    .init(color: Color(hex: "FFB48C").opacity(0.0),  location: 0.278),
                    .init(color: Color(hex: "F5E8D0").opacity(0.12), location: 0.444),
                    .init(color: Color(hex: "F5E8D0").opacity(0.0),  location: 0.528),
                    .init(color: Color(hex: "FFB48C").opacity(0.10), location: 0.667),
                    .init(color: Color(hex: "F5E8D0").opacity(0.13), location: 0.889),
                    .init(color: Color(hex: "F5E8D0").opacity(0.0),  location: 1.000),
                ]),
                center: .center
            )
            .blendMode(.screen)
            .mask(DonutShape(innerRatio: 0.27).fill(style: FillStyle(eoFill: true)))

            // diagonal sheen (fixed in disc local coords)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.08), location: 0),
                            .init(color: Color.clear,                location: 0.35),
                            .init(color: Color.clear,                location: 0.70),
                            .init(color: Color.white.opacity(0.04), location: 1.0),
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // center label
            label
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }

    private var label: some View {
        let labelDiam = diameter * 0.44
        return ZStack {
            Circle()
                .fill(labelFillStyle)

            // iridescent ring
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FFC8DC").opacity(0.30),
                            Color(hex: "B4C8FF").opacity(0.20),
                            Color(hex: "FFDCB4").opacity(0.30),
                            Color(hex: "C8B4FF").opacity(0.25),
                            Color(hex: "FFC8DC").opacity(0.30),
                        ]),
                        center: .center
                    )
                )
                .blendMode(.overlay)
                .opacity(0.7)

            // soft inner shadow approximation
            Circle()
                .stroke(Color.black.opacity(0.5), lineWidth: 6)
                .blur(radius: 4)
                .mask(Circle())

            // spindle hole
            Circle()
                .fill(Color(hex: "050505"))
                .frame(width: labelDiam * 0.14, height: labelDiam * 0.14)
                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
        }
        .frame(width: labelDiam, height: labelDiam)
        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private var labelFillStyle: AnyShapeStyle {
        if let stops = labelStops {
            return AnyShapeStyle(LinearGradient(stops: stops, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(LinearGradient(
            colors: [Color.besideCoral.opacity(0.7), Color(hex: "4A1D3D")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ))
    }
}

// Donut mask shape used for the splatter overlay (clears center spindle area)
private struct DonutShape: Shape {
    var innerRatio: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        let inset = rect.width * (1 - innerRatio) / 2
        path.addEllipse(in: rect.insetBy(dx: inset, dy: inset))
        return path
    }
}

// MARK: - Tonearm overlay

private struct TonearmView: View {
    let size: CGFloat
    let playing: Bool

    private var pivotX: CGFloat { size * 0.83 }
    private var pivotY: CGFloat { size * 0.12 }
    private var pivotDiam: CGFloat { size * 0.11 }
    private var armLen: CGFloat { size * 0.50 }
    private var armAngle: Double { playing ? 160 : 140 }
    private var counterDim: CGFloat { size * 0.07 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Arm assembly (shaft + headshell + needle), rotates around its leading-mid
            armAssembly
                .frame(width: armLen, height: 4, alignment: .leading)
                .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: 0, y: 0.5))
                .offset(x: pivotX, y: pivotY - 2)
                .animation(.spring(response: 0.55, dampingFraction: 0.65), value: playing)

            // Counterweight
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "2A2A2A"), Color(hex: "0A0A0A")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: counterDim, height: counterDim)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                .rotationEffect(.degrees(-30))
                .offset(x: size * 0.92 - counterDim / 2, y: size * 0.05 - counterDim / 2)

            // Pivot (drawn last, on top of arm base)
            pivot
                .frame(width: pivotDiam, height: pivotDiam)
                .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
                .offset(x: pivotX - pivotDiam / 2, y: pivotY - pivotDiam / 2)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private var armAssembly: some View {
        ZStack(alignment: .leading) {
            // shaft
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: "D0D0D0"), Color(hex: "909090"), Color(hex: "555555")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: armLen, height: 4)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

            // headshell at far end
            headshell
                .frame(width: 26, height: 18)
                .offset(x: armLen - 13)
        }
    }

    private var headshell: some View {
        ZStack {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 3, bottomLeading: 7, bottomTrailing: 7, topTrailing: 3),
                style: .continuous
            )
            .fill(LinearGradient(
                colors: [Color(hex: "1A1A1A"), Color(hex: "0A0A0A")],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 3, bottomLeading: 7, bottomTrailing: 7, topTrailing: 3),
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.7), radius: 4, y: 2)

            // Needle protruding past bottom edge
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(hex: "AAAAAA"), Color(hex: "2A2A2A")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 2, height: 7)
                .offset(y: 9 + 2)  // headshell half-height (9) + a bit
        }
    }

    private var pivot: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "4A4A4A"), Color(hex: "1A1A1A"), Color(hex: "0A0A0A")]),
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0, endRadius: pivotDiam * 0.5
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color(hex: "2A2A2A"), Color(hex: "0A0A0A")]),
                        center: .center, startRadius: 0, endRadius: pivotDiam * 0.22
                    )
                )
                .frame(width: pivotDiam * 0.44, height: pivotDiam * 0.44)
        }
    }
}
