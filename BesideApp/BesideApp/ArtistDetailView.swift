import SwiftUI

struct ArtistDetailView: View {
    @State var viewModel: ArtistDetailViewModel
    var onSelectTrack: (Track) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                if viewModel.isLoading && viewModel.topSongs.isEmpty && viewModel.albums.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.besideTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    if !viewModel.topSongs.isEmpty {
                        sectionHeader("トップソング · Top Songs")
                            .padding(.bottom, 4)
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.topSongs) { track in
                                Button {
                                    onSelectTrack(track)
                                } label: {
                                    ArtistTrackRow(track: track)
                                }
                            }
                        }
                        .padding(.bottom, 22)
                    }

                    if !viewModel.albums.isEmpty {
                        sectionHeader("アルバム · Albums")
                            .padding(.bottom, 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(viewModel.albums) { album in
                                    AlbumCard(album: album)
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                        .padding(.bottom, 28)
                    }

                    if let err = viewModel.loadError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.besideSyncBad)
                            .padding(.top, 24)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.besideSurface.ignoresSafeArea())
        .navigationTitle(viewModel.artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.besideSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if viewModel.topSongs.isEmpty && viewModel.albums.isEmpty {
                viewModel.load()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Group {
                if let url = viewModel.artist.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            placeholderArtwork
                        }
                    }
                } else {
                    placeholderArtwork
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)

            Text(viewModel.artist.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholderArtwork: some View {
        LinearGradient(
            colors: [Color.besideCoral.opacity(0.6), Color(hex: "4A1D3D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.7))
        )
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.besideTextTertiary)
                .tracking(0.6)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 22)
    }
}

// MARK: - Track row (artist detail variant)

private struct ArtistTrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = track.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            LinearGradient(stops: track.gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                } else {
                    LinearGradient(stops: track.gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(track.album)
                    .font(.system(size: 12.5))
                    .foregroundColor(.besideTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(fmt(track.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.besideTextTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Album card

private struct AlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let url = album.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.system(size: 11))
                    .foregroundColor(.besideTextSecondary)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(hex: "1F1F1F"), Color(hex: "141414")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
