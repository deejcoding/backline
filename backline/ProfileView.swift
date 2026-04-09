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

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(MessagesManager.self) private var messagesManager
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header: photo + username + bio + instagram
                    profileHeaderSection

                    // Genres
                    genresSection

                    // Roles
                    rolesSection

                    // Featured Projects
                    musicProjectsSection
                    
                    //TODO: add visual projects section

                    // My Services
                    myServicesSection

                    // My ISO Posts
                    myISOPostsSection

                    // My Listings
                    myListingsSection

                    // Actions
                    actionsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ConversationsView()
                    } label: {
                        let count = messagesManager.unreadCount(forUID: authManager.currentUser?.uid ?? "")
                        Image(systemName: count > 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                            .overlay(alignment: .topTrailing) {
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(3)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                    }
                }
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
            .task {
                if let uid = authManager.currentUser?.uid {
                    await listingManager.fetchUserListings(uid: uid)
                    await listingManager.fetchUserServiceListings(uid: uid)
                    await listingManager.fetchUserIsoPosts(uid: uid)
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
            .alert("Delete ISO Post", isPresented: $showDeleteISOConfirmation) {
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

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Profile photo
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let urlString = authManager.profilePhotoURL,
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
                        .foregroundStyle(ThemeColor.blue)
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                        await authManager.uploadProfilePhoto(imageData: jpegData)
                    }
                }
            }

            // Username, bio, instagram
            VStack(alignment: .leading, spacing: 4) {
                if let username = authManager.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                if let bio = authManager.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let handle = authManager.instagramHandle, !handle.isEmpty {
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
        if !authManager.genres.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(Array(authManager.genres.enumerated()), id: \.element) { index, genre in
                    let color = ThemeColor.cycle(index)
                    Text("#\(genre)")
                        .font(.caption2)
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Roles

    @ViewBuilder
    private var rolesSection: some View {
        if !authManager.roles.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(Array(authManager.roles.enumerated()), id: \.element) { index, role in
                    let color = ThemeColor.cycle(index)
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button("Edit Profile") {
                showEditProfile = true
            }
            .font(.caption)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal)

            Button("Sign Out") {
                authManager.signOut()
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 40)
    }

    // MARK: - Featured Projects

    private var musicProjectsSection: some View {
        //TODO: add support for Spotify embeds
        //TODO: add support for ninaprotocol embeds
        //TODO: add support for SoundCloud embeds
        VStack(alignment: .leading, spacing: 10) {
            Text("Featured Projects")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if authManager.musicProjects.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No featured projects yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(authManager.musicProjects) { project in
                        musicProjectRow(project)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func musicProjectRow(_ project: MusicProject) -> some View {
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

    // MARK: - My Listings

    private var myListingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My Listings")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

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

                HStack(spacing: 3) {
                    ForEach(Array(listing.listingTypes.enumerated()), id: \.element) { index, type in
                        let color = ThemeColor.cycle(index)
                        Text(type.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                    }
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

    // MARK: - My Services

    private var myServicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My Services")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

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
                VStack(spacing: 8) {
                    ForEach(listingManager.userServiceListings) { service in
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

                            Menu {
                                Button {
                                    serviceToEdit = service
                                    showEditService = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    serviceToDelete = service
                                    showDeleteServiceConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - My ISO Posts

    private var myISOPostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My ISO Posts")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if listingManager.userIsoPosts.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "megaphone")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                    Text("No ISO posts yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(listingManager.userIsoPosts) { post in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(post.roleNeeded)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if post.isExpired {
                                        Text("Expired")
                                            .font(.system(size: 8))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.red.opacity(0.4), lineWidth: 0.5)
                                            )
                                            .foregroundStyle(.red)
                                    }
                                }
                                Text(post.category.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(post.budget)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Menu {
                                Button {
                                    isoToEdit = post
                                    showEditISO = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    isoToDelete = post
                                    showDeleteISOConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }
}
