//
//  ProfileView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct ProfileView: View {

    @Binding var navigationPath: NavigationPath

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ConnectionsManager.self) private var connectionsManager
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showEditProfile = false
    @State private var showDeleteListingConfirmation = false
    @State private var showDeleteServiceConfirmation = false
    @State private var listingToDelete: Listing?
    @State private var serviceToDelete: ServiceListing?
    @State private var serviceToEdit: ServiceListing?
    @State private var showEditService = false
    @State private var showDeleteISOConfirmation = false
    @State private var isoToDelete: ISOPost?
    @State private var isoToEdit: ISOPost?
    @State private var showEditISO = false
    @State private var showDeleteFlyerConfirmation = false
    @State private var flyerToDelete: ShowFlyer?

    @State private var showCopiedFeedback = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 20) {

                    // Header: photo + username + bio + instagram
                    profileHeaderSection

                    // Profile completeness bar (hidden at 100%)
                    profileCompletenessSection

                    // Connections count
                    connectionsRow

                    // Referral Section
                    referralSection

                    // Genres
                    genresSection

                    // Roles
                    rolesSection

                    // Music
                    musicSection

                    // My Services
                    myServicesSection

                    // My Show Flyers
                    myShowFlyersSection

                    // My ISO Posts
                    myISOPostsSection

                    // My Listings
                    myListingsSection

                    // Actions
                    actionsSection

                    Spacer().frame(height: 80)
                }
                .padding(.vertical)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("backline")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(-0.2)
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ChatDestination.self) { dest in
                ChatView(conversationId: dest.conversationId, conversation: dest.conversation)
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
            .navigationDestination(for: ISOPost.self) { post in
                ISOPostDetailView(post: post)
            }
            .navigationDestination(for: ShowFlyer.self) { flyer in
                ShowFlyerDetailView(flyer: flyer)
            }
            .task {
                if let uid = authManager.currentUser?.uid {
                    await listingManager.fetchUserListings(uid: uid)
                    await listingManager.fetchUserServiceListings(uid: uid)
                    await listingManager.fetchUserIsoPosts(uid: uid)
                    await listingManager.fetchUserShowFlyers(uid: uid)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showEditService) {
                if let service = serviceToEdit {
                    EditServiceListingView(service: service)
                }
            }
            .alert("Delete Listing", isPresented: $showDeleteListingConfirmation) {
                Button("Delete", role: .destructive) {
                    if let listing = listingToDelete {
                        Task { await listingManager.deleteListing(id: listing.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this listing? This cannot be undone.")
            }
            .sheet(isPresented: $showEditISO) {
                if let post = isoToEdit {
                    EditISOPostView(post: post)
                }
            }
            .alert("Delete Service", isPresented: $showDeleteServiceConfirmation) {
                Button("Delete", role: .destructive) {
                    if let service = serviceToDelete {
                        Task { await listingManager.deleteServiceListing(id: service.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this service? This cannot be undone.")
            }
            .alert("Delete Flyer", isPresented: $showDeleteFlyerConfirmation) {
                Button("Delete", role: .destructive) {
                    if let flyer = flyerToDelete {
                        Task { await listingManager.deleteShowFlyer(id: flyer.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this flyer? This cannot be undone.")
            }
            .alert("Delete Open Role", isPresented: $showDeleteISOConfirmation) {
                Button("Delete", role: .destructive) {
                    if let post = isoToDelete {
                        Task { await listingManager.deleteISOPost(id: post.id) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this post? This cannot be undone.")
            }

        }
    }

    // MARK: - Profile Completeness

    @ViewBuilder
    private var profileCompletenessSection: some View {
        let score = authManager.profileCompleteness
        if score < 100 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PROFILE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("\(score)%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(score >= 80 ? ThemeColor.green : score >= 50 ? ThemeColor.yellow : ThemeColor.red)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 4)
                        Rectangle()
                            .fill(score >= 80 ? ThemeColor.green : score >= 50 ? ThemeColor.yellow : ThemeColor.red)
                            .frame(width: geo.size.width * CGFloat(score) / 100, height: 4)
                    }
                }
                .frame(height: 4)

                // Missing items hint
                let missing = missingProfileItems
                if !missing.isEmpty {
                    Text("Add \(missing.joined(separator: ", ")) to complete")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var missingProfileItems: [String] {
        var items: [String] = []
        if authManager.profilePhotoURL == nil { items.append("photo") }
        if authManager.bio == nil || (authManager.bio ?? "").isEmpty { items.append("bio") }
        if authManager.musicProjects.isEmpty && authManager.featuredProjects.isEmpty { items.append("portfolio") }
        if authManager.roles.isEmpty { items.append("skills") }
        if authManager.genres.isEmpty { items.append("genres") }
        return items
    }

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // Square profile photo
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        if let urlString = authManager.profilePhotoURL,
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

                        // Camera badge
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(ThemeColor.cyan)
                            .overlay(
                                Rectangle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let newItem else { return }
                    Task.detached(priority: .userInitiated) {
                        guard let data = try? await newItem.loadTransferable(type: Data.self),
                              let uiImage = UIImage(data: data) else { return }
                        let maxDimension: CGFloat = 800
                        let downsized: UIImage = {
                            let size = uiImage.size
                            if max(size.width, size.height) <= maxDimension { return uiImage }
                            let ratio = maxDimension / max(size.width, size.height)
                            let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)
                            return uiImage.preparingThumbnail(of: targetSize) ?? uiImage
                        }()
                        if let jpegData = downsized.jpegData(compressionQuality: 0.8) {
                            await authManager.uploadProfilePhoto(imageData: jpegData)
                        }
                        await MainActor.run {
                            selectedPhoto = nil
                        }
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let displayName = authManager.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                            .lineLimit(1)
                    }

                    if let username = authManager.username {
                        Text("@\(username)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    if !authManager.roles.isEmpty {
                        HStack(spacing: 5) {
                            Text(authManager.roles.first ?? "")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(ThemeColor.cyan)
                        }
                    }

                    if let handle = authManager.instagramHandle, !handle.isEmpty {
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
            if let bio = authManager.bio, !bio.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Text("● ")
                        .foregroundStyle(ThemeColor.green)
                    Text(bio)
                }
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Stat Strip + Connections

    private var connectionsRow: some View {
        VStack(spacing: 0) {
            // Stat strip
            HStack(spacing: 0) {
                NavigationLink {
                    ConnectionsListView()
                } label: {
                    statCell(num: "\(connectionsManager.connections.count)", unit: "CONNECTED", color: ThemeColor.green)
                }
                .buttonStyle(.plain)
                NavigationLink {
                    ConnectionRequestsView()
                } label: {
                    statCell(
                        num: "\(connectionsManager.incomingRequests.count)",
                        unit: "REQUESTS",
                        color: ThemeColor.yellow
                    )
                }
                .buttonStyle(.plain)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(ThemeColor.hairline).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(ThemeColor.hairline).frame(height: 1)
            }

            // Action row
            HStack(spacing: 0) {
                Button {
                    showEditProfile = true
                } label: {
                    Text("Edit profile")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 1)
                        }
                }

                /*NavigationLink {
                    ConnectionsListView()
                } label: {
                    Text("Connections")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } */
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(ThemeColor.hairline).frame(height: 1)
            }
        }
    }

    private func statCell(num: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(num)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(-0.3)
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    // MARK: - Referral Section

    @ViewBuilder
    private var referralSection: some View {
        if let code = authManager.referralCode {
            Button {
                UIPasteboard.general.string = "Join me on Backline! Use my referral code: \(code)"
                withAnimation {
                    showCopiedFeedback = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showCopiedFeedback = false
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16))
                        .foregroundStyle(ThemeColor.cyan)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REFER A FRIEND")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text(showCopiedFeedback ? "COPIED TO CLIPBOARD!" : "Your code: \(code)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(showCopiedFeedback ? ThemeColor.green : .white)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "square.on.square")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.05))
                .overlay(
                    Rectangle()
                        .stroke(ThemeColor.cyan.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: - Genres

    @ViewBuilder
    private var genresSection: some View {
        if !authManager.genres.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(authManager.genres, id: \.self) { genre in
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
        if !authManager.roles.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(authManager.roles, id: \.self) { role in
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

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsView()
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                    Text("Settings")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(0.4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 40)
    }

    // MARK: - Portfolio

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Portfolio")

            if authManager.featuredProjects.isEmpty && authManager.musicProjects.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No portfolio items yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(authManager.featuredProjects) { project in
                        FeaturedSongCard(song: project)
                    }

                    ForEach(authManager.musicProjects) { project in
                        musicLinkRow(project)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func musicLinkRow(_ project: MusicProject) -> some View {
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

    // MARK: - My Listings

    private var myListingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Your listings")

            if listingManager.userListings.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "guitars")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No listings yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(listingManager.userListings) { listing in
                            NavigationLink {
                                ListingDetailView(listing: listing)
                            } label: {
                                userListingCard(listing)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    listingToDelete = listing
                                    showDeleteListingConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
    }

    private func userListingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear
                .frame(width: 140, height: 100)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
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

    // MARK: - My Services

    private var myServicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Your services")

            if listingManager.userServiceListings.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No services yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(listingManager.userServiceListings) { service in
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
                        .contextMenu {
                            Button(role: .destructive) {
                                serviceToDelete = service
                                showDeleteServiceConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - My Show Flyers

    private var myShowFlyersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Your show flyers")

            if listingManager.userShowFlyers.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No flyers yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(listingManager.userShowFlyers) { flyer in
                            NavigationLink(value: flyer) {
                                userFlyerCard(flyer)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    flyerToDelete = flyer
                                    showDeleteFlyerConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 8)
    }

    private func userFlyerCard(_ flyer: ShowFlyer) -> some View {
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

            VStack(alignment: .leading, spacing: 2) {
                Text(flyer.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                if let venue = flyer.venue, !venue.isEmpty {
                    Text(venue)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ThemeColor.cyan)
                        .lineLimit(1)
                }

                if flyer.isExpired {
                    Text("EXPIRED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(ThemeColor.red)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .overlay(
                            Rectangle()
                                .stroke(ThemeColor.red.opacity(0.3), lineWidth: 1)
                        )
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

    // MARK: - My ISO Posts

    private var myISOPostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BroadcastSectionHeader(label: "Your open role posts")

            if listingManager.userIsoPosts.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "megaphone")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No open roles yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(listingManager.userIsoPosts) { post in
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
                                Text(post.budget)
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
                        .contextMenu {
                            Button(role: .destructive) {
                                isoToDelete = post
                                showDeleteISOConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Settings View
private struct SettingsView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @State private var showDeleteAccountConfirmation = false
    @State private var showDeleteAccountFinalConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Blocked Users
                settingsRow(icon: "person.slash", label: "Blocked Users") {
                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        settingsRowContent(icon: "person.slash", label: "Blocked Users")
                    }
                }

                // Messaging Privacy
                messagingPrivacyRow

                // Terms of Service
                settingsRow(icon: "doc.text", label: "Terms of Service") {
                    Link(destination: URL(string: "https://backlinenyc.com/terms.html") ?? URL(string: "https://backlinenyc.com")!) {
                        settingsRowContent(icon: "doc.text", label: "Terms of Service")
                    }
                }

                // Privacy Policy
                settingsRow(icon: "lock.shield", label: "Privacy Policy") {
                    Link(destination: URL(string: "https://backlinenyc.com/privacy.html") ?? URL(string: "https://backlinenyc.com")!) {
                        settingsRowContent(icon: "lock.shield", label: "Privacy Policy")
                    }
                }

                // Support
                settingsRow(icon: "questionmark.circle", label: "Support") {
                    Link(destination: URL(string: "mailto:deej@backlinenyc.com") ?? URL(string: "https://backlinenyc.com")!) {
                        settingsRowContent(icon: "questionmark.circle", label: "Support")
                    }
                }

                Spacer().frame(height: 32)

                // Sign Out
                Button {
                    authManager.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12))
                        Text("Sign Out")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .tracking(0.4)
                        Spacer()
                    }
                    .foregroundStyle(ThemeColor.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) {
                        Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                    }
                }

                // Delete Account
                Button {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("Delete Account")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .tracking(0.4)
                        Spacer()
                    }
                    .foregroundStyle(ThemeColor.red.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(ThemeColor.hairline).frame(height: 1)
                    }
                }

                Spacer().frame(height: 100)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
            Button("Delete My Account", role: .destructive) {
                showDeleteAccountFinalConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, all your listings, posts, messages, and connections. This cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showDeleteAccountFinalConfirmation) {
            Button("Yes, Delete Everything", role: .destructive) {
                isDeletingAccount = true
                Task {
                    do {
                        try await authManager.deleteAccount()
                    } catch {
                        isDeletingAccount = false
                        deleteAccountError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your account and all data will be permanently erased. There is no way to recover it.")
        }
        .alert("Error Deleting Account", isPresented: .init(
            get: { deleteAccountError != nil },
            set: { if !$0 { deleteAccountError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountError ?? "")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("DELETING ACCOUNT...")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var messagingPrivacyRow: some View {
        HStack {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 12))
            Text("Messages From")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(0.4)
            Spacer()
            Picker("", selection: Binding(
                get: { authManager.allowMessagesFrom },
                set: { newValue in
                    Task {
                        await authManager.updateMessagingPrivacy(newValue)
                        BLAnalytics.updateMessagingPrivacy(setting: newValue)
                    }
                }
            )) {
                Text("Anyone").tag("anyone")
                Text("Connections Only").tag("connections")
            }
            .pickerStyle(.menu)
            .tint(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
    }

    // Generic row content (reused across NavigationLink / Link / Button)
    private func settingsRowContent(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .tracking(0.4)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ThemeColor.hairline).frame(height: 1)
        }
    }

    // Wrapper that applies the top border only on the first row
    @ViewBuilder
    private func settingsRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        content()
    }
}


