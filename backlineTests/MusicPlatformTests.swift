//
//  MusicPlatformTests.swift
//  backlineTests
//

import Foundation
import Testing
@testable import backline

struct MusicPlatformTests {

    // MARK: - Platform detection

    @Test func detectsSpotify() {
        #expect(MusicPlatform.detect(from: "https://spotify.com/track/123") == .spotify)
    }

    @Test func detectsOpenSpotify() {
        #expect(MusicPlatform.detect(from: "https://open.spotify.com/track/abc") == .spotify)
    }

    @Test func detectsAppleMusic() {
        #expect(MusicPlatform.detect(from: "https://music.apple.com/us/album/something") == .appleMusic)
    }

    @Test func detectsYouTube() {
        #expect(MusicPlatform.detect(from: "https://youtube.com/watch?v=abc123") == .youtube)
    }

    @Test func detectsShortYouTube() {
        #expect(MusicPlatform.detect(from: "https://youtu.be/abc123") == .youtube)
    }

    @Test func detectsSoundCloud() {
        #expect(MusicPlatform.detect(from: "https://soundcloud.com/artist/track") == .soundcloud)
    }

    @Test func unknownURLReturnsOther() {
        #expect(MusicPlatform.detect(from: "https://bandcamp.com/album/xyz") == .other)
        #expect(MusicPlatform.detect(from: "https://example.com") == .other)
    }

    // MARK: - Icon names

    @Test func spotifyIconName() {
        #expect(MusicPlatform.spotify.iconName == "music.note")
    }

    @Test func appleMusicIconName() {
        #expect(MusicPlatform.appleMusic.iconName == "music.note.list")
    }

    @Test func youtubeIconName() {
        #expect(MusicPlatform.youtube.iconName == "play.rectangle.fill")
    }

    @Test func soundcloudIconName() {
        #expect(MusicPlatform.soundcloud.iconName == "cloud.fill")
    }

    @Test func otherIconName() {
        #expect(MusicPlatform.other.iconName == "link")
    }
}
