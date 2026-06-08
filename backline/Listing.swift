//
//  Listing.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import Foundation

// MARK: - Profile Destination (for navigation)

struct ProfileDestination: Hashable {
    let uid: String
    let username: String
}

enum ProfileSubpage: Hashable {
    case connections
    case connectionRequests
}

// MARK: - Category

enum ListingCategory: String, CaseIterable, Codable {
    case guitars = "Guitars"
    case amps = "Amps"
    case synthesizers = "Synthesizers"
    case stringedInstruments = "Stringed Instruments"
    case drumsAndPercussion = "Drums & Percussion"
    case microphones = "Microphones"
    case accessories = "Accessories"
    case miscellaneous = "Miscellaneous"
}

// MARK: - Condition

enum ListingCondition: String, CaseIterable, Codable {
    case new = "New"
    case likeNew = "Like New"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

// MARK: - Service Category

enum ServiceCategory: String, CaseIterable, Codable {
    case giggingMusician = "Gigging Musician"
    case bandForHire = "Band for Hire"
    case repair = "Repair"
    case production = "Production"
    case design = "Design"
    case liveSound = "Live Sound"
}

// MARK: - ISO Category

enum ISOCategory: String, CaseIterable, Codable {
    case gig = "Gig"
    case bandmate = "Bandmate"
    case recording = "Recording"
    case production = "Production"
    case repair = "Repair"
    case lessons = "Lessons"
    case practiceSpace = "Practice Space"
}

// MARK: - ISO Post

struct ISOPost: Identifiable, Codable, Hashable {
    var id: String
    var category: ISOCategory
    var roleNeeded: String
    var location: String?
    var timeframe: Date?
    var isOngoing: Bool?
    var budget: String?
    var description: String
    var posterUID: String
    var posterUsername: String
    var createdAt: Date

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

// MARK: - Service Listing

struct ServiceListing: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var category: ServiceCategory
    var description: String
    var portfolioURL: String?
    var rate: String
    var sellerUID: String
    var sellerUsername: String
    var createdAt: Date
}

// MARK: - Borough

enum Borough: String, CaseIterable, Codable {
    case manhattan = "Manhattan"
    case brooklyn = "Brooklyn"
    case queens = "Queens"
    case bronx = "Bronx"
    case statenIsland = "Staten Island"
}

// MARK: - Listing Type

enum ListingType: String, CaseIterable, Codable {
    case sell = "Sell"
    case rent = "Rent"
}

// MARK: - Listing

struct Listing: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String
    var price: Double?
    var rentPrice: String?
    var listingTypes: [ListingType]
    var category: ListingCategory
    var condition: ListingCondition
    var location: String
    var borough: Borough?
    var photoURLs: [String]
    var sellerUID: String
    var sellerUsername: String
    var createdAt: Date
}
