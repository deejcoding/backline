//
//  UserProfileTests.swift
//  backlineTests
//

import Foundation
import Testing
@testable import backline

struct UserProfileTests {

    // MARK: - Completeness Score

    @Test func emptyProfileScoresZero() {
        let profile = UserProfile(
            id: "uid1",
            username: "testuser",
            displayName: nil,
            profilePhotoURL: nil,
            roles: [],
            genres: [],
            bio: nil
        )
        #expect(profile.completenessScore == 0)
    }

    @Test func profileWithPhotoOnlyScoresOne() {
        let profile = UserProfile(
            id: "uid1",
            username: "testuser",
            displayName: nil,
            profilePhotoURL: "https://example.com/photo.jpg",
            roles: [],
            genres: [],
            bio: nil
        )
        #expect(profile.completenessScore == 1)
    }

    @Test func fullyCompleteProfileScoresSix() {
        let profile = UserProfile(
            id: "uid1",
            username: "testuser",
            displayName: "Test User",
            profilePhotoURL: "https://example.com/photo.jpg",
            roles: ["Guitarist"],
            genres: ["Rock"],
            bio: "I play guitar",
            neighborhood: "Williamsburg, Brooklyn"
        )
        #expect(profile.completenessScore == 6)
    }

    @Test func profileWithRolesAndGenresScoresTwo() {
        let profile = UserProfile(
            id: "uid1",
            username: "testuser",
            displayName: nil,
            profilePhotoURL: nil,
            roles: ["Drummer", "Vocalist"],
            genres: ["Jazz", "Blues"],
            bio: nil
        )
        #expect(profile.completenessScore == 2)
    }

    @Test func emptyStringFieldsCountAsIncomplete() {
        let profile = UserProfile(
            id: "uid1",
            username: "testuser",
            displayName: "",
            profilePhotoURL: "",
            roles: [],
            genres: [],
            bio: ""
        )
        #expect(profile.completenessScore == 0)
    }
}
