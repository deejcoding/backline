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

                    // Header: photo + username + score
                    profileHeaderSection

                    // Bio
                    if let bio = authManager.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    // Genres
                    if !authManager.genres.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(authManager.genres, id: \.self) { genre in
                                Text("#\(genre)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Instagram
                    if let handle = authManager.instagramHandle, !handle.isEmpty {
                        Link(destination: URL(string: "https://instagram.com/\(handle)") ?? URL(string: "https://instagram.com")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                Text("@\(handle)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Music Projects
                    musicProjectsSection
                    
                    //TODO: add visual projects section

                    // My Listings
                    myListingsSection

                    // My Services
                    myServicesSection

                    // My ISO Posts
                    myISOPostsSection

                    // Actions
                    VStack(spacing: 12) {
                        Button("Edit Profile") {
                            showEditProfile = true
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                        .padding(.horizontal)

                        Button("Sign Out") {
                            authManager.signOut()
                        }
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(Rectangle())
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
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
        VStack(spacing: 12) {
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
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(Color.accentColor)
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

            // Username
            if let username = authManager.username {
                Text("@\(username)")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            // Profile Score
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("\(authManager.profileScore) pts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.top, 8)
    }

    // MARK: - Music Projects

    private var musicProjectsSection: some View {
        //TODO: add support for Spotify embeds
        //TODO: add support for ninaprotocol embeds
        //TODO: add support for SoundCloud embeds
        VStack(alignment: .leading, spacing: 12) {
            Text("Music Projects")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            if authManager.musicProjects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No music projects yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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
            HStack(spacing: 12) {
                Image(systemName: project.platform.iconName)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(project.platform.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(Rectangle())
        }
    }

    // MARK: - My Listings

    private var myListingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Listings")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            if listingManager.userListings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "guitars")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No listings yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(width: 150, height: 110)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let price = listing.price {
                    Text("$\(price, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                HStack(spacing: 3) {
                    ForEach(listing.listingTypes, id: \.self) { type in
                        Text(type.rawValue)
                            .font(.system(size: 8, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
        }
        .frame(width: 150)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - My Services

    private var myServicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Services")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            if listingManager.userServiceListings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No services yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(listingManager.userServiceListings) { service in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(service.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(service.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(service.rate)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)

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
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - My ISO Posts

    private var myISOPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My ISO Posts")
                .font(.headline)
                .fontWeight(.bold)
                .padding(.horizontal)

            if listingManager.userIsoPosts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "megaphone")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No ISO posts yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(listingManager.userIsoPosts) { post in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(post.roleNeeded)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if post.isExpired {
                                        Text("Expired")
                                            .font(.system(size: 9, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.15))
                                            .foregroundStyle(.red)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(post.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(post.budget)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)

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
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }
}
