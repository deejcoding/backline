//
//  ProfanityFilterTests.swift
//  backlineTests
//

import Foundation
import Testing
@testable import backline

// MARK: - ProfanityFilter Tests

struct ProfanityFilterTests {

    // MARK: - Obvious profanity

    @Test func detectsObviousProfanity() {
        #expect(ProfanityFilter.containsProfanity("fuck"))
        #expect(ProfanityFilter.containsProfanity("shit"))
    }

    @Test func detectsProfanityInSentence() {
        #expect(ProfanityFilter.containsProfanity("you are shit"))
        #expect(ProfanityFilter.containsProfanity("what the fuck"))
    }

    @Test func handlesMixedCase() {
        #expect(ProfanityFilter.containsProfanity("FUCK"))
        #expect(ProfanityFilter.containsProfanity("Shit"))
        #expect(ProfanityFilter.containsProfanity("sHiT"))
    }

    // MARK: - False positives (should NOT flag)

    @Test func doesNotFlagWordsContainingBlockedSubstrings() {
        #expect(!ProfanityFilter.containsProfanity("classical"))
        #expect(!ProfanityFilter.containsProfanity("assistant"))
        #expect(!ProfanityFilter.containsProfanity("Scunthorpe"))
        #expect(!ProfanityFilter.containsProfanity("cockatoo"))
        #expect(!ProfanityFilter.containsProfanity("dickens"))
    }

    @Test func doesNotFlagNormalUsernames() {
        #expect(!ProfanityFilter.containsProfanity("jazzdrummer"))
        #expect(!ProfanityFilter.containsProfanity("guitarist99"))
        #expect(!ProfanityFilter.containsProfanity("bassist"))
        #expect(!ProfanityFilter.containsProfanity("drummerboy"))
    }

    // MARK: - Leetspeak / number substitutions

    @Test func detectsNumberSubstitutions() {
        // 4 → a, so "4ss" → "ass"
        #expect(ProfanityFilter.containsProfanity("4ss"))
        // 1 → i, so "sh1t" → "shit"
        #expect(ProfanityFilter.containsProfanity("sh1t"))
    }

    @Test func detectsSymbolSubstitutions() {
        // @ → a, so "@ss" → "ass"
        #expect(ProfanityFilter.containsProfanity("@ss"))
        // $ → s, so "$hit" → "shit"
        #expect(ProfanityFilter.containsProfanity("$hit"))
    }

    // MARK: - Reserved usernames

    @Test func flagsReservedUsernames() {
        #expect(ProfanityFilter.containsProfanity("admin"))
        #expect(ProfanityFilter.containsProfanity("backline"))
        #expect(ProfanityFilter.containsProfanity("moderator"))
        #expect(ProfanityFilter.containsProfanity("support"))
    }

    @Test func flagsReservedUsernamesCaseInsensitive() {
        #expect(ProfanityFilter.containsProfanity("ADMIN"))
        #expect(ProfanityFilter.containsProfanity("Admin"))
        #expect(ProfanityFilter.containsProfanity("BACKLINE"))
    }

    // MARK: - Edge cases

    @Test func emptyStringReturnsFalse() {
        #expect(!ProfanityFilter.containsProfanity(""))
    }

    @Test func singleCharReturnsFalse() {
        #expect(!ProfanityFilter.containsProfanity("a"))
        #expect(!ProfanityFilter.containsProfanity("x"))
    }
}

// MARK: - ContactInfoFilter Tests

struct ContactInfoFilterTests {

    // MARK: - Email detection

    @Test func detectsStandardEmail() {
        #expect(ContactInfoFilter.containsContactInfo("user@example.com"))
    }

    @Test func detectsEmailInSentence() {
        #expect(ContactInfoFilter.containsContactInfo("email me at user@example.com for details"))
    }

    @Test func detectsEmailWithSubdomain() {
        #expect(ContactInfoFilter.containsContactInfo("user@mail.example.co.uk"))
    }

    // MARK: - Phone detection

    @Test func detectsStandardPhoneNumber() {
        #expect(ContactInfoFilter.containsContactInfo("555-123-4567"))
    }

    @Test func detectsPhoneWithParentheses() {
        #expect(ContactInfoFilter.containsContactInfo("(555) 123-4567"))
    }

    @Test func detectsPhoneWithoutFormatting() {
        #expect(ContactInfoFilter.containsContactInfo("5551234567"))
    }

    @Test func detectsPhoneWithCountryCode() {
        #expect(ContactInfoFilter.containsContactInfo("+1 555 123 4567"))
    }

    // MARK: - False positives (should NOT flag)

    @Test func doesNotFlagNormalText() {
        #expect(!ContactInfoFilter.containsContactInfo("I play 5 gigs a week"))
    }

    @Test func doesNotFlagShortNumbers() {
        #expect(!ContactInfoFilter.containsContactInfo("call me at 5pm"))
    }

    @Test func emptyStringReturnsFalse() {
        #expect(!ContactInfoFilter.containsContactInfo(""))
    }
}
