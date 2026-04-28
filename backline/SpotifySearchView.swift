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
    @State private var searchTask: Task<Void, Never>?
    private var spotify = SpotifyManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search songs on Spotify", text: $query)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: query) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled else { return }
                        await spotify.searchTracks(query: newValue)
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
            .navigationTitle("Search Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        spotify.stopPlayback()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                spotify.stopPlayback()
            }
        }
    }

    private func trackRow(_ track: SpotifyTrack) -> some View {
        HStack(spacing: 10) {
            // Album art
            if let urlString = track.albumImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Preview play button
            if track.previewURL != nil {
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
}
