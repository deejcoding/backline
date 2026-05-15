//
//  FeaturedSongCard.swift
//  backline
//
//  Created by Khadija Aslam on 4/13/26.
//

import SwiftUI

struct FeaturedSongCard: View {

    let song: SpotifyTrack
    private var spotify: SpotifyManager { SpotifyManager.shared }

    private var subtitle: String {
        switch song.itemType {
        case .track:
            return song.artistName
        case .artist:
            return song.artistName.isEmpty ? "Artist" : song.artistName
        case .album:
            let parts = [song.artistName, song.albumName].filter { !$0.isEmpty }
            return parts.joined(separator: " · ")
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Square album art
            if let urlString = song.albumImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 48, height: 48)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            // Play preview button (tracks only)
            if song.itemType == .track, song.previewURL != nil {
                Button {
                    spotify.playPreview(for: song)
                } label: {
                    Image(systemName: spotify.currentlyPlayingTrackID == song.id && spotify.isPlaying
                          ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColor.green)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Rectangle()
                                .stroke(ThemeColor.green.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spotify.currentlyPlayingTrackID == song.id && spotify.isPlaying
                    ? "Pause \(song.name)" : "Play \(song.name) preview")
            }

            // Open in Spotify
            if let url = URL(string: song.externalURL) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .accessibilityLabel("Open \(song.name) in Spotify")
            }
        }
        .padding(10)
        .overlay(
            Rectangle()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}
