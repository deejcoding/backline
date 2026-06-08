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
    @Environment(ConnectionsManager.self) private var connectionsManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    let uid: String
    let username: String

    @State private var profilePhotoURL: String?
    @State private var displayName: String?
    @State private var bio: String?
    @State private var instagramHandle: String?
    @State private var musicProjects: [MusicProject] = []
    @State private var featuredProjects: [SpotifyTrack] = []
    @State private var genres: [String] = []
    @State private var roles: [String] = []
    @State private var neighborhood: String?
    @State private var userListings: [Listing] = []
    @State private var userServices: [ServiceListing] = []
    @State private var userIsoPosts: [ISOPost] = []
    @State private var userFlyers: [ShowFlyer] = []
    @State private var isLoadingProfile = true

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?
    @State private var showBlockConfirmation = false
    @State private var showReportSheet = false
    @State private var showDisconnectConfirmation = false
    @State private var mutualConnections: [UserProfile] = []
    @State private var targetAllowMessagesFrom: String = "anyone"
    @State private var showGuestPrompt = false

    private let db = Firestore.firestore()

    private var isOwnProfile: Bool {
        uid == authManager.currentUser?.uid
    }

    var body: some View {
        Group {
            if !isOwnProfile && authManager.isBlocked(uid) {
                // Blocked state
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("YOU'VE BLOCKED @\(username.uppercased())")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))
                    Button {
                        Task { await authManager.unblockUser(uid) }
                    } label: {
                        Text("Unblock")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(0.4)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .overlay(
                                Rectangle()
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            )
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if isLoadingProfile {
                        ProgressView()
                            .padding(.top, 60)
                    } else {
                        VStack(spacing: 0) {

                            // Header: photo + username + bio + instagram
                            profileHeaderSection

                            // Connection action strip (connect/message)
                            if !isOwnProfile && !authManager.isBlocked(uid) {
                                if authManager.isGuestMode {
                                    guestActionStrip
                                } else if authManager.canInteract {
                                    connectionActionStrip
                                } else {
                                    incompleteProfileBanner
                                }
                            }

                            // Mutual connections
                            if !isOwnProfile && !mutualConnections.isEmpty {
                                mutualConnectionsRow
                            }

                            // Genres
                            genresSection

                            // Roles
                            rolesSection

                            // Music
                            if !featuredProjects.isEmpty || !musicProjects.isEmpty {
                                musicSection
                            }

                            // Show Flyers (upcoming + past)
                            if !userFlyers.isEmpty {
                                showFlyersSection
                            }

                            // Services
                            if !userServices.isEmpty {
                                servicesSection
                            }

                            // ISO Posts
                            if !userIsoPosts.isEmpty {
                                isoPostsSection
                            }

                            // Listings
                            if !userListings.isEmpty {
                                listingsSection
                            }

                            Spacer().frame(height: 100)
                        }
                    }
                }
            }
        }
        .navigationTitle("@\(username)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: URL(string: "backline://profile/\(uid)/\(username)")!,
                    subject: Text("@\(username)"),
                    message: Text("Check out @\(username) on Backline")
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                }
            }
            if !isOwnProfile && !authManager.isGuestMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label("Report User", systemImage: "exclamationmark.triangle")
                        }

                        if case .connected = connectionsManager.connectionStatus(with: uid) {
                            Button(role: .destructive) {
                                showDisconnectConfirmation = true
                            } label: {
                                Label("Disconnect", systemImage: "person.badge.minus")
                            }
                        }

                        if authManager.isBlocked(uid) {
                            Button {
                                Task { await authManager.unblockUser(uid) }
                            } label: {
                                Label("Unblock User", systemImage: "hand.raised.slash")
                            }
                        } else {
                            Button(role: .destructive) {
                                showBlockConfirmation = true
                            } label: {
                                Label("Block User", systemImage: "hand.raised")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                }
            }
        }
        .alert("Block @\(username)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) {
                Task {
                    await connectionsManager.removeAllBetween(currentUID: authManager.currentUser?.uid ?? "", otherUID: uid)
                    await authManager.blockUser(uid)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to message you, and their content will be hidden from your feeds.")
        }
        .alert("Disconnect from @\(username)?", isPresented: $showDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) {
                if case .connected(let conn) = connectionsManager.connectionStatus(with: uid) {
                    Task { await connectionsManager.removeConnection(conn.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer be connected. You can send a new request later.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportView(contentType: "user", contentId: uid, reportedUID: uid)
        }
        .sheet(isPresented: $showGuestPrompt) {
            GuestPromptView()
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
        .task {
            BLAnalytics.viewProfile(uid: uid)
            if !isOwnProfile {
                listingManager.recordProfileView(viewedUID: uid, viewerUID: authManager.currentUser?.uid)
            }
            await loadProfile()
        }
    }

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // Square profile photo
                if let urlString = profilePhotoURL,
                   let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .frame(width: 88, height: 88)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 88, height: 88)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(Color(.systemGray3))
                        }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                            .lineLimit(1)
                    }

                    if !roles.isEmpty {
                        Text(roles.first ?? "")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(ThemeColor.cyan)
                    }

                    if let neighborhood, !neighborhood.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9))
                            Text(neighborhood)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.55))
                    }

                    if let handle = instagramHandle, !handle.isEmpty {
                        Link(destination: URL(string: "https://instagram.com/\(handle)") ?? URL(string: "https://instagram.com")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 9))
                                Text("@\(handle)")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // Bio
            if let bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Connection Action Strip

    private var canMessage: Bool {
        if targetAllowMessagesFrom == "anyone" { return true }
        if case .connected = connectionsManager.connectionStatus(with: uid) { return true }
        if targetAllowMessagesFrom == "mutuals" && !mutualConnections.isEmpty { return true }
        return false
    }

    @ViewBuilder
    private var connectionActionStrip: some View {
        let _ = connectionsManager.connections
        let _ = connectionsManager.outgoingRequests
        let _ = connectionsManager.incomingRequests
        let status = connectionsManager.connectionStatus(with: uid)

        HStack(spacing: 0) {
            switch status {
            case .none:
                Button {
                    Task {
                        guard let currentUID = authManager.currentUser?.uid,
                              let currentUsername = authManager.username else { return }
                        await connectionsManager.sendRequest(
                            fromUID: currentUID,
                            fromUsername: currentUsername,
                            toUID: uid,
                            toUsername: username
                        )
                    }
                } label: {
                    Text("Connect")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .opacity(networkMonitor.isConnected ? 1 : 0.4)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                }
                .disabled(!networkMonitor.isConnected)

            case .pendingOutgoing(let request):
                Button {
                    Task { await connectionsManager.withdrawRequest(request.id) }
                } label: {
                    Text("Pending")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                }

            case .pendingIncoming(let request):
                Button {
                    Task { await connectionsManager.acceptRequest(request.id) }
                } label: {
                    Text("Accept")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ThemeColor.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                }
                Button {
                    Task { await connectionsManager.rejectRequest(request.id) }
                } label: {
                    Text("Decline")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                }

            case .connected:
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ThemeColor.green)
                    Text("Connected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                }
            }

            // Message button — shown for all statuses, respects privacy setting
            if canMessage {
                Button {
                    Task { await messageUserTapped() }
                } label: {
                    Text("Message")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .help("This user only accepts messages from connections")
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
    }

    // MARK: - Incomplete Profile Banner

    private var incompleteProfileBanner: some View {
        VStack(spacing: 6) {
            Text("COMPLETE YOUR PROFILE TO CONNECT & MESSAGE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(ThemeColor.red)
            Text("\(authManager.profileCompleteness)% complete — 80% required")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
    }

    // MARK: - Guest Action Strip

    private var guestActionStrip: some View {
        HStack(spacing: 0) {
            Button {
                showGuestPrompt = true
            } label: {
                Text("Connect")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1)
                    }
            }

            Button {
                showGuestPrompt = true
            } label: {
                Text("Message")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
    }

    // MARK: - Mutual Connections Row

    private var mutualConnectionsRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: -6) {
                ForEach(Array(mutualConnections.prefix(3)), id: \.id) { user in
                    if let urlString = user.profilePhotoURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(width: 22, height: 22)
                        .clipped()
                        .overlay(Rectangle().stroke(Color(hex: 0x0A0A0A), lineWidth: 1.5))
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 22, height: 22)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color(.systemGray3))
                            }
                            .overlay(Rectangle().stroke(Color(hex: 0x0A0A0A), lineWidth: 1.5))
                    }
                }
            }

            let names = mutualConnections.prefix(2).map { "@\($0.username)" }
            let remaining = mutualConnections.count - names.count
            let text = remaining > 0
                ? "\(names.joined(separator: ", ")) and \(remaining) more mutual connection\(remaining == 1 ? "" : "s")"
                : "\(names.joined(separator: " and ")) — mutual connection\(mutualConnections.count == 1 ? "" : "s")"

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Genres

    @ViewBuilder
    private var genresSection: some View {
        if !genres.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(genres, id: \.self) { genre in
                    Text("#\(genre)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeColor.cyan)
                        .tracking(0.4)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .overlay(
                            Rectangle()
                                .stroke(ThemeColor.cyan.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Roles

    @ViewBuilder
    private var rolesSection: some View {
        if !roles.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeColor.yellow)
                        .tracking(0.4)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .overlay(
                            Rectangle()
                                .stroke(ThemeColor.yellow.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: - Portfolio

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Portfolio")

            VStack(spacing: 10) {
                ForEach(featuredProjects) { project in
                    FeaturedSongCard(song: project)
                }

                ForEach(musicProjects) { project in
                    Link(destination: URL(string: project.url) ?? URL(string: "https://example.com")!) {
                        HStack(spacing: 10) {
                            if let thumb = project.thumbnailURL, let url = URL(string: thumb) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color(.systemGray5))
                                }
                                .frame(width: 48, height: 48)
                                .clipped()
                            } else {
                                Image(systemName: project.platform.iconName)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .frame(width: 48, height: 48)
                                    .background(Color(.systemGray6))
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(project.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(project.platform.rawValue)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(10)
                        .overlay(
                            Rectangle()
                                .stroke(.white.opacity(0.14), lineWidth: 1)
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
            BroadcastSectionHeader(label: "Listings")

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
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray6))
                        }
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.caption)
                                    .foregroundStyle(Color(.systemGray4))
                            }
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                if let price = listing.price {
                    Text("$\(price, specifier: "%.0f")")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(ThemeColor.green)
                }

                HStack(spacing: 3) {
                    ForEach(Array(listing.listingTypes.enumerated()), id: \.element) { index, type in
                        let color = ThemeColor.cycle(index)
                        Text(type.rawValue)
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .overlay(
                                Rectangle()
                                    .stroke(color.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 140)
        .overlay(
            Rectangle()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .clipped()
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BroadcastSectionHeader(label: "Services")

            VStack(spacing: 0) {
                ForEach(userServices) { service in
                    NavigationLink(value: service) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.title)
                                    .font(.system(size: 13, weight: .medium))
                                Text(service.category.rawValue)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(ThemeColor.yellow)
                            }
                            Spacer()
                            Text(service.rate)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(ThemeColor.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - ISO Posts

    private var isoPostsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            BroadcastSectionHeader(label: "Open Roles")

            VStack(spacing: 0) {
                ForEach(userIsoPosts) { post in
                    NavigationLink(value: post) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.roleNeeded)
                                    .font(.system(size: 13, weight: .medium))
                                Text(post.category.rawValue)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Text(post.budget ?? "")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(ThemeColor.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
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
            displayName = data?["displayName"] as? String
            bio = data?["bio"] as? String
            instagramHandle = data?["instagramHandle"] as? String
            genres = data?["genres"] as? [String] ?? []
            roles = data?["roles"] as? [String] ?? []
            neighborhood = data?["neighborhood"] as? String
            targetAllowMessagesFrom = data?["allowMessagesFrom"] as? String ?? "anyone"

            if let projectDicts = data?["musicProjects"] as? [[String: String]] {
                musicProjects = projectDicts.compactMap { dict in
                    guard let id = dict["id"],
                          let title = dict["title"],
                          let url = dict["url"],
                          let platformRaw = dict["platform"],
                          let platform = MusicPlatform(rawValue: platformRaw)
                    else { return nil }
                    return MusicProject(id: id, title: title, url: url, platform: platform, thumbnailURL: dict["thumbnailURL"])
                }
            }

            if let projectDictsRaw = data?["featuredProjects"] as? [[String: String]] {
                featuredProjects = projectDictsRaw.compactMap { dict in
                    guard let id = dict["id"],
                          let name = dict["name"],
                          let artistName = dict["artistName"],
                          let albumName = dict["albumName"],
                          let externalURL = dict["externalURL"]
                    else { return nil }
                    let itemTypeRaw = dict["itemType"] ?? "track"
                    let itemType = SpotifyItemType(rawValue: itemTypeRaw) ?? .track
                    return SpotifyTrack(
                        id: id, name: name, artistName: artistName,
                        albumName: albumName,
                        albumImageURL: dict["albumImageURL"],
                        previewURL: dict["previewURL"],
                        externalURL: externalURL,
                        itemType: itemType
                    )
                }
            } else if let songDict = data?["featuredSong"] as? [String: String],
                      let id = songDict["id"],
                      let name = songDict["name"],
                      let artistName = songDict["artistName"],
                      let albumName = songDict["albumName"],
                      let externalURL = songDict["externalURL"] {
                // Migration: read old single featuredSong format
                featuredProjects = [SpotifyTrack(
                    id: id, name: name, artistName: artistName,
                    albumName: albumName,
                    albumImageURL: songDict["albumImageURL"],
                    previewURL: songDict["previewURL"],
                    externalURL: externalURL
                )]
            }
        } catch {
            // Profile fetch failed
        }

        // Fetch listings, services, ISO posts, and flyers in parallel
        async let fetchedListings = fetchListings()
        async let fetchedServices = fetchServices()
        async let fetchedISOs = fetchISOs()
        async let fetchedFlyers = fetchFlyers()

        userListings = await fetchedListings
        userServices = await fetchedServices
        userIsoPosts = await fetchedISOs
        userFlyers = await fetchedFlyers

        // Fetch mutual connections (for non-own profiles)
        if !isOwnProfile, let currentUID = authManager.currentUser?.uid {
            mutualConnections = await connectionsManager.fetchMutualConnections(
                currentUID: currentUID,
                targetUID: uid,
                allUsers: listingManager.allUsers
            )
        }

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
            return []
        }
    }

    // MARK: - Show Flyers

    private var showFlyersSection: some View {
        let upcoming = userFlyers.filter { !$0.isExpired }.sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }
        let past = userFlyers.filter { $0.isExpired }.sorted { ($0.eventDate ?? .distantPast) > ($1.eventDate ?? .distantPast) }

        return VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Shows")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(upcoming + past) { flyer in
                        NavigationLink(value: flyer) {
                            publicFlyerCard(flyer, isPast: flyer.isExpired)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func publicFlyerCard(_ flyer: ShowFlyer, isPast: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(width: 120, height: 160)
                .overlay {
                    if let url = URL(string: flyer.imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipped()
                .opacity(isPast ? 0.6 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(flyer.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                if let venue = flyer.venue, !venue.isEmpty {
                    Text(venue)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ThemeColor.cyan)
                        .lineLimit(1)
                }

                if isPast {
                    Text("PAST")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 120)
        .overlay(
            Rectangle()
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .clipped()
    }

    private func fetchFlyers() async -> [ShowFlyer] {
        do {
            let snapshot = try await db.collection("showFlyers")
                .whereField("posterUID", isEqualTo: uid)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let imageURL = data["imageURL"] as? String,
                      let title = data["title"] as? String,
                      let posterUID = data["posterUID"] as? String,
                      let posterUsername = data["posterUsername"] as? String
                else { return nil }

                let venue = data["venue"] as? String
                let eventDate = (data["eventDate"] as? Timestamp)?.dateValue()
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return ShowFlyer(
                    id: doc.documentID,
                    imageURL: imageURL,
                    title: title,
                    venue: venue,
                    eventDate: eventDate,
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
