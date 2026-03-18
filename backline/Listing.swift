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

// MARK: - Listing

struct Listing: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var price: Double
    var category: ListingCategory
    var condition: ListingCondition
    var location: String
    var photoURLs: [String]
    var sellerUID: String
    var sellerUsername: String
    var createdAt: Date
}
