//
//  RateLimiterTests.swift
//  backlineTests
//

import Foundation
import Testing
@testable import backline

@Suite(.serialized)
struct RateLimiterTests {

    // Reset state before each test
    private func freshLimiter() {
        RateLimiter.shared.reset()
    }

    @Test func allowsFirstAction() {
        freshLimiter()
        #expect(RateLimiter.shared.allow(key: "test_first", maxAttempts: 3, window: 60))
    }

    @Test func allowsUpToMaxAttempts() {
        freshLimiter()
        let key = "test_max"
        #expect(RateLimiter.shared.allow(key: key, maxAttempts: 3, window: 60))
        #expect(RateLimiter.shared.allow(key: key, maxAttempts: 3, window: 60))
        #expect(RateLimiter.shared.allow(key: key, maxAttempts: 3, window: 60))
    }

    @Test func blocksWhenLimitExceeded() {
        freshLimiter()
        let key = "test_block"
        _ = RateLimiter.shared.allow(key: key, maxAttempts: 2, window: 60)
        _ = RateLimiter.shared.allow(key: key, maxAttempts: 2, window: 60)
        #expect(!RateLimiter.shared.allow(key: key, maxAttempts: 2, window: 60))
    }

    @Test func differentKeysAreIndependent() {
        freshLimiter()
        _ = RateLimiter.shared.allow(key: "keyA", maxAttempts: 1, window: 60)
        // keyA is now exhausted
        #expect(!RateLimiter.shared.allow(key: "keyA", maxAttempts: 1, window: 60))
        // keyB should still be allowed
        #expect(RateLimiter.shared.allow(key: "keyB", maxAttempts: 1, window: 60))
    }

    @Test func cooldownReturnsZeroWhenUnderLimit() {
        freshLimiter()
        let cd = RateLimiter.shared.cooldown(key: "test_cd_ok", maxAttempts: 5, window: 60)
        #expect(cd == 0)
    }

    @Test func cooldownReturnsPositiveWhenAtLimit() {
        freshLimiter()
        let key = "test_cd_full"
        _ = RateLimiter.shared.allow(key: key, maxAttempts: 1, window: 60)
        let cd = RateLimiter.shared.cooldown(key: key, maxAttempts: 1, window: 60)
        #expect(cd > 0)
    }

    @Test func resetClearsAllState() {
        freshLimiter()
        let key = "test_reset"
        _ = RateLimiter.shared.allow(key: key, maxAttempts: 1, window: 60)
        #expect(!RateLimiter.shared.allow(key: key, maxAttempts: 1, window: 60))
        RateLimiter.shared.reset()
        #expect(RateLimiter.shared.allow(key: key, maxAttempts: 1, window: 60))
    }

    @Test func expiredTimestampsArePruned() {
        freshLimiter()
        let key = "test_expire"
        // Use a very short window (0.01 seconds)
        _ = RateLimiter.shared.allow(key: key, maxAttempts: 1, window: 0.01)
        // Wait for the window to expire
        Thread.sleep(forTimeInterval: 0.02)
        // Should be allowed again since the old timestamp expired
        #expect(RateLimiter.shared.allow(key: key, maxAttempts: 1, window: 0.01))
    }
}
