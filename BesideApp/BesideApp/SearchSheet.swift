import SwiftUI

struct SearchSheet: View {
    @Binding var isPresented: Bool
    var onSelect: (Track) -> Void

    @State private var query: String = ""
    @State private var results: [Track] = catalogTracks
    @State private var isSearching: Bool = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Color.besideSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 18)

                // Search bar + cancel
                HStack(spacing: 10) {
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(.besideTextTertiary)
                            .padding(.leading, 12)

                        TextField("曲名・アーティスト  ·  Songs, artists", text: $query)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .tint(.besideCoral)
                            .focused($searchFocused)
                            .autocorrectionDisabled()
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .onChange(of: query) { runSearch() }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "1F1F1F"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                    .frame(height: 40)

                    Button {
                        isPresented = false
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.besideCoral)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                // Section header (when not searching)
                if query.isEmpty {
                    HStack {
                        Text("最近聴いた曲 · Recently played")
                            .font(.system(size: 11))
                            .foregroundColor(.besideTextTertiary)
                            .tracking(0.6)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
                }

                // Results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isSearching {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonRow()
                            }
                        } else if results.isEmpty {
                            VStack(spacing: 6) {
                                Text("該当する曲がありません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.besideTextSecondary)
                                Text("No results")
                                    .font(.system(size: 11))
                                    .foregroundColor(.besideTextTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            ForEach(results) { track in
                                Button {
                                    isPresented = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onSelect(track)
                                    }
                                } label: {
                                    TrackRow(track: track)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            query = ""
            results = catalogTracks
            isSearching = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                searchFocused = true
            }
        }
    }

    private func runSearch() {
        guard !query.isEmpty else {
            isSearching = false
            results = catalogTracks
            return
        }
        isSearching = true
        let q = query.lowercased()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            results = catalogTracks.filter {
                $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
            }
            isSearching = false
        }
    }
}

// MARK: - Track row

private struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(stops: track.gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(track.artist) · \(track.album)")
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

// MARK: - Skeleton row

private struct SkeletonRow: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: "1F1F1F"))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "1F1F1F"))
                    .frame(width: 140, height: 13)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "1A1A1A"))
                    .frame(width: 90, height: 11)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .opacity(shimmer ? 0.4 : 0.9)
        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}
