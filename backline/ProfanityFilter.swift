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
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let lowerRange = NSRange(lower.startIndex..., in: lower)
                let normRange = NSRange(normalized.startIndex..., in: normalized)
                if regex.firstMatch(in: lower, range: lowerRange) != nil
                    || regex.firstMatch(in: normalized, range: normRange) != nil {
                    return true
                }
            }
        }

        return false
    }
}

// MARK: - Contact Info Filter

enum ContactInfoFilter {

    // US phone number pattern: matches formats like 555-123-4567, (555) 123-4567, 5551234567, +1 555 123 4567
    private static let phonePattern = #"\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)?\d{3}[-.\s]?\d{4}\b"#

    // Standard email pattern
    private static let emailPattern = #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#

    /// Returns true if the text contains a phone number or email address.
    static func containsContactInfo(_ text: String) -> Bool {
        let phoneRegex = try? NSRegularExpression(pattern: phonePattern)
        let emailRegex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive)
        let range = NSRange(text.startIndex..., in: text)

        if let phoneRegex, phoneRegex.firstMatch(in: text, range: range) != nil {
            return true
        }
        if let emailRegex, emailRegex.firstMatch(in: text, range: range) != nil {
            return true
        }
        return false
    }
}
