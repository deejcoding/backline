//
//  Listing.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import Foundation

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
    case repair = "Repair"
    case production = "Production"
    case design = "Design"
    case liveSound = "Live Sound"
}

// MARK: - ISO Category

enum ISOCategory: String, CaseIterable, Codable {
    case gig = "Gig"
    case bandmate = "Bandmate"
    case service = "Service"
}

// MARK: - ISO Post

struct ISOPost: Identifiable, Codable {
    var id: String
    var category: ISOCategory
    var roleNeeded: String
    var location: String
    var timeframe: Date
    var budget: String
    var description: String
    var posterUID: String
    var posterUsername: String
    var createdAt: Date

    var isExpired: Bool {
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: createdAt) ?? createdAt
        return Date() > expirationDate
    }
}

// MARK: - Service Listing

struct ServiceListing: Identifiable, Codable {
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

// MARK: - Listing Type

enum ListingType: String, CaseIterable, Codable {
    case sell = "Sell"
    case rent = "Rent"
    case trade = "Trade"
}

// MARK: - Listing

struct Listing: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var price: Double?
    var rentPrice: String?
    var listingTypes: [ListingType]
    var category: ListingCategory
    var condition: ListingCondition
    var location: String
    var photoURLs: [String]
    var sellerUID: String
    var sellerUsername: String
    var createdAt: Date
}
