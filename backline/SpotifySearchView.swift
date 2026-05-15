//
//  SpotifySearchView.swift
//  backline
//
//  Created by Khadija Aslam on 4/13/26.
//

import SwiftUI

struct SpotifySearchView: View {

    @Environment(\.dismiss) private var dismiss
    let onSelect: (SpotifyTrack) -> Void

    @State private var query = ""
    @State private var selectedType: SpotifyItemType = .track
    @State private var searchTask: Task<Void, Never>?
    private var spotify = SpotifyManager.shared

    init(onSelect: @escaping (SpotifyTrack) -> Void) {
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search \(selectedType.label.lowercased())...", text: $query)
                        .font(.system(size: 12, design: .monospaced))
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(Rectangle())
                .padding(.horizontal)
                .padding(.top, 8)

                // Type filter tabs
                HStack(spacing: 8) {
                    ForEach(SpotifyItemType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            Text(type.label)
                                .font(.system(size: 12, weight: selectedType == type ? .semibold : .regular, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(selectedType == type ? ThemeColor.green : Color(.systemGray5))
                                .foregroundStyle(selectedType == type ? .black : .primary)
                                .clipShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: selectedType) { _, _ in
                    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    searchTask?.cancel()
                    searchTask = Task {
                        await spotify.search(query: query, type: selectedType)
                    }
                }
                .onChange(of: query) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        await spotify.search(query: newValue, type: selectedType)
                    }
                }

                if spotify.isSearching {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                } else if spotify.searchResults.isEmpty && !query.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No results found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(spotify.searchResults) { track in
                                trackRow(track)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        spotify.stopPlayback()
                                        onSelect(track)
                                        dismiss()
                                    }
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Search Spotify")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        spotify.stopPlayback()
                        dismiss()
                    }
                }
            }
            .task {
                await spotify.refreshTokenIfNeeded()
            }
            .onDisappear {
                spotify.stopPlayback()
            }
        }
    }

    private func trackRow(_ track: SpotifyTrack) -> some View {
        HStack(spacing: 10) {
            // Image
            if let urlString = track.albumImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(Rectangle())
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: track.itemType == .artist ? "person.fill" : "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(subtitleText(for: track))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Preview play button (tracks only)
            if track.itemType == .track, track.previewURL != nil {
                Button {
                    spotify.playPreview(for: track)
                } label: {
                    Image(systemName: spotify.currentlyPlayingTrackID == track.id && spotify.isPlaying
                          ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeColor.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func subtitleText(for track: SpotifyTrack) -> String {
        switch track.itemType {
        case .track:
            return track.artistName
        case .artist:
            return track.artistName.isEmpty ? "Artist" : track.artistName
        case .album:
            let parts = [track.artistName, track.albumName].filter { !$0.isEmpty }
            return parts.joined(separator: " · ")
        }
    }
}
