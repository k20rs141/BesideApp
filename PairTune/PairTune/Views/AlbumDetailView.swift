import SwiftUI
import UIKit

// MARK: - AlbumDetailView (v0.4 §2.8)
//
// Apple Music の Album / EP 画面を PairTune に合わせて翻案。
// - 上 540pt に cover の色をブリードさせる
// - 中央寄せ cover hero / アルバム名 / アーティスト(tappable, primary)/ 種別 + 日付
// - CTAs: 「ふたりで再生 / ひとりで再生」(mode に応じて文言切替) + add to library
// - トラックリスト: # / title / partner heart / your heart / duration / ⋯
// - ⋯ → TrackContextMenu(同ファイルの View で overlay 表示)

struct AlbumDetailView: View {
    @State var viewModel: AlbumDetailViewModel
    /// shared モードで partner がいる時のみ「相手に送る」等を表示するために渡す。
    var partnerName: String?
    var onSelectTrack: (Track) -> Void
    /// アーティスト名タップ / TrackContextMenu「アーティストを見る」の遷移先。
    /// 呼び出し側で push する。caller が nil の時はリンク無効化。
    var onShowArtist: ((Artist) -> Void)? = nil
    /// custom sticky back button のタップで pop するためのコールバック。
    /// nil の場合は NavigationStack の dismissEnvironment を使う。
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var contextTrack: Track?
    @State private var toastMessage: String?

    var body: some View {
        ZStack {
            Color.pairtuneSurface.ignoresSafeArea()

            // ambient bleed from cover (top 540pt fades to transparent)
            ambientBleed
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    coverHero
                        .padding(.top, 52)
                    ctaRow
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 8)

                    if viewModel.isLoading && viewModel.tracks.isEmpty {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.pairtuneTextSecondary)
                            .padding(.top, 30)
                    } else if let err = viewModel.loadError, viewModel.tracks.isEmpty {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.pairtuneSyncBad)
                            .padding(.top, 24)
                    } else {
                        trackList
                            .padding(.top, 8)
                            .padding(.bottom, 30)
                        Text(footer)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "5A5566"))
                            .tracking(0.3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 30)
                    }
                }
            }
            .scrollIndicators(.hidden)

            // v0.5: sticky back button(jsx の絶対配置 36×36 + blur 背景)
            VStack {
                HStack {
                    Button {
                        if let onBack { onBack() } else { dismiss() }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                Spacer()
            }

            // Toast overlay
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    ToastView(message: msg)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .padding(.bottom, 130)
                }
                .animation(.easeOut(duration: 0.25), value: toastMessage != nil)
                .allowsHitTesting(false)
            }

            // TrackContextMenu overlay
            if let track = contextTrack {
                TrackContextMenu(
                    track: track,
                    partnerName: partnerName,
                    onClose: { contextTrack = nil },
                    onFavorite: {
                        Task { await viewModel.addFavorite(track) }
                    },
                    onSendToPartner: { viewModel.play(track) },
                    onPlayNext: { Task { await viewModel.playNext(track) } },
                    onShowArtist: (onShowArtist != nil && track.artistId != nil) ? {
                        onShowArtist?(Artist(
                            id: track.artistId!,
                            name: track.artist,
                            artworkURL: nil
                        ))
                    } : nil
                )
                .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.tracks.isEmpty { viewModel.load() }
        }
    }

    // MARK: - Ambient bleed

    private var ambientBleed: some View {
        // jsx: album のカバー画像を上 540pt に拡大・ぼかして敷き、下へフェード。
        // artwork が無いときだけ primary→surface のグラデでフォールバック。
        VStack(spacing: 0) {
            Group {
                if let url = viewModel.album.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 60)
                                .opacity(0.55)
                                .overlay(Color.pairtuneSurface.opacity(0.25))
                        default:
                            primaryFallbackGradient
                        }
                    }
                } else {
                    primaryFallbackGradient
                }
            }
            .frame(height: 540)
            .mask(
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.6), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            Spacer(minLength: 0)
        }
    }

    private var primaryFallbackGradient: some View {
        LinearGradient(
            colors: [Color.pairtunePrimary.opacity(0.55), Color.pairtuneSurface.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Cover hero

    private var coverHero: some View {
        VStack(spacing: 14) {
            GeometryReader { geo in
                let size = geo.size.width * 0.65
                let xPad = (geo.size.width - size) / 2
                Group {
                    if let url = viewModel.album.artworkURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default: placeholderArtwork
                            }
                        }
                    } else { placeholderArtwork }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.55), radius: 30, y: 14)
                .offset(x: xPad)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 32)

            VStack(spacing: 5) {
                // jsx: 22pt 700(bold)
                Text(viewModel.album.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .tracking(0.2)

                Button {
                    if let artistId = viewModel.albumArtistId {
                        onShowArtist?(Artist(
                            id: artistId,
                            name: viewModel.album.artistName,
                            artworkURL: nil
                        ))
                    }
                } label: {
                    Text(viewModel.album.artistName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.pairtunePrimary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.albumArtistId == nil || onShowArtist == nil)

                Text(metaLine)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "7A7588"))
                    .tracking(0.4)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
        }
    }

    private var placeholderArtwork: some View {
        LinearGradient(
            colors: [Color.pairtunePrimary.opacity(0.7), Color(hex: "1F1830")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var metaLine: String {
        var parts: [String] = [viewModel.kindLabel]
        if let date = viewModel.releaseDate { parts.append(formatDate(date)) }
        return parts.joined(separator: " · ")
    }

    private func formatDate(_ raw: String) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        if let d = df.date(from: raw) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "ja_JP")
            out.dateFormat = "yyyy年M月d日"
            return out.string(from: d)
        }
        return raw
    }

    // MARK: - CTA row
    //
    // jsx: primary 56pt height + 15pt 600、secondary 56×56 大きめ正方形(chat6「副ボタン拡大」)

    private var ctaRow: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.playAll()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(isSolo ? "ひとりで再生" : "ふたりで再生")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.pairtunePrimary, .pairtuneSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.pairtunePrimary.opacity(0.27), radius: 16, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.playNextAll()
                showToast("キューに追加しました")
            } label: {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "A8A8A8"))
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.tracks.isEmpty)
        }
    }

    /// haptic 付きトースト表示。playNextAll など「キューへの追加」操作の確認に使う。
    /// 1.6 秒後に自動で消える。
    private func showToast(_ msg: String) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { toastMessage = nil }
        }
    }

    private var isSolo: Bool {
        // RoomViewModel.mode は AlbumDetailViewModel に持たせていないので
        // partnerName の有無で代替判定。partner なし = solo モードと見なす。
        partnerName == nil
    }

    // MARK: - Track list

    private var trackList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { idx, track in
                Button {
                    // キューが空ならタップした曲以降を up-next に積む(Apple Music ライク)
                    viewModel.queueRemainingIfEmpty(after: track)
                    onSelectTrack(track)
                } label: {
                    AlbumTrackRow(
                        number: idx + 1,
                        track: track,
                        onMenu: { contextTrack = track }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: String {
        let total = viewModel.totalDurationSeconds
        let minutes = total / 60
        let durationStr: String
        if minutes >= 60 {
            durationStr = "\(minutes / 60) 時間 \(minutes % 60) 分"
        } else {
            durationStr = "\(minutes) 分"
        }
        return "\(viewModel.tracks.count) 曲 · \(durationStr)"
    }
}

// MARK: - Album track row

// v0.5: 行高 64pt + ♥ マーカー撤去(chat6 §1-11、screens-album-extras.jsx と一致)
//   - jsx の vertical padding 21px × 2 ≒ 64pt
//   - partnerFav / youFav の ♥ 表示は廃止(行が混雑するため。お気に入りは別動線で表現)

private struct AlbumTrackRow: View {
    let number: Int
    let track: Track
    var onMenu: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(hex: "7A7588"))
                .frame(width: 18)
                .monospacedDigit()

            Text(track.title)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(.white)
                .tracking(0.1)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(fmt(track.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(hex: "5A5566"))
                .monospacedDigit()

            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "5A5566"))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 21)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 0.5)
                .padding(.leading, 46)
        }
        .contentShape(Rectangle())
    }
}
