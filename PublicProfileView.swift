//
//  PublicProfileView.swift
//  backline
//
//  Created by Khadija Aslam on 4/7/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PublicProfileView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ListingManager.self) private var listingManager

    let uid: String
    let username: String

    @State private var profilePhotoURL: String?
    @State private var bio: String?
    @State private var instagramHandle: String?
    @State private var musicProjects: [MusicProject] = []
    @State private var genres: [String] = []
    @State private var roles: [String] = []
    @State private var userListings: [Listing] = []
    @State private var userServices: [ServiceListing] = []
    @State private var userIsoPosts: [ISOPost] = []
    @State private var isLoadingProfile = true

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    private let db = Firestore.firestore()

    private var isOwnProfile: Bool {
        uid == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            if isLoadingProfile {
                ProgressView()
                    .padding(.top, 60)
            } else {
                VStack(spacing: 20) {

                    // Header: photo + username + bio + instagram
                    profileHeaderSection

                    // Genres
                    genresSection

                    // Roles
                    rolesSection

                    // Featured Projects
                    if !musicProjects.isEmpty {
                        musicProjectsSection
                    }

                    // Message button
                    if !isOwnProfile {
                        Button {
                            Task { await messageUserTapped() }
                        } label: {
                            Text("Message")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                        .padding(.horizontal)
                    }

                    // Services
                    if !userServices.isEmpty {
                        servicesSection
                    }

                    // ISO Posts (non-expired only for public view)
                    if !userIsoPosts.filter({ !$0.isExpired }).isEmpty {
                        isoPostsSection
                    }

                    // Listings
                    if !userListings.isEmpty {
                        listingsSection
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToChat) {
            if let convId = activeChatConversationId,
               let conv = activeChatConversation {
                ChatView(conversationId: convId, conversation: conv)
            }
        }
        .task {
            await loadProfile()
        }
    }

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Profile photo
            if let urlString = profilePhotoURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)
            }

            // Username, bio, instagram
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(username)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if let bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let handle = instagramHandle, !handle.isEmpty {
                    Link(destination: URL(string: "https://instagram.com/\(handle)") ?? URL(string: "https://instagram.com")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 9))
                            Text("@\(handle)")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Genres

    @ViewBuilder
    private var genresSection: some View {
        if !genres.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(genres, id: \.self) { genre in
                    Text("#\(genre)")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Roles

    @ViewBuilder
    private var rolesSection: some View {
        if !roles.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Featured Projects

    private var musicProjectsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Featured Projects")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(musicProjects) { project in
                    Link(destination: URL(string: project.url) ?? URL(string: "https://example.com")!) {
                        HStack(spacing: 10) {
                            Image(systemName: project.platform.iconName)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(project.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(project.platform.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - Listings

    private var listingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Listings")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(userListings) { listing in
                        NavigationLink(value: listing) {
                            listingCard(listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func listingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(width: 140, height: 100)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let price = listing.price {
                    Text("$\(price, specifier: "%.0f")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 140)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Services")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(userServices) { service in
                    NavigationLink(value: service) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(service.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(service.category.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(service.rate)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - ISO Posts

    private var isoPostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ISO Posts")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(userIsoPosts.filter { !$0.isExpired }) { post in
                    NavigationLink(value: post) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.roleNeeded)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text(post.category.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(post.budget)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - Load Profile

    private func loadProfile() async {
        isLoadingProfile = true

        // Fetch user profile
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let data = doc.data()
            profilePhotoURL = data?["profilePhotoURL"] as? String
            bio = data?["bio"] as? String
            instagramHandle = data?["instagramHandle"] as? String
            genres = data?["genres"] as? [String] ?? []
            roles = data?["roles"] as? [String] ?? []

            if let projectDicts = data?["musicProjects"] as? [[String: String]] {
                musicProjects = projectDicts.compactMap { dict in
                    guard let id = dict["id"],
                          let title = dict["title"],
                          let url = dict["url"],
                          let platformRaw = dict["platform"],
                          let platform = MusicPlatform(rawValue: platformRaw)
                    else { return nil }
                    return MusicProject(id: id, title: title, url: url, platform: platform)
                }
            }
        } catch {
            // Profile fetch failed
        }

        // Fetch listings, services, and ISO posts in parallel
        async let fetchedListings = fetchListings()
        async let fetchedServices = fetchServices()
        async let fetchedISOs = fetchISOs()

        userListings = await fetchedListings
        userServices = await fetchedServices
        userIsoPosts = await fetchedISOs

        isLoadingProfile = false
    }

    private func fetchListings() async -> [Listing] {
        do {
            let snapshot = try await db.collection("listings")
                .whereField("sellerUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
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
            return []
        }
    }

    private func fetchServices() async -> [ServiceListing] {
        do {
            let snapshot = try await db.collection("serviceListings")
                .whereField("sellerUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
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
            return []
        }
    }

    private func fetchISOs() async -> [ISOPost] {
        do {
            let snapshot = try await db.collection("isoPosts")
                .whereField("posterUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
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
            return []
        }
    }

    // MARK: - Message User

    private func messageUserTapped() async {
        guard let currentUID = authManager.currentUser?.uid,
              let currentUsername = authManager.username else { return }

        if let convId = await messagesManager.startConversation(
            currentUID: currentUID,
            currentUsername: currentUsername,
            otherUID: uid,
            otherUsername: username
        ) {
            let conversation = messagesManager.conversations.first(where: { $0.id == convId })
                ?? Conversation(
                    id: convId,
                    participants: [currentUID, uid],
                    participantUsernames: [currentUID: currentUsername, uid: username],
                    lastMessage: "",
                    lastMessageAt: Date(),
                    lastMessageSenderUID: "",
                    lastReadAt: [:]
                )
            activeChatConversationId = convId
            activeChatConversation = conversation
            navigateToChat = true
        }
    }
}
