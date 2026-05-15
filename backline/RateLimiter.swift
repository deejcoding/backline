//
//  RateLimiter.swift
//  backline
//
//  Created by Claude on 5/3/26.
//

import Foundation

/// Simple in-memory rate limiter using a sliding window.
/// Each action key tracks timestamps of recent attempts.
/// If the number of attempts in the window exceeds the limit, the action is blocked.
final class RateLimiter {

    static let shared = RateLimiter()

    private var timestamps: [String: [Date]] = [:]
    private let lock = NSLock()

    private init() {}

    /// Check whether an action is allowed.
    /// - Parameters:
    ///   - key: A unique identifier for the action (e.g. "sendMessage", "createListing").
    ///   - maxAttempts: Maximum number of actions allowed within `window`.
    ///   - window: Time window in seconds.
    /// - Returns: `true` if the action is allowed, `false` if rate-limited.
    func allow(key: String, maxAttempts: Int, window: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let cutoff = now.addingTimeInterval(-window)

        // Remove expired timestamps
        var recent = (timestamps[key] ?? []).filter { $0 > cutoff }

        if recent.count >= maxAttempts {
            return false
        }

        recent.append(now)
        timestamps[key] = recent
        return true
    }

    /// Returns how many seconds until the next action is allowed, or 0 if allowed now.
    func cooldown(key: String, maxAttempts: Int, window: TimeInterval) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        let recent = (timestamps[key] ?? []).filter { $0 > cutoff }

        if recent.count < maxAttempts {
            return 0
        }

        // Earliest timestamp in window — cooldown expires when it leaves the window
        if let earliest = recent.first {
            return earliest.timeIntervalSince(cutoff)
        }
        return 0
    }

    /// Clear all tracked timestamps (e.g. on sign-out).
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        timestamps.removeAll()
    }
}
