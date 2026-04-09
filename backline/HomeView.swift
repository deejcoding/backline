//
//  HomeView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(MessagesManager.self) private var messagesManager

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    // Top gigs: ISO posts that match the user's roles
    private var matchedGigs: [ISOPost] {
        let userRoles = Set(authManager.roles.map { $0.lowercased() })
        guard !userRoles.isEmpty else { return Array(listingManager.isoPosts.filter { !$0.isExpired }.prefix(10)) }
        return listingManager.isoPosts
            .filter { !$0.isExpired }
            .filter { userRoles.contains($0.roleNeeded.lowercased()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // Discover: users who share genres with the current user, excluding self
    private var discoverUsers: [UserProfile] {
        let currentUID = authManager.currentUser?.uid ?? ""
        let userGenres = Set(authManager.genres.map { $0.lowercased() })
        let others = listingManager.allUsers.filter { $0.id != currentUID }
        if userGenres.isEmpty { return Array(others.prefix(10)) }
        return others
            .filter { user in
                user.genres.contains(where: { userGenres.contains($0.lowercased()) })
            }
    }

    // Recent listings
    private var recentListings: [Listing] {
        Array(listingManager.listings.prefix(10))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - Top Gigs
                    topGigsSection

                    // MARK: - Discover Artists
                    discoverSection

                    // MARK: - Recent Listings
                    recentListingsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("For You")
            .task {
                async let iso: () = listingManager.fetchIsoPosts()
                async let users: () = listingManager.fetchAllUsers()
                async let items: () = listingManager.fetchListings()
                _ = await (iso, users, items)

                // Fetch profile photos for ISO posters
                let uids = Array(Set(listingManager.isoPosts.map(\.posterUID)))
                await listingManager.fetchProfilePhotos(for: uids)
            }
            .refreshable {
                async let iso: () = listingManager.fetchIsoPosts()
                async let users: () = listingManager.fetchAllUsers()
                async let items: () = listingManager.fetchListings()
                _ = await (iso, users, items)
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if let convId = activeChatConversationId,
                   let conv = activeChatConversation {
                    ChatView(conversationId: convId, conversation: conv)
                }
            }
            .navigationDestination(for: ISOPost.self) { post in
                ISOPostDetailView(post: post)
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                PublicProfileView(uid: dest.uid, username: dest.username)
            }
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing)
            }
            .navigationDestination(for: ServiceListing.self) { service in
                ServiceListingDetailView(service: service)
            }
        }
    }

    // MARK: - Top Gigs Section

    private var topGigsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Gigs For You")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if matchedGigs.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.mic")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No matching gigs right now")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Posts matching your skills will appear here.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(matchedGigs) { post in
                            NavigationLink(value: post) {
                                gigCard(post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func gigCard(_ post: ISOPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: profile pic + username is looking for...
            HStack(spacing: 8) {
                if let photoURL = listingManager.profilePhotos[post.posterUID],
                   let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color(.systemGray4))
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(.systemGray3))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(post.posterUsername)
                        .font(.caption2)
                        .fontWeight(.bold)
                    + Text(" is looking for...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Role needed
            Text(post.roleNeeded)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)

            // Budget + location
            HStack(spacing: 8) {
                Text(post.budget)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(ThemeColor.green)
                Text(post.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 220)
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Discover Artists Section

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Discover Artists")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if discoverUsers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No artists to discover yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(discoverUsers) { user in
                            NavigationLink(value: ProfileDestination(uid: user.id, username: user.username)) {
                                discoverCard(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func discoverCard(_ user: UserProfile) -> some View {
        VStack(spacing: 8) {
            // Profile photo
            if let urlString = user.profilePhotoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color(.systemGray4))
            }

            Text("@\(user.username)")
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)

            // Shared genres (up to 2)
            if !user.roles.isEmpty {
                FlowLayout(spacing: 3) {
                    ForEach(Array(user.roles.prefix(2).enumerated()), id: \.element) { index, role in
                        let color = ThemeColor.cycle(index)
                        Text(role)
                            .font(.system(size: 8))
                            .foregroundStyle(color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(width: 100)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Recent Listings Section

    private var recentListingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Listings")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if recentListings.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "guitars")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No listings yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentListings) { listing in
                            NavigationLink(value: listing) {
                                recentListingCard(listing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func recentListingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(width: 150, height: 110)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Rectangle().fill(Color(.systemGray4))
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Rectangle().fill(Color(.systemGray4))
                            }
                        }
                    } else {
                        Rectangle().fill(Color(.systemGray4))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let price = listing.price {
                    Text("$\(price, specifier: "%.0f")")
                        .font(.caption2)
                        .foregroundStyle(ThemeColor.green)
                }

                Text(listing.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 150)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
