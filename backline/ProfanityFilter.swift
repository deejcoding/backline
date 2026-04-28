//
//  ProfanityFilter.swift
//  backline
//
//  Created by Khadija Aslam on 4/13/26.
//

import Foundation

enum ProfanityFilter {

    // Common slurs and profanity — checked as substrings within the username
    private static let blockedWords: Set<String> = [
        "fuck", "shit", "ass", "bitch", "dick", "cock", "cunt",
        "nigger", "nigga", "faggot", "fag", "retard", "slut",
        "whore", "pussy", "penis", "vagina", "rape", "molest",
        "pedo", "nazi", "hitler", "kike", "spic", "chink",
        "wetback", "tranny", "dyke", "twat", "wank", "jizz",
        "cum", "porn", "anal", "anus", "dildo", "hentai",
        "boob", "tits", "nudes", "onlyfans"
    ]

    // Exact banned usernames
    private static let blockedUsernames: Set<String> = [
        "admin", "administrator", "backline", "support", "help",
        "moderator", "mod", "staff", "official", "system"
    ]

    /// Returns true if the username contains profanity or is a reserved name.
    static func containsProfanity(_ username: String) -> Bool {
        let lower = username.lowercased()

        if blockedUsernames.contains(lower) {
            return true
        }

        // Check if any blocked word appears as a substring
        // Also check with common letter substitutions
        let normalized = lower
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "8", with: "b")
            .replacingOccurrences(of: "@", with: "a")
            .replacingOccurrences(of: "$", with: "s")

        for word in blockedWords {
            if lower.contains(word) || normalized.contains(word) {
                return true
            }
        }

        return false
    }
}
