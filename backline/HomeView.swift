//
//  HomeView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {

    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ConnectionsManager.self) private var connectionsManager

    @State private var searchText = ""
    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    // Synonym groups: each array contains terms that should match each other
    private static let roleSynonyms: [[String]] = [
        ["drums", "drummer", "percussionist", "percussion"],
        ["guitar", "guitarist"],
        ["bass", "bassist", "bass player"],
        ["vocals", "vocalist", "singer"],
        ["keyboardist", "keyboard", "keys", "pianist", "piano"],
        ["synth", "synthesizer", "synth player"],
        ["producing", "producer", "music producer"],
        ["dj", "disc jockey"],
        ["rapper", "mc", "emcee"],
        ["mixing engineer", "mixer", "mix engineer"],
        ["mastering engineer", "mastering"],
        ["recording engineer", "recording"],
        ["live sound engineering", "live sound", "sound engineer", "sound tech", "audio engineer"],
        ["graphic design", "graphic designer", "designer"],
        ["videography", "videographer", "video"],
        ["photography", "photographer"],
        ["managing", "manager", "band manager"],
        ["songwriting", "songwriter"],
        ["beat maker", "beatmaker", "beat producer"],
    ]

    /// Returns true if a user's role and a post's roleNeeded are semantically related.
    private func roleMatches(userRole: String, postRole: String) -> Bool {
        let u = userRole.lowercased()
        let p = postRole.lowercased()

        // Direct substring match (covers "drums" in "drummer" and vice versa)
        if u.contains(p) || p.contains(u) { return true }

        // Synonym group match
        for group in Self.roleSynonyms {
            let uInGroup = group.contains(where: { u.contains($0) || $0.contains(u) })
            let pInGroup = group.contains(where: { p.contains($0) || $0.contains(p) })
            if uInGroup && pInGroup { return true }
        }

        return false
    }

    // Top gigs: ISO posts that match the user's roles, falling back to most recent
    private var matchedGigs: [ISOPost] {
        let blocked = Set(authManager.blockedUsers)
        let userRoles = Set(authManager.roles.map { $0.lowercased() })
        let nonBlocked = listingManager.isoPosts
            .filter { !blocked.contains($0.posterUID) }
            .sorted { $0.createdAt > $1.createdAt }
        let base: [ISOPost]
        if userRoles.isEmpty {
            base = Array(nonBlocked.prefix(10))
        } else {
            let matched = nonBlocked.filter { post in
                userRoles.contains { role in roleMatches(userRole: role, postRole: post.roleNeeded) }
            }
            base = matched.isEmpty ? Array(nonBlocked.prefix(10)) : matched
        }
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.roleNeeded.lowercased().contains(query)
            || $0.posterUsername.lowercased().contains(query)
            || $0.budget.lowercased().contains(query)
            || $0.description.lowercased().contains(query)
        }
    }

    // Discover: prioritize mutuals > similar skills/genres > newest, exclude connected users
    private var discoverUsers: [UserProfile] {
        let currentUID = authManager.currentUser?.uid ?? ""
        let blocked = Set(authManager.blockedUsers)
        let connectedUIDs = Set(connectionsManager.connections.map { $0.otherUID(currentUID: currentUID) })
        let pendingUIDs = Set(
            connectionsManager.outgoingRequests.map(\.toUID)
            + connectionsManager.incomingRequests.map(\.fromUID)
        )
        let excludeUIDs = blocked.union(connectedUIDs).union(pendingUIDs)

        let others = listingManager.allUsers.filter { $0.id != currentUID && !excludeUIDs.contains($0.id) }

        let userGenres = Set(authManager.genres.map { $0.lowercased() })
        let userRoles = Set(authManager.roles.map { $0.lowercased() })

        // Score each user: mutuals first, then profile completeness + skill/genre overlap
        let scored = others.map { user -> (UserProfile, Int) in
            var score = 0

            // Mutual connections (highest priority)
            let mutuals = connectionsManager.mutualCounts[user.id] ?? 0
            score += mutuals * 10

            // Profile completeness (0–5)
            score += user.completenessScore * 2

            // Genre overlap
            let sharedGenres = user.genres.filter { userGenres.contains($0.lowercased()) }.count
            score += sharedGenres * 2

            // Role overlap
            let sharedRoles = user.roles.filter { userRoles.contains($0.lowercased()) }.count
            score += sharedRoles * 2

            return (user, score)
        }

        let sorted = scored
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        let base = Array(sorted.prefix(20))
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.username.lowercased().contains(query)
            || $0.roles.contains { $0.lowercased().contains(query) }
            || $0.genres.contains { $0.lowercased().contains(query) }
        }
    }

    // Recent listings
    private var recentListings: [Listing] {
        let blocked = Set(authManager.blockedUsers)
        let base = Array(listingManager.listings.filter { !blocked.contains($0.sellerUID) }.prefix(10))
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter {
            $0.title.lowercased().contains(query)
            || $0.location.lowercased().contains(query)
            || $0.condition.rawValue.lowercased().contains(query)
        }
    }

    // Upcoming shows
    private var upcomingShows: [ShowFlyer] {
        let blocked = Set(authManager.blockedUsers)
        let base = listingManager.showFlyers
            .filter { !$0.isExpired && !blocked.contains($0.posterUID) }
            .sorted { ($0.eventDate ?? Date()) < ($1.eventDate ?? Date()) }

        guard !searchText.isEmpty else { return Array(base.prefix(10)) }
        let query = searchText.lowercased()
        return base.filter {
            $0.title.lowercased().contains(query)
            || ($0.venue?.lowercased().contains(query) ?? false)
            || $0.posterUsername.lowercased().contains(query)
        }
    }
    
    // Strict Match Count so that it doesn't lie
    private var strictMatchCount: Int {
        let blocked = Set(authManager.blockedUsers)
        let userRoles = Set(authManager.roles.map { $0.lowercased() })
        guard !userRoles.isEmpty else { return 0 }

        let eligible = listingManager.isoPosts
            .filter { !blocked.contains($0.posterUID) }

        let matches = eligible.filter { post in
            userRoles.contains { role in roleMatches(userRole: role, postRole: post.roleNeeded) }
        }
        return matches.count
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Error banner
                    if let error = listingManager.errorMessage {
                        Text(error)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(ThemeColor.red.opacity(0.85))
                    }

                    // Greeting
                    greetingSection

                    // MARK: - Top Gigs
                    topGigsSection

                    // MARK: - Discover Artists
                    discoverSection

                    // MARK: - Upcoming Shows
                    upcomingShowsSection

                    // MARK: - Recent Listings
                    recentListingsSection

                    Spacer().frame(height: 100)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("backline")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(-0.2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if authManager.isGuestMode {
                        EmptyView()
                    } else {
                        NavigationLink {
                            ConversationsView()
                        } label: {
                            let count = messagesManager.unreadCount(forUID: authManager.currentUser?.uid ?? "")
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 15))
                                .overlay(alignment: .topTrailing) {
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .frame(minWidth: 16, minHeight: 16)
                                            .background(ThemeColor.red)
                                            .clipShape(Capsule())
                                            .alignmentGuide(.top) { $0[.bottom] - 8 }
                                            .alignmentGuide(.trailing) { $0[.leading] + 8 }
                                    }
                                }
                                .accessibilityLabel(count > 0 ? "\(count) unread messages" : "Messages")
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
            .navigationDestination(for: ShowFlyer.self) { flyer in
                ShowFlyerDetailView(flyer: flyer)
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if let convId = activeChatConversationId,
                   let conv = activeChatConversation {
                    ChatView(conversationId: convId, conversation: conv)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search backline")
            .onSubmit(of: .search) { BLAnalytics.search(query: searchText) }
            .task {
                async let iso: () = listingManager.fetchIsoPosts()
                async let users: () = listingManager.fetchAllUsers()
                async let items: () = listingManager.fetchListings()
                async let flyers: () = listingManager.fetchShowFlyers()
                _ = await (iso, users, items, flyers)

                // Precompute mutual connection counts for discover sorting (skip for guests)
                if !authManager.isGuestMode, let uid = authManager.currentUser?.uid {
                    await connectionsManager.precomputeMutualCounts(currentUID: uid)
                }

                // Fetch profile photos for ISO posters
                let uids = Array(Set(listingManager.isoPosts.map(\.posterUID)))
                await listingManager.fetchProfilePhotos(for: uids)
            }
            .refreshable {
                async let iso: () = listingManager.fetchIsoPosts()
                async let users: () = listingManager.fetchAllUsers()
                async let items: () = listingManager.fetchListings()
                async let flyers: () = listingManager.fetchShowFlyers()
                _ = await (iso, users, items, flyers)
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if authManager.isGuestMode {
                Text("Welcome to Backline")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)

                Text("Browse gigs, artists, and gear.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                Text("For you, ")
                    .font(.system(size: 26, weight: .semibold))
                    .tracking(-0.5)
                + Text(authManager.username ?? "")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)

                HStack(spacing: 0) {
                    Text("\(strictMatchCount) gigs")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColor.green)
                        .fontWeight(.bold)
                    Text(" match your skills today.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Top Gigs Section

    private var topGigsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BroadcastSectionHeader(label: "Top gigs for you", trailing: "See all") { selectedTab = 1 }

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
                VStack(spacing: 0) {
                    ForEach(matchedGigs) { post in
                        NavigationLink(value: post) {
                            gigRow(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func isStrictMatch(_ post: ISOPost) -> Bool {
        let userRoles = Set(authManager.roles.map { $0.lowercased() })
        return !userRoles.isEmpty && userRoles.contains(post.roleNeeded.lowercased())
    }

    private func gigRow(_ post: ISOPost) -> some View {
        let matched = isStrictMatch(post)
        return HStack(alignment: .top, spacing: 14) {
            // Square avatar
            if let photoURL = listingManager.profilePhotos[post.posterUID],
               let url = URL(string: photoURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 56, height: 56)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(.systemGray3))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Handle + time
                HStack {
                    Text("@\(post.posterUsername)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Text(post.timeAgoString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }

                // Kicker
                HStack(spacing: 6) {
                    Text("LOOKING FOR")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(ThemeColor.cyan)
                }

                // Role
                Text(post.roleNeeded)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.1)
                    .lineLimit(1)

                // Meta: budget · genres
                HStack(spacing: 6) {
                    Text(post.budget)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(ThemeColor.green)
                        .tracking(-0.1)

                    if let genres = posterGenres(for: post.posterUID), !genres.isEmpty {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.4))
                        Text(genres)
                            .font(.system(size: 12).italic())
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ThemeColor.hairline)
                .frame(height: 1)
        }
        .overlay {
            if matched {
                Rectangle()
                    .strokeBorder(ThemeColor.green.opacity(0.5), lineWidth: 1)
            }
        }
    }

    // MARK: - Poster Genres

    private func posterGenres(for uid: String) -> String? {
        guard let user = listingManager.allUsers.first(where: { $0.id == uid }),
              !user.genres.isEmpty else { return nil }
        return user.genres.joined(separator: " · ")
    }

    // MARK: - Discover Artists Section

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BroadcastSectionHeader(label: "Artists near you", trailing: "See all") { selectedTab = 1 }

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
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(discoverUsers) { user in
                            NavigationLink(value: ProfileDestination(uid: user.id, username: user.username)) {
                                discoverCard(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func discoverCard(_ user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square profile photo
            if let urlString = user.profilePhotoURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 96, height: 96)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(Color(.systemGray3))
                    }
            }

            Text(user.username)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .padding(.top, 10)

            if let firstRole = user.roles.first {
                let colorIndex = abs(user.id.hashValue) % 3
                let tagColor = [ThemeColor.cyan, ThemeColor.yellow, ThemeColor.green][colorIndex]
                Text(firstRole)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(tagColor)
                    .lineLimit(1)
            }
        }
        .frame(width: 96, alignment: .topLeading)
    }

    // MARK: - Upcoming Shows Section

    private var upcomingShowsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BroadcastSectionHeader(label: "Upcoming shows", trailing: "See all") { selectedTab = 1 }

            if upcomingShows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No upcoming shows yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(upcomingShows) { flyer in
                            NavigationLink(value: flyer) {
                                upcomingShowCard(flyer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.top, 8)
    }

    private func upcomingShowCard(_ flyer: ShowFlyer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square flyer image
            if let url = URL(string: flyer.imageURL) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 96, height: 96)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(Color(.systemGray3))
                    }
            }

            Text(flyer.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            if let venue = flyer.venue, !venue.isEmpty {
                Text(venue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ThemeColor.cyan)
                    .lineLimit(1)
            }

            if let eventDate = flyer.eventDate {
                Text(eventDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(ThemeColor.yellow)
                    .lineLimit(1)
            }
        }
        .frame(width: 96, alignment: .topLeading)
    }

    // MARK: - Recent Listings Section

    private var recentListingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BroadcastSectionHeader(label: "Recent listings", trailing: "See all") { selectedTab = 3 }

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
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 14
                ) {
                    ForEach(recentListings.prefix(4)) { listing in
                        NavigationLink(value: listing) {
                            recentListingCard(listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func recentListingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square image
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray6))
                        }
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(Color(.systemGray4))
                            }
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    if let price = listing.price {
                        Text("$\(price, specifier: "%.0f")")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(ThemeColor.green)
                    }
                    if let rentPrice = listing.rentPrice, !rentPrice.isEmpty {
                        Text(rentPrice)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(ThemeColor.cyan)
                    }
                }

                HStack(spacing: 5) {
                    Text(listing.condition.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(listing.location)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
    }
}
