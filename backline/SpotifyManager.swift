//
//  SpotifyManager.swift
//  backline
//
//  Created by Khadija Aslam on 4/13/26.
//

import Foundation
import AVFoundation

enum SpotifyItemType: String, Codable, CaseIterable {
    case track = "track"
    case artist = "artist"
    case album = "album"

    var label: String {
        switch self {
        case .track: "Songs"
        case .artist: "Artists"
        case .album: "Albums"
        }
    }
}

struct SpotifyTrack: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let artistName: String
    let albumName: String
    let albumImageURL: String?
    let previewURL: String?
    let externalURL: String
    var itemType: SpotifyItemType = .track

    enum CodingKeys: String, CodingKey {
        case id, name, artistName, albumName, albumImageURL, previewURL, externalURL, itemType
    }
}

@MainActor
@Observable
final class SpotifyManager {

    static let shared = SpotifyManager()

    var searchResults: [SpotifyTrack] = []
    var isSearching = false
    var isPlaying = false
    var currentlyPlayingTrackID: String?

    private var accessToken: String?
    private var tokenExpiry: Date?
    private var audioPlayer: AVPlayer?

    private let clientID = "4bbf6c9d330b421fa7710966ffe5208e"
    private let clientSecret = "d3504992f0ab416492cae9e4c4bbd47f"

    private init() {}

    // MARK: - Client Credentials Auth

    private func fetchAccessToken(forceRefresh: Bool = false) async throws -> String {
        if !forceRefresh, let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }

        accessToken = nil
        tokenExpiry = nil

        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let credentials = "\(clientID):\(clientSecret)"
        let encodedCredentials = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode != 200 {
            print("[Spotify] Token failed: \(httpResponse.statusCode)")
            throw URLError(.userAuthenticationRequired)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let token = json?["access_token"] as? String,
              let expiresIn = json?["expires_in"] as? Int else {
            throw URLError(.userAuthenticationRequired)
        }

        accessToken = token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(min(expiresIn - 300, 1800)))
        return token
    }

    func refreshTokenIfNeeded() async {
        do {
            _ = try await fetchAccessToken(forceRefresh: accessToken == nil)
        } catch {
            print("[Spotify] Pre-refresh failed: \(error)")
        }
    }

    // MARK: - Search

    func search(query: String, type: SpotifyItemType) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            let results = try await performSearch(query: trimmed, type: type, isRetry: false)
            searchResults = results
        } catch {
            print("[Spotify] Search failed: \(error)")
            searchResults = []
        }
    }

    private func performSearch(query: String, type: SpotifyItemType, isRetry: Bool) async throws -> [SpotifyTrack] {
        let token = try await fetchAccessToken(forceRefresh: isRetry)

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
        let urlString = "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=\(type.rawValue)"
        guard let url = URL(string: urlString) else { return [] }

        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { return [] }

        if httpResponse.statusCode == 401 && !isRetry {
            return try await performSearch(query: query, type: type, isRetry: true)
        }

        if httpResponse.statusCode != 200 {
            if !isRetry {
                return try await performSearch(query: query, type: type, isRetry: true)
            }
            return []
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        switch type {
        case .track:
            let tracks = (json?["tracks"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
            return tracks.compactMap { parseTrack($0) }
        case .artist:
            let artists = (json?["artists"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
            return artists.compactMap { parseArtist($0) }
        case .album:
            let albums = (json?["albums"] as? [String: Any])?["items"] as? [[String: Any]] ?? []
            return albums.compactMap { parseAlbum($0) }
        }
    }

    // MARK: - Parsing

    private func parseTrack(_ dict: [String: Any]) -> SpotifyTrack? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let artists = dict["artists"] as? [[String: Any]],
              let artistName = artists.first?["name"] as? String,
              let album = dict["album"] as? [String: Any],
              let albumName = album["name"] as? String,
              let externalURLs = dict["external_urls"] as? [String: String],
              let externalURL = externalURLs["spotify"]
        else { return nil }

        let images = (album["images"] as? [[String: Any]]) ?? []
        let albumImageURL = images.first?["url"] as? String
        let previewURL = dict["preview_url"] as? String

        return SpotifyTrack(
            id: id, name: name, artistName: artistName, albumName: albumName,
            albumImageURL: albumImageURL, previewURL: previewURL,
            externalURL: externalURL, itemType: .track
        )
    }

    private func parseArtist(_ dict: [String: Any]) -> SpotifyTrack? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let externalURLs = dict["external_urls"] as? [String: String],
              let externalURL = externalURLs["spotify"]
        else { return nil }

        let images = dict["images"] as? [[String: Any]] ?? []
        let imageURL = images.first?["url"] as? String
        let genres = dict["genres"] as? [String] ?? []
        let genreText = genres.prefix(2).joined(separator: ", ")

        return SpotifyTrack(
            id: id, name: name, artistName: genreText.isEmpty ? "Artist" : genreText,
            albumName: "", albumImageURL: imageURL, previewURL: nil,
            externalURL: externalURL, itemType: .artist
        )
    }

    private func parseAlbum(_ dict: [String: Any]) -> SpotifyTrack? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let artists = dict["artists"] as? [[String: Any]],
              let artistName = artists.first?["name"] as? String,
              let externalURLs = dict["external_urls"] as? [String: String],
              let externalURL = externalURLs["spotify"]
        else { return nil }

        let images = dict["images"] as? [[String: Any]] ?? []
        let imageURL = images.first?["url"] as? String
        let releaseDate = dict["release_date"] as? String ?? ""
        let year = String(releaseDate.prefix(4))

        return SpotifyTrack(
            id: id, name: name, artistName: artistName,
            albumName: year, albumImageURL: imageURL, previewURL: nil,
            externalURL: externalURL, itemType: .album
        )
    }

    // MARK: - Playback

    func playPreview(for track: SpotifyTrack) {
        guard let urlString = track.previewURL,
              let url = URL(string: urlString) else { return }

        if currentlyPlayingTrackID == track.id && isPlaying {
            stopPlayback()
            return
        }

        stopPlayback()

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        let playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.play()
        isPlaying = true
        currentlyPlayingTrackID = track.id

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.currentlyPlayingTrackID = nil
            }
        }
    }

    func stopPlayback() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingTrackID = nil
    }
}
