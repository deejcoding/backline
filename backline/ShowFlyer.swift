//
//  ShowFlyer.swift
//  backline
//

import Foundation

struct ShowFlyer: Identifiable, Codable, Hashable {
    var id: String
    var imageURL: String
    var title: String
    var venue: String?
    var eventDate: Date?
    var posterUID: String
    var posterUsername: String
    var createdAt: Date
    var ticketURL: String?

    var isExpired: Bool {
        if let eventDate {
            // Expire the day after the event
            let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: eventDate) ?? eventDate
            return Date() > dayAfter
        }
        // No event date — expire after 30 days
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: createdAt) ?? createdAt
        return Date() > expirationDate
    }

    var timeAgoString: String {
        let interval = Date().timeIntervalSince(createdAt)
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
