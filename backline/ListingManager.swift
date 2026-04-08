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
    var profilePhotoURL: String?
    var roles: [String]
    var bio: String?
}

@Observable
final class ListingManager {

    // MARK: - State

    var isLoading = false
    var errorMessage: String?
    var profilePhotos: [String: String] = [:]  // uid -> profilePhotoURL
    var allUsers: [UserProfile] = []

    private let db = Firestore.firestore()

    // MARK: - Fetch All Users

    func fetchAllUsers() async {
        do {
            let snapshot = try await db.collection("users").getDocuments()
            allUsers = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let username = data["username"] as? String, !username.isEmpty else { return nil }
                let photoURL = data["profilePhotoURL"] as? String
                let roles = data["roles"] as? [String] ?? []
                let bio = data["bio"] as? String
                return UserProfile(
                    id: doc.documentID,
                    username: username,
                    profilePhotoURL: photoURL,
                    roles: roles,
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

            try await db.collection("serviceListings").document(docId).setData(data)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Delete Listing

    func deleteListing(id: String) async {
        do {
            try await db.collection("listings").document(id).delete()
            listings.removeAll { $0.id == id }
            userListings.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteServiceListing(id: String) async {
        do {
            try await db.collection("serviceListings").document(id).delete()
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
        location: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            var data: [String: Any] = [
                "title": title,
                "description": description,
                "listingTypes": listingTypes.map { $0.rawValue },
                "category": category.rawValue,
                "condition": condition.rawValue,
                "location": location
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

            try await db.collection("listings").document(id).updateData(data)

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

            try await db.collection("serviceListings").document(id).updateData(data)

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
        images: [UIImage],
        sellerUID: String,
        sellerUsername: String
    ) async {
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

            try await db.collection("listings").document(listingId).setData(data)
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
                      let location = data["location"] as? String,
                      let budget = data["budget"] as? String,
                      let description = data["description"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let timeframe = (data["timeframe"] as? Timestamp)?.dateValue() ?? Date()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ISOPost(
                    id: doc.documentID,
                    category: category,
                    roleNeeded: roleNeeded,
                    location: location,
                    timeframe: timeframe,
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
                      let location = data["location"] as? String,
                      let budget = data["budget"] as? String,
                      let description = data["description"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let timeframe = (data["timeframe"] as? Timestamp)?.dateValue() ?? Date()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ISOPost(
                    id: doc.documentID,
                    category: category,
                    roleNeeded: roleNeeded,
                    location: location,
                    timeframe: timeframe,
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
        location: String,
        timeframe: Date,
        budget: String,
        description: String,
        posterUID: String,
        posterUsername: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let docId = db.collection("isoPosts").document().documentID

            let data: [String: Any] = [
                "id": docId,
                "category": category.rawValue,
                "roleNeeded": roleNeeded,
                "location": location,
                "timeframe": Timestamp(date: timeframe),
                "budget": budget,
                "description": description,
                "posterUID": posterUID,
                "posterUsername": posterUsername,
                "createdAt": FieldValue.serverTimestamp()
            ]

            try await db.collection("isoPosts").document(docId).setData(data)
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
        location: String,
        timeframe: Date,
        budget: String,
        description: String
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let data: [String: Any] = [
                "category": category.rawValue,
                "roleNeeded": roleNeeded,
                "location": location,
                "timeframe": Timestamp(date: timeframe),
                "budget": budget,
                "description": description
            ]

            try await db.collection("isoPosts").document(id).updateData(data)

            if let index = isoPosts.firstIndex(where: { $0.id == id }) {
                isoPosts[index].category = category
                isoPosts[index].roleNeeded = roleNeeded
                isoPosts[index].location = location
                isoPosts[index].timeframe = timeframe
                isoPosts[index].budget = budget
                isoPosts[index].description = description
            }
            if let index = userIsoPosts.firstIndex(where: { $0.id == id }) {
                userIsoPosts[index].category = category
                userIsoPosts[index].roleNeeded = roleNeeded
                userIsoPosts[index].location = location
                userIsoPosts[index].timeframe = timeframe
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
            try await db.collection("isoPosts").document(id).delete()
            isoPosts.removeAll { $0.id == id }
            userIsoPosts.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
