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

    var iconName: String {
        switch self {
        case .spotify:     return "music.note"
        case .appleMusic:  return "music.note.list"
        case .youtube:     return "play.rectangle.fill"
        }
    }
}

// MARK: - Music Project

struct MusicProject: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var url: String
    var platform: MusicPlatform
}
