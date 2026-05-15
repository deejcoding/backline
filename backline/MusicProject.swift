//
//  MusicProject.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import Foundation

// MARK: - Music Platform

enum MusicPlatform: String, CaseIterable, Codable {
    case spotify = "Spotify"
    case appleMusic = "Apple Music"
    case youtube = "YouTube"
    case soundcloud = "SoundCloud"
    case other = "Link"

    var iconName: String {
        switch self {
        case .spotify:     return "music.note"
        case .appleMusic:  return "music.note.list"
        case .youtube:     return "play.rectangle.fill"
        case .soundcloud:  return "cloud.fill"
        case .other:       return "link"
        }
    }

    /// Attempt to detect the platform from a URL string.
    static func detect(from url: String) -> MusicPlatform {
        let lower = url.lowercased()
        if lower.contains("spotify.com") || lower.contains("open.spotify") { return .spotify }
        if lower.contains("music.apple.com") { return .appleMusic }
        if lower.contains("youtube.com") || lower.contains("youtu.be") { return .youtube }
        if lower.contains("soundcloud.com") { return .soundcloud }
        return .other
    }
}

// MARK: - Music Project

struct MusicProject: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var url: String
    var platform: MusicPlatform
    var thumbnailURL: String?
}
