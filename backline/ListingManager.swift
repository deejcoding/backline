//
//  ListingManager.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

struct UserProfile: Identifiable, Hashable {
    let id: String  // uid
    let username: String
    var displayName: String?
    var profilePhotoURL: String?
    var roles: [String]
    var genres: [String]
    var bio: String?

    /// 0–5 score based on how complete the profile is.
    var completenessScore: Int {
        var score = 0
        if profilePhotoURL != nil && !(profilePhotoURL?.isEmpty ?? true) { score += 1 }
        if displayName != nil && !(displayName?.isEmpty ?? true) { score += 1 }
        if !roles.isEmpty { score += 1 }
        if !genres.isEmpty { score += 1 }
        if bio != nil && !(bio?.isEmpty ?? true) { score += 1 }
        return score
    }
}

@Observable
final class ListingManager {

    // MARK: - State

    var isLoading = false
    var errorMessage: String?
    var profilePhotos: [String: String] = [:]  // uid -> profilePhotoURL
    var allUsers: [UserProfile] = []

    private let db = Firestore.firestore()

    // MARK: - Retry Helper

    private func withRetry<T>(maxAttempts: Int = 3, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }
        throw lastError ?? NSError(domain: "ListingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during retry operation"])
    }

    // MARK: - Fetch All Users

    func fetchAllUsers() async {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            allUsers = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let username = data["username"] as? String, !username.isEmpty else { return nil }
                let displayName = data["displayName"] as? String
                let photoURL = data["profilePhotoURL"] as? String
                let roles = data["roles"] as? [String] ?? []
                let genres = data["genres"] as? [String] ?? []
                let bio = data["bio"] as? String
                return UserProfile(
                    id: doc.documentID,
                    username: username,
                    displayName: displayName,
                    profilePhotoURL: photoURL,
                    roles: roles,
                    genres: genres,
                    bio: bio
                )
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Profile Photo Cache

    func fetchProfilePhotos(for uids: [String]) async {
        let uncachedUIDs = uids.filter { profilePhotos[$0] == nil }
        guard !uncachedUIDs.isEmpty else { return }

        // Firestore 'in' queries support max 30 items
        for batch in stride(from: 0, to: uncachedUIDs.count, by: 30) {
            let end = min(batch + 30, uncachedUIDs.count)
            let batchUIDs = Array(uncachedUIDs[batch..<end])
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batchUIDs)
                    .getDocuments()
                for doc in snapshot.documents {
                    if let url = doc.data()["profilePhotoURL"] as? String, !url.isEmpty {
                        profilePhotos[doc.documentID] = url
                    }
                }
            } catch {
                // Silently fail
            }
        }
    }

    // MARK: - Photo Upload

    func uploadPhotos(images: [UIImage], listingId: String) async throws -> [String] {
        var urls: [String] = []
        for (index, image) in images.enumerated() {
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else { continue }
            let ref = Storage.storage().reference()
                .child("listing_photos/\(listingId)/\(index).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(jpegData, metadata: metadata)
            let url = try await ref.downloadURL()
            urls.append(url.absoluteString)
        }
        return urls
    }

    // MARK: - Fetch Listings

    var listings: [Listing] = []

    func fetchListings() async {
        do {
            let snapshot = try await db.collection("listings")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            listings = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let description = data["description"] as? String,
                      let categoryRaw = data["category"] as? String,
                      let category = ListingCategory(rawValue: categoryRaw),
                      let conditionRaw = data["condition"] as? String,
                      let condition = ListingCondition(rawValue: conditionRaw),
                      let location = data["location"] as? String,
                      let photoURLs = data["photoURLs"] as? [String],
                      let sellerUID = data["sellerUID"] as? String,
                      let sellerUsername = data["sellerUsername"] as? String
                else { return nil }

                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let price = data["price"] as? Double
                let rentPrice = data["rentPrice"] as? String

                let listingTypeStrings = data["listingTypes"] as? [String] ?? ["Sell"]
                let listingTypes = listingTypeStrings.compactMap { ListingType(rawValue: $0) }
                let borough = (data["borough"] as? String).flatMap { Borough(rawValue: $0) }

                return Listing(
                    id: doc.documentID,
                    title: title,
                    description: description,
                    price: price,
                    rentPrice: rentPrice,
                    listingTypes: listingTypes.isEmpty ? [.sell] : listingTypes,
                    category: category,
                    condition: condition,
                    location: location,
                    borough: borough,
                    photoURLs: photoURLs,
                    sellerUID: sellerUID,
                    sellerUsername: sellerUsername,
                    createdAt: createdAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch User Listings

    var userListings: [Listing] = []
    var userServiceListings: [ServiceListing] = []
    var isoPosts: [ISOPost] = []
    var userIsoPosts: [ISOPost] = []
    var showFlyers: [ShowFlyer] = []
    var userShowFlyers: [ShowFlyer] = []

    func fetchUserListings(uid: String) async {
        do {
            let snapshot = try await db.collection("listings")
                .whereField("sellerUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            userListings = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let description = data["description"] as? String,
                      let categoryRaw = data["category"] as? String,
                      let category = ListingCategory(rawValue: categoryRaw),
                      let conditionRaw = data["condition"] as? String,
                      let condition = ListingCondition(rawValue: conditionRaw),
                      let location = data["location"] as? String,
                      let photoURLs = data["photoURLs"] as? [String],
                      let sellerUID = data["sellerUID"] as? String,
                      let sellerUsername = data["sellerUsername"] as? String
                else { return nil }

                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let price = data["price"] as? Double
                let rentPrice = data["rentPrice"] as? String
                let listingTypeStrings = data["listingTypes"] as? [String] ?? ["Sell"]
                let listingTypes = listingTypeStrings.compactMap { ListingType(rawValue: $0) }
                let borough = (data["borough"] as? String).flatMap { Borough(rawValue: $0) }

                return Listing(
                    id: doc.documentID,
                    title: title,
                    description: description,
                    price: price,
                    rentPrice: rentPrice,
                    listingTypes: listingTypes.isEmpty ? [.sell] : listingTypes,
                    category: category,
                    condition: condition,
                    location: location,
                    borough: borough,
                    photoURLs: photoURLs,
                    sellerUID: sellerUID,
                    sellerUsername: sellerUsername,
                    createdAt: createdAt
                )
            }
        } catch {
            // Silently fail for profile listings
        }
    }

    func fetchUserServiceListings(uid: String) async {
        do {
            let snapshot = try await db.collection("serviceListings")
                .whereField("sellerUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            userServiceListings = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let categoryRaw = data["category"] as? String,
                      let category = ServiceCategory(rawValue: categoryRaw),
                      let description = data["description"] as? String,
                      let rate = data["rate"] as? String,
                      let sellerUID = data["sellerUID"] as? String,
                      let sellerUsername = data["sellerUsername"] as? String
                else { return nil }

                let portfolioURL = data["portfolioURL"] as? String
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ServiceListing(
                    id: doc.documentID,
                    title: title,
                    category: category,
                    description: description,
                    portfolioURL: portfolioURL,
                    rate: rate,
                    sellerUID: sellerUID,
                    sellerUsername: sellerUsername,
                    createdAt: createdAt
                )
            }
        } catch {
            // Silently fail for profile listings
        }
    }

    // MARK: - Fetch Service Listings

    var serviceListings: [ServiceListing] = []

    func fetchServiceListings() async {
        do {
            let snapshot = try await db.collection("serviceListings")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            serviceListings = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let categoryRaw = data["category"] as? String,
                      let category = ServiceCategory(rawValue: categoryRaw),
                      let description = data["description"] as? String,
                      let rate = data["rate"] as? String,
                      let sellerUID = data["sellerUID"] as? String,
                      let sellerUsername = data["sellerUsername"] as? String
                else { return nil }

                let portfolioURL = data["portfolioURL"] as? String
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ServiceListing(
                    id: doc.documentID,
                    title: title,
                    category: category,
                    description: description,
                    portfolioURL: portfolioURL,
                    rate: rate,
                    sellerUID: sellerUID,
                    sellerUsername: sellerUsername,
                    createdAt: createdAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Service Listing

    func createServiceListing(
        title: String,
        category: ServiceCategory,
        description: String,
        portfolioURL: String?,
        rate: String,
        sellerUID: String,
        sellerUsername: String
    ) async {
        // Rate limit: 5 services per hour
        guard RateLimiter.shared.allow(key: "createService_\(sellerUID)", maxAttempts: 5, window: 3600) else {
            errorMessage = "You're creating services too fast. Please wait before posting again."
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let docId = db.collection("serviceListings").document().documentID

            var data: [String: Any] = [
                "id": docId,
                "title": title,
                "category": category.rawValue,
                "description": description,
                "rate": rate,
                "sellerUID": sellerUID,
                "sellerUsername": sellerUsername,
                "createdAt": FieldValue.serverTimestamp()
            ]

            if let portfolioURL, !portfolioURL.isEmpty {
                data["portfolioURL"] = portfolioURL
            }

            try await withRetry {
                try await self.db.collection("serviceListings").document(docId).setData(data)
            }
            BLAnalytics.createServiceListing(category: category.rawValue)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Delete Listing

    func deleteListing(id: String) async {
        do {
            try await withRetry { try await self.db.collection("listings").document(id).delete() }
            listings.removeAll { $0.id == id }
            userListings.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteServiceListing(id: String) async {
        do {
            try await withRetry { try await self.db.collection("serviceListings").document(id).delete() }
            serviceListings.removeAll { $0.id == id }
            userServiceListings.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Listing

    func updateListing(
        id: String,
        title: String,
        description: String,
        price: Double?,
        rentPrice: String?,
        listingTypes: [ListingType],
        category: ListingCategory,
        condition: ListingCondition,
        location: String,
        borough: Borough?,
        existingPhotoURLs: [String],
        newImages: [UIImage]
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            // Upload any new images
            var allPhotoURLs = existingPhotoURLs
            if !newImages.isEmpty {
                let newURLs = try await uploadPhotos(images: newImages, listingId: id)
                allPhotoURLs.append(contentsOf: newURLs)
            }

            var data: [String: Any] = [
                "title": title,
                "description": description,
                "listingTypes": listingTypes.map { $0.rawValue },
                "category": category.rawValue,
                "condition": condition.rawValue,
                "location": location,
                "photoURLs": allPhotoURLs
            ]

            if let price {
                data["price"] = price
            } else {
                data["price"] = FieldValue.delete()
            }

            if let rentPrice, !rentPrice.isEmpty {
                data["rentPrice"] = rentPrice
            } else {
                data["rentPrice"] = FieldValue.delete()
            }

            if let borough {
                data["borough"] = borough.rawValue
            } else {
                data["borough"] = FieldValue.delete()
            }

            try await withRetry {
                try await self.db.collection("listings").document(id).updateData(data)
            }

            // Update local arrays
            if let index = listings.firstIndex(where: { $0.id == id }) {
                listings[index].title = title
                listings[index].description = description
                listings[index].price = price
                listings[index].rentPrice = rentPrice
                listings[index].listingTypes = listingTypes
                listings[index].category = category
                listings[index].condition = condition
                listings[index].location = location
                listings[index].borough = borough
                listings[index].photoURLs = allPhotoURLs
            }
            if let index = userListings.firstIndex(where: { $0.id == id }) {
                userListings[index].title = title
                userListings[index].description = description
                userListings[index].price = price
                userListings[index].rentPrice = rentPrice
                userListings[index].listingTypes = listingTypes
                userListings[index].category = category
                userListings[index].condition = condition
                userListings[index].location = location
                userListings[index].borough = borough
                userListings[index].photoURLs = allPhotoURLs
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateServiceListing(
        id: String,
        title: String,
        category: ServiceCategory,
        description: String,
        portfolioURL: String?,
        rate: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            var data: [String: Any] = [
                "title": title,
                "category": category.rawValue,
                "description": description,
                "rate": rate
            ]

            if let portfolioURL, !portfolioURL.isEmpty {
                data["portfolioURL"] = portfolioURL
            } else {
                data["portfolioURL"] = FieldValue.delete()
            }

            try await withRetry {
                try await self.db.collection("serviceListings").document(id).updateData(data)
            }

            // Update local arrays
            if let index = serviceListings.firstIndex(where: { $0.id == id }) {
                serviceListings[index].title = title
                serviceListings[index].category = category
                serviceListings[index].description = description
                serviceListings[index].portfolioURL = portfolioURL
                serviceListings[index].rate = rate
            }
            if let index = userServiceListings.firstIndex(where: { $0.id == id }) {
                userServiceListings[index].title = title
                userServiceListings[index].category = category
                userServiceListings[index].description = description
                userServiceListings[index].portfolioURL = portfolioURL
                userServiceListings[index].rate = rate
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create Listing

    func createListing(
        title: String,
        description: String,
        price: Double?,
        rentPrice: String?,
        listingTypes: [ListingType],
        category: ListingCategory,
        condition: ListingCondition,
        location: String,
        borough: Borough?,
        images: [UIImage],
        sellerUID: String,
        sellerUsername: String
    ) async {
        // Rate limit: 5 listings per hour
        guard RateLimiter.shared.allow(key: "createListing_\(sellerUID)", maxAttempts: 5, window: 3600) else {
            errorMessage = "You're creating listings too fast. Please wait before posting again."
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let listingId = db.collection("listings").document().documentID

            let photoURLs = try await uploadPhotos(images: images, listingId: listingId)

            var data: [String: Any] = [
                "id": listingId,
                "title": title,
                "description": description,
                "listingTypes": listingTypes.map { $0.rawValue },
                "category": category.rawValue,
                "condition": condition.rawValue,
                "location": location,
                "photoURLs": photoURLs,
                "sellerUID": sellerUID,
                "sellerUsername": sellerUsername,
                "createdAt": FieldValue.serverTimestamp()
            ]

            if let price {
                data["price"] = price
            }
            if let rentPrice, !rentPrice.isEmpty {
                data["rentPrice"] = rentPrice
            }
            if let borough {
                data["borough"] = borough.rawValue
            }

            try await withRetry {
                try await self.db.collection("listings").document(listingId).setData(data)
            }
            BLAnalytics.createListing(category: category.rawValue)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch ISO Posts

    func fetchIsoPosts() async {
        do {
            let snapshot = try await db.collection("isoPosts")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            isoPosts = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let categoryRaw = data["category"] as? String,
                      let category = ISOCategory(rawValue: categoryRaw),
                      let roleNeeded = data["roleNeeded"] as? String,
                      let budget = data["budget"] as? String,
                      let description = data["description"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let location = data["location"] as? String
                let timeframe = (data["timeframe"] as? Timestamp)?.dateValue()
                let isOngoing = data["isOngoing"] as? Bool
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ISOPost(
                    id: doc.documentID,
                    category: category,
                    roleNeeded: roleNeeded,
                    location: location,
                    timeframe: timeframe,
                    isOngoing: isOngoing,
                    budget: budget,
                    description: description,
                    posterUID: posterUID,
                    posterUsername: posterUsername,
                    createdAt: createdAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchUserIsoPosts(uid: String) async {
        do {
            let snapshot = try await db.collection("isoPosts")
                .whereField("posterUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            userIsoPosts = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let categoryRaw = data["category"] as? String,
                      let category = ISOCategory(rawValue: categoryRaw),
                      let roleNeeded = data["roleNeeded"] as? String,
                      let budget = data["budget"] as? String,
                      let description = data["description"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let location = data["location"] as? String
                let timeframe = (data["timeframe"] as? Timestamp)?.dateValue()
                let isOngoing = data["isOngoing"] as? Bool
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ISOPost(
                    id: doc.documentID,
                    category: category,
                    roleNeeded: roleNeeded,
                    location: location,
                    timeframe: timeframe,
                    isOngoing: isOngoing,
                    budget: budget,
                    description: description,
                    posterUID: posterUID,
                    posterUsername: posterUsername,
                    createdAt: createdAt
                )
            }
        } catch {
            // Silently fail for profile
        }
    }

    // MARK: - Create ISO Post

    func createISOPost(
        category: ISOCategory,
        roleNeeded: String,
        location: String?,
        timeframe: Date?,
        isOngoing: Bool,
        budget: String,
        description: String,
        posterUID: String,
        posterUsername: String
    ) async {
        // Rate limit: 5 ISO posts per hour
        guard RateLimiter.shared.allow(key: "createISO_\(posterUID)", maxAttempts: 5, window: 3600) else {
            errorMessage = "You're creating posts too fast. Please wait before posting again."
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let docId = db.collection("isoPosts").document().documentID

            var data: [String: Any] = [
                "id": docId,
                "category": category.rawValue,
                "roleNeeded": roleNeeded,
                "budget": budget,
                "description": description,
                "posterUID": posterUID,
                "posterUsername": posterUsername,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let location, !location.isEmpty {
                data["location"] = location
            }
            if isOngoing {
                data["isOngoing"] = true
            } else if let timeframe {
                data["timeframe"] = Timestamp(date: timeframe)
            }

            try await withRetry {
                try await self.db.collection("isoPosts").document(docId).setData(data)
            }
            BLAnalytics.createISOPost(category: category.rawValue, role: roleNeeded)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Update ISO Post

    func updateISOPost(
        id: String,
        category: ISOCategory,
        roleNeeded: String,
        location: String?,
        timeframe: Date?,
        isOngoing: Bool,
        budget: String,
        description: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            var data: [String: Any] = [
                "category": category.rawValue,
                "roleNeeded": roleNeeded,
                "budget": budget,
                "description": description
            ]
            if let location, !location.isEmpty {
                data["location"] = location
            } else {
                data["location"] = FieldValue.delete()
            }
            if isOngoing {
                data["isOngoing"] = true
                data["timeframe"] = FieldValue.delete()
            } else if let timeframe {
                data["isOngoing"] = FieldValue.delete()
                data["timeframe"] = Timestamp(date: timeframe)
            } else {
                data["isOngoing"] = FieldValue.delete()
                data["timeframe"] = FieldValue.delete()
            }

            try await withRetry {
                try await self.db.collection("isoPosts").document(id).updateData(data)
            }

            if let index = isoPosts.firstIndex(where: { $0.id == id }) {
                isoPosts[index].category = category
                isoPosts[index].roleNeeded = roleNeeded
                isoPosts[index].location = location
                isoPosts[index].timeframe = isOngoing ? nil : timeframe
                isoPosts[index].isOngoing = isOngoing ? true : nil
                isoPosts[index].budget = budget
                isoPosts[index].description = description
            }
            if let index = userIsoPosts.firstIndex(where: { $0.id == id }) {
                userIsoPosts[index].category = category
                userIsoPosts[index].roleNeeded = roleNeeded
                userIsoPosts[index].location = location
                userIsoPosts[index].timeframe = isOngoing ? nil : timeframe
                userIsoPosts[index].isOngoing = isOngoing ? true : nil
                userIsoPosts[index].budget = budget
                userIsoPosts[index].description = description
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Delete ISO Post

    func deleteISOPost(id: String) async {
        do {
            try await withRetry { try await self.db.collection("isoPosts").document(id).delete() }
            isoPosts.removeAll { $0.id == id }
            userIsoPosts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reports

    func submitReport(
        reporterUID: String,
        reportedUID: String,
        contentType: String,
        contentId: String,
        reason: String,
        details: String
    ) async -> Bool {
        do {
            try await withRetry {
                try await self.db.collection("reports").addDocument(data: [
                    "reporterUID": reporterUID,
                    "reportedUID": reportedUID,
                    "contentType": contentType,
                    "contentId": contentId,
                    "reason": reason,
                    "details": details,
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }
            BLAnalytics.submitReport(contentType: contentType)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Fetch Single Items by ID (for deep links)

    func fetchListing(id: String) async -> Listing? {
        // Check local cache first
        if let cached = listings.first(where: { $0.id == id }) { return cached }

        do {
            let doc = try await db.collection("listings").document(id).getDocument()
            guard let data = doc.data(),
                  let title = data["title"] as? String,
                  let description = data["description"] as? String,
                  let categoryRaw = data["category"] as? String,
                  let category = ListingCategory(rawValue: categoryRaw),
                  let conditionRaw = data["condition"] as? String,
                  let condition = ListingCondition(rawValue: conditionRaw),
                  let location = data["location"] as? String,
                  let photoURLs = data["photoURLs"] as? [String],
                  let sellerUID = data["sellerUID"] as? String,
                  let sellerUsername = data["sellerUsername"] as? String
            else { return nil }

            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let price = data["price"] as? Double
            let rentPrice = data["rentPrice"] as? String
            let listingTypeStrings = data["listingTypes"] as? [String] ?? ["Sell"]
            let listingTypes = listingTypeStrings.compactMap { ListingType(rawValue: $0) }
            let borough = (data["borough"] as? String).flatMap { Borough(rawValue: $0) }

            return Listing(
                id: doc.documentID,
                title: title,
                description: description,
                price: price,
                rentPrice: rentPrice,
                listingTypes: listingTypes.isEmpty ? [.sell] : listingTypes,
                category: category,
                condition: condition,
                location: location,
                borough: borough,
                photoURLs: photoURLs,
                sellerUID: sellerUID,
                sellerUsername: sellerUsername,
                createdAt: createdAt
            )
        } catch {
            return nil
        }
    }

    func fetchServiceListing(id: String) async -> ServiceListing? {
        if let cached = serviceListings.first(where: { $0.id == id }) { return cached }

        do {
            let doc = try await db.collection("serviceListings").document(id).getDocument()
            guard let data = doc.data(),
                  let title = data["title"] as? String,
                  let categoryRaw = data["category"] as? String,
                  let category = ServiceCategory(rawValue: categoryRaw),
                  let description = data["description"] as? String,
                  let rate = data["rate"] as? String,
                  let sellerUID = data["sellerUID"] as? String,
                  let sellerUsername = data["sellerUsername"] as? String
            else { return nil }

            let portfolioURL = data["portfolioURL"] as? String
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

            return ServiceListing(
                id: doc.documentID,
                title: title,
                category: category,
                description: description,
                portfolioURL: portfolioURL,
                rate: rate,
                sellerUID: sellerUID,
                sellerUsername: sellerUsername,
                createdAt: createdAt
            )
        } catch {
            return nil
        }
    }

    func fetchISOPost(id: String) async -> ISOPost? {
        if let cached = isoPosts.first(where: { $0.id == id }) { return cached }

        do {
            let doc = try await db.collection("isoPosts").document(id).getDocument()
            guard let data = doc.data(),
                  let categoryRaw = data["category"] as? String,
                  let category = ISOCategory(rawValue: categoryRaw),
                  let roleNeeded = data["roleNeeded"] as? String,
                  let budget = data["budget"] as? String,
                  let description = data["description"] as? String,
                  let posterUID = data["posterUID"] as? String,
                  let posterUsername = data["posterUsername"] as? String
            else { return nil }

            let location = data["location"] as? String
            let timeframe = (data["timeframe"] as? Timestamp)?.dateValue()
            let isOngoing = data["isOngoing"] as? Bool
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

            return ISOPost(
                id: doc.documentID,
                category: category,
                roleNeeded: roleNeeded,
                location: location,
                timeframe: timeframe,
                isOngoing: isOngoing,
                budget: budget,
                description: description,
                posterUID: posterUID,
                posterUsername: posterUsername,
                createdAt: createdAt
            )
        } catch {
            return nil
        }
    }

    // MARK: - Show Flyers

    func uploadFlyerPhoto(image: UIImage, flyerId: String) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ListingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        let ref = Storage.storage().reference().child("flyer_photos/\(flyerId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpegData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func fetchShowFlyers() async {
        do {
            let snapshot = try await db.collection("showFlyers")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            showFlyers = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let imageURL = data["imageURL"] as? String,
                      let title = data["title"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let venue = data["venue"] as? String
                let eventDate = (data["eventDate"] as? Timestamp)?.dateValue()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let ticketURL = data["ticketURL"] as? String

                return ShowFlyer(
                    id: doc.documentID,
                    imageURL: imageURL,
                    title: title,
                    venue: venue,
                    eventDate: eventDate,
                    posterUID: posterUID,
                    posterUsername: posterUsername,
                    createdAt: createdAt,
                    ticketURL: ticketURL
                )
            }
        } catch {
            // Silently fail — collection may not exist yet
        }
    }

    func fetchUserShowFlyers(uid: String) async {
        do {
            let snapshot = try await db.collection("showFlyers")
                .whereField("posterUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            userShowFlyers = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let imageURL = data["imageURL"] as? String,
                      let title = data["title"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let venue = data["venue"] as? String
                let eventDate = (data["eventDate"] as? Timestamp)?.dateValue()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let ticketURL = data["ticketURL"] as? String

                return ShowFlyer(
                    id: doc.documentID,
                    imageURL: imageURL,
                    title: title,
                    venue: venue,
                    eventDate: eventDate,
                    posterUID: posterUID,
                    posterUsername: posterUsername,
                    createdAt: createdAt,
                    ticketURL: ticketURL
                )
            }
        } catch {
            // Silently fail for profile
        }
    }

    func fetchShowFlyer(id: String) async -> ShowFlyer? {
        if let cached = showFlyers.first(where: { $0.id == id }) { return cached }

        do {
            let doc = try await db.collection("showFlyers").document(id).getDocument()
            guard let data = doc.data(),
                  let imageURL = data["imageURL"] as? String,
                  let title = data["title"] as? String,
                  let posterUID = data["posterUID"] as? String,
                  let posterUsername = data["posterUsername"] as? String
            else { return nil }

            let venue = data["venue"] as? String
            let eventDate = (data["eventDate"] as? Timestamp)?.dateValue()
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let ticketURL = data["ticketURL"] as? String

            return ShowFlyer(
                id: doc.documentID,
                imageURL: imageURL,
                title: title,
                venue: venue,
                eventDate: eventDate,
                posterUID: posterUID,
                posterUsername: posterUsername,
                createdAt: createdAt,
                ticketURL: ticketURL
            )
        } catch {
            return nil
        }
    }

    func createShowFlyer(
        title: String,
        venue: String?,
        eventDate: Date?,
        ticketURL: String?,
        image: UIImage,
        posterUID: String,
        posterUsername: String
    ) async {
        guard RateLimiter.shared.allow(key: "createFlyer_\(posterUID)", maxAttempts: 5, window: 3600) else {
            errorMessage = "You're posting flyers too fast. Please wait before posting again."
            return
        }
        isLoading = true
        errorMessage = nil

        do {
            let docId = db.collection("showFlyers").document().documentID
            let imageURL = try await uploadFlyerPhoto(image: image, flyerId: docId)

            var data: [String: Any] = [
                "id": docId,
                "imageURL": imageURL,
                "title": title,
                "posterUID": posterUID,
                "posterUsername": posterUsername,
                "createdAt": FieldValue.serverTimestamp()
            ]
            if let venue, !venue.isEmpty {
                data["venue"] = venue
            }
            if let eventDate {
                data["eventDate"] = Timestamp(date: eventDate)
            }
            if let ticketURL, !ticketURL.isEmpty {
                data["ticketURL"] = ticketURL
            }

            try await withRetry {
                try await self.db.collection("showFlyers").document(docId).setData(data)
            }
            BLAnalytics.createShowFlyer()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateShowFlyer(
        id: String,
        title: String,
        venue: String?,
        eventDate: Date?,
        ticketURL: String?
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            var data: [String: Any] = [
                "title": title
            ]
            if let venue, !venue.isEmpty {
                data["venue"] = venue
            } else {
                data["venue"] = FieldValue.delete()
            }
            if let eventDate {
                data["eventDate"] = Timestamp(date: eventDate)
            } else {
                data["eventDate"] = FieldValue.delete()
            }
            if let ticketURL, !ticketURL.isEmpty {
                data["ticketURL"] = ticketURL
            } else {
                data["ticketURL"] = FieldValue.delete()
            }

            try await withRetry {
                try await self.db.collection("showFlyers").document(id).updateData(data)
            }

            if let index = showFlyers.firstIndex(where: { $0.id == id }) {
                showFlyers[index].title = title
                showFlyers[index].venue = venue
                showFlyers[index].eventDate = eventDate
                showFlyers[index].ticketURL = ticketURL
            }
            if let index = userShowFlyers.firstIndex(where: { $0.id == id }) {
                userShowFlyers[index].title = title
                userShowFlyers[index].venue = venue
                userShowFlyers[index].eventDate = eventDate
                userShowFlyers[index].ticketURL = ticketURL
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteShowFlyer(id: String) async {
        do {
            try await withRetry { try await self.db.collection("showFlyers").document(id).delete() }
            // Also delete the flyer image from storage
            try? await Storage.storage().reference().child("flyer_photos/\(id).jpg").delete()
            showFlyers.removeAll { $0.id == id }
            userShowFlyers.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
