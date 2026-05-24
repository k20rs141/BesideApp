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
    var accent: Color = .pairtuneCoral
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

// MARK: - Sync Wave Badge (v0.5: 3-dot pulse)
//
// chat6 のレビューで「Room — 3 ドット pulse」に統一(SoloIndicator と同系の表現)。
// 旧 v0.4 の 2 本サイン波 Canvas は jsx で撤去された。
// Claude Design `screens-room.jsx::SyncWave` を SwiftUI に移植(v0.5)。

struct SyncWaveView: View {
    let state: SyncState
    /// playing 時の dot 色(state から導出する `playing` を変えたい時用、通常はデフォルトで OK)
    var primary: Color = .pairtunePrimary
    /// 互換のため secondary を受け取るが描画には使わない(旧 v0.4 の名残)
    var secondary: Color = .pairtuneSecondary

    /// 状態ごとの設定(jsx の cfgs と一致)
    private var config: (label: String, color: Color, duration: Double?) {
        switch state {
        case .idle:         return ("ホスト選曲待ち", Color(hex: "3F3F4A"), nil)
        case .loading:      return ("読み込み中",     .pairtuneSyncWarn,   1.2)
        case .playing:      return ("同期中",         primary,             1.2)
        case .paused:       return ("一時停止",       .pairtuneTextSecondary, nil)
        case .outOfSync:    return ("補正中",         .pairtuneSyncWarn,   0.7)
        case .disconnected: return ("再接続中",       .pairtuneSyncBad,    0.5)
        }
    }

    var body: some View {
        let cfg = config
        HStack(spacing: 8) {
            ThreeDotPulse(color: cfg.color, duration: cfg.duration)
                .frame(width: 30, height: 14)
            Text(cfg.label)
                .font(.system(size: 11))
                .foregroundColor(cfg.color)
                .tracking(0.3)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(cfg.color.opacity(0.08))
                .overlay(Capsule().stroke(cfg.color.opacity(0.19), lineWidth: 0.5))
        )
        .animation(.easeInOut(duration: 0.25), value: state)
    }
}

// MARK: - Solo Indicator (v0.5)
//
// Solo Room 用の 3-dot pulse。Shared の SyncWave と同型だが、color/label が違う。
// 「ひとりで聴いています」「一時停止」「読み込み中」「ホスト選曲待ち」をテキストで提示。

struct SoloIndicator: View {
    let state: SyncState

    private var label: String {
        switch state {
        case .loading: return "読み込み中"
        case .paused:  return "一時停止"
        case .playing: return "ひとりで聴いています"
        default:       return "ホスト選曲待ち"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ThreeDotPulse(
                color: .pairtunePrimary,
                duration: state == .playing ? 1.4 : nil
            )
            .frame(width: 30, height: 14)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "7A7588"))
                .tracking(0.3)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.03))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        )
    }
}

// MARK: - 3 dot pulse(SyncWave / SoloIndicator 共通)
//
// jsx: 3 つの circle (r=2.2) を 9pt 間隔で並べ、duration あり時のみ opacity を
// .35 → 1 → .35 でアニメーション(stagger 0.18s)。

private struct ThreeDotPulse: View {
    let color: Color
    /// nil なら静止(opacity 固定)、値があれば pulse アニメ
    let duration: Double?

    var body: some View {
        if let duration {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 6.8) {
                    ForEach(0..<3, id: \.self) { i in
                        let phase = ((t + Double(i) * 0.18).truncatingRemainder(dividingBy: duration)) / duration
                        // 0..1 を sin で 0..1 → 0..1 (滑らかな pulse)
                        let alpha = 0.35 + 0.65 * (1 - abs(2 * phase - 1))
                        Circle()
                            .fill(color)
                            .frame(width: 4.4, height: 4.4)
                            .opacity(alpha)
                    }
                }
            }
        } else {
            HStack(spacing: 6.8) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .frame(width: 4.4, height: 4.4)
                        .opacity(0.45)
                }
            }
        }
    }
}

// v0.5: 旧 SyncWaveCanvas (2 本サイン波 Canvas) は撤去。3-dot pulse の ThreeDotPulse に置換。

// MARK: - RemoteAvatar
//
// URL があれば AsyncImage、無ければ gradient + initials のフォールバック。
// HomeView / RoomView / QueueSheet の参加者表示で共通利用する。

struct RemoteAvatarView: View {
    /// `profiles.avatar_url` 等から渡す。nil の時はイニシャル fallback。
    let url: URL?
    /// fallback 表示用のイニシャル(2 文字目安)。
    let initials: String
    /// fallback 時の gradient ベース色。
    let color: Color
    var size: CGFloat = 40
    /// 外周ストロークの色(リング表現用、nil で出さない)。
    var strokeColor: Color? = Color(hex: "1A1A1A")
    var strokeWidth: CGFloat = 1.5
    /// オフライン等で dim 表示にする。
    var dim: Bool = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            if let strokeColor {
                Circle().stroke(strokeColor, lineWidth: strokeWidth)
            }
        }
        .opacity(dim ? 0.55 : 1.0)
        .saturation(dim ? 0.5 : 1.0)
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [color, color.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(.pairtuneBase)
        }
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
                        .foregroundColor(.pairtuneBase)
                )
                .overlay(Circle().stroke(Color(hex: "1A1A1A"), lineWidth: 1.5))

            if showCrown && participant.role == .host {
                Circle()
                    .fill(Color.pairtuneCream)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.pairtuneBase)
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
    var color: Color = .pairtuneTextSecondary
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
            .foregroundColor(.pairtuneBase)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.pairtuneCream.opacity(0.96))
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
            VinylDiscBody(
                diameter: discDiam,
                labelStops: track?.gradientStops,
                artworkURL: track?.artworkURL
            )
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
    var artworkURL: URL? = nil

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
            // Base: artwork image when available, otherwise the gradient label
            if let url = artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle().fill(labelFillStyle)
                    }
                }
                .clipShape(Circle())
            } else {
                Circle().fill(labelFillStyle)
            }

            // iridescent ring (subtle overlay even with artwork)
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
                .opacity(artworkURL == nil ? 0.7 : 0.25)

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
            colors: [Color.pairtuneCoral.opacity(0.7), Color(hex: "4A1D3D")],
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

// MARK: - Tonearm overlay (v0.5)
//
// jsx 仕様 (docs/design_v3_source/screens-room.jsx):
//   - container 内 pivot 位置: left 93% / top 10%
//   - pivot 形状: width 16% / aspectRatio 0.78:1(縦長楕円)+ 内側に小さなキャプセル
//   - arm: width 68% / height 6px、transform-origin '0 50%' (pivot 中央左)
//   - arm 角度: paused = 90deg(真下)/ playing = 95deg(わずかに内側)
//   - transition: 0.8s spring
//   - cartridge (headshell): 28×22, translate(-58%, -20%) で arm 端点から微オフセット
//   - needle: 2×8 を cartridge 下部から突出
//   - counterweight: jsx には無い(撤去)

private struct TonearmView: View {
    let size: CGFloat
    let playing: Bool

    // jsx 通りのレイアウト比率
    private var pivotCenterX: CGFloat { size * 0.93 }
    private var pivotCenterY: CGFloat { size * 0.10 }
    private var pivotW: CGFloat { size * 0.16 }
    private var pivotH: CGFloat { pivotW / 0.78 }   // aspectRatio 0.78:1
    private var armLen: CGFloat { size * 0.68 }
    private var armHeight: CGFloat { 6 }
    private var armAngle: Double { playing ? 95 : 90 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // arm + cartridge(回転は arm の leading-center 周り)
            armAssembly
                .frame(width: armLen, height: armHeight, alignment: .leading)
                .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: 0, y: 0.5))
                .offset(x: pivotCenterX, y: pivotCenterY - armHeight / 2)
                .animation(.spring(response: 0.8, dampingFraction: 0.65), value: playing)

            // pivot(arm の上に重ねる)
            pivot
                .frame(width: pivotW, height: pivotH)
                .offset(x: pivotCenterX - pivotW / 2, y: pivotCenterY - pivotH / 2)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // jsx: shaft(銀色グラデ)+ cartridge を arm 端点に配置
    private var armAssembly: some View {
        ZStack(alignment: .leading) {
            // shaft
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: "E2E2E8"), Color(hex: "B0B0B8"), Color(hex: "6A6A72")],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    // 上端のハイライト
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.4), .clear],
                            startPoint: .top, endPoint: .center
                        ))
                )
                .frame(width: armLen, height: armHeight)
                .shadow(color: .black.opacity(0.55), radius: 2.5, y: 1)

            // cartridge / headshell at far end
            // jsx: translate(-58%, -20%) で arm 端点を基準にオフセット
            cartridge
                .frame(width: 28, height: 22)
                .offset(x: armLen - 28 * 0.58, y: -22 * 0.20)
        }
    }

    private var cartridge: some View {
        ZStack {
            cartridgeBody
            cartridgeNeedle
        }
    }

    private var cartridgeShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 4,
                bottomLeading: 8,
                bottomTrailing: 8,
                topTrailing: 4
            ),
            style: .continuous
        )
    }

    private var cartridgeBody: some View {
        cartridgeShape
            .fill(LinearGradient(
                colors: [Color(hex: "202028"), Color(hex: "0A0A10")],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(
                cartridgeShape.stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
    }

    // needle(下から 88% 位置に出る 2×8 の銀棒)
    private var cartridgeNeedle: some View {
        let needleH: CGFloat = 8
        let yOffset: CGFloat = 22 * 0.88 - 11 + needleH / 2
        return Rectangle()
            .fill(LinearGradient(
                colors: [Color(hex: "C8C8D0"), Color(hex: "4A4A52")],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: 2, height: needleH)
            .offset(y: yOffset)
    }

    // jsx: 縦長楕円のピボット台 + 内側に小さなキャプセル top
    private var pivot: some View {
        ZStack {
            // 楕円ベース(縦長)
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "4A4A52"),
                            Color(hex: "1F1F25"),
                            Color(hex: "0E0E12")
                        ]),
                        center: UnitPoint(x: 0.38, y: 0.28),
                        startRadius: 0, endRadius: pivotW * 0.6
                    )
                )
                .overlay(Ellipse().stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.7), radius: 6, y: 4)

            // 中央の小さなキャプセル(内側)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "2A2A32"), Color(hex: "0A0A10")],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: pivotW * 0.46, height: pivotH * 0.36)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1.5)
                .offset(y: pivotH * 0.04)   // jsx: top 54%(中央より少し下)
        }
    }
}
