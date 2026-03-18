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

@Observable
final class ListingManager {

    // MARK: - State

    var isLoading = false
    var errorMessage: String?

    private let db = Firestore.firestore()

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
                      let price = data["price"] as? Double,
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

                return Listing(
                    id: doc.documentID,
                    title: title,
                    description: description,
                    price: price,
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

    // MARK: - Create Listing

    func createListing(
        title: String,
        description: String,
        price: Double,
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

            let data: [String: Any] = [
                "id": listingId,
                "title": title,
                "description": description,
                "price": price,
                "category": category.rawValue,
                "condition": condition.rawValue,
                "location": location,
                "photoURLs": photoURLs,
                "sellerUID": sellerUID,
                "sellerUsername": sellerUsername,
                "createdAt": FieldValue.serverTimestamp()
            ]

            try await db.collection("listings").document(listingId).setData(data)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
