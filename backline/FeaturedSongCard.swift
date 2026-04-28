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

    var body: some View {
        HStack(spacing: 10) {
            // Album art
            if let urlString = song.albumImageURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Play preview button
            if song.previewURL != nil {
                Button {
                    spotify.playPreview(for: song)
                } label: {
                    Image(systemName: spotify.currentlyPlayingTrackID == song.id && spotify.isPlaying
                          ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(ThemeColor.green)
                }
                .buttonStyle(.plain)
            }

            // Open in Spotify
            if let url = URL(string: song.externalURL) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}
