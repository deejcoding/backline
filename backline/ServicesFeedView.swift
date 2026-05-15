//
//  ServicesFeedView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI
import FirebaseAuth

struct ServicesFeedView: View {

    @Environment(ListingManager.self) private var listingManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ConnectionsManager.self) private var connectionsManager

    @Binding var searchText: String
    @State private var selectedRole: String?
    @State private var selectedGenre: String?

    private static let allRoles = [
        "Guitar", "Vocals", "Keyboardist", "Synth", "Woodwinds",
        "Strings", "Brass", "Bass", "Drums", "Producing",
        "Rapper", "DJ", "Live Sound Engineering", "Mixing Engineer",
        "Mastering Engineer", "Recording Engineer", "Graphic Design"
    ]

    private var availableGenres: [String] {
        let currentUID = authManager.currentUser?.uid ?? ""
        let blocked = Set(authManager.blockedUsers)
        let allGenres = listingManager.allUsers
            .filter { $0.id != currentUID && !blocked.contains($0.id) }
            .flatMap { $0.genres }
        return Array(Set(allGenres.map { $0.lowercased() })).sorted()
    }

    private var filteredUsers: [UserProfile] {
        let blocked = Set(authManager.blockedUsers)
        var results = listingManager.allUsers

        // Exclude current user and blocked users
        if let currentUID = authManager.currentUser?.uid {
            results = results.filter { $0.id != currentUID && !blocked.contains($0.id) }
        } else {
            results = results.filter { !blocked.contains($0.id) }
        }

        if let role = selectedRole {
            results = results.filter { $0.roles.contains(role) }
        }

        if let genre = selectedGenre {
            results = results.filter { user in
                user.genres.contains(where: { $0.lowercased() == genre })
            }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.username.lowercased().contains(query)
                || ($0.displayName?.lowercased().contains(query) ?? false)
                || $0.roles.contains(where: { $0.lowercased().contains(query) })
                || $0.genres.contains(where: { $0.lowercased().contains(query) })
            }
        }

        // Sort: mutual connections first, then profile completeness
        return results.sorted { a, b in
            let aMutuals = connectionsManager.mutualCounts[a.id] ?? 0
            let bMutuals = connectionsManager.mutualCounts[b.id] ?? 0
            if aMutuals != bMutuals { return aMutuals > bMutuals }
            return a.completenessScore > b.completenessScore
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Role filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    roleChip("All", role: nil)
                    ForEach(Self.allRoles, id: \.self) { role in
                        roleChip(role, role: role)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Genre filter
            if !availableGenres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        genreChip("All Genres", genre: nil)
                        ForEach(availableGenres, id: \.self) { genre in
                            genreChip(genre, genre: genre)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }

            if filteredUsers.isEmpty {
                Spacer()
                Text("NO ARTISTS FOUND")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.45))
                Text("Musicians on backline will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 4)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredUsers) { user in
                            NavigationLink(value: ProfileDestination(uid: user.id, username: user.username)) {
                                userCard(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await listingManager.fetchAllUsers()
                }
            }
        }
        .task {
            await listingManager.fetchAllUsers()
            if let uid = authManager.currentUser?.uid {
                await connectionsManager.precomputeMutualCounts(currentUID: uid)
            }
        }
    }

    // MARK: - Role Chip

    private func roleChip(_ title: String, role: String?) -> some View {
        BroadcastChip(
            title: title,
            isSelected: selectedRole == role,
            action: { selectedRole = role }
        )
    }

    // MARK: - Genre Chip

    private func genreChip(_ title: String, genre: String?) -> some View {
        Button {
            selectedGenre = genre
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedGenre == genre ? ThemeColor.cyan : .clear)
                .foregroundStyle(selectedGenre == genre ? Color(hex: 0x0A0A0A) : .white.opacity(0.7))
                .overlay(
                    Rectangle()
                        .stroke(selectedGenre == genre ? ThemeColor.cyan : .white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - User Card

    private func userCard(_ user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square profile photo
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let urlString = user.profilePhotoURL, let url = URL(string: urlString) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color(.systemGray3))
                            }
                    }
                }
                .clipped()

            // Info area
            VStack(alignment: .leading, spacing: 3) {
                // Username
                Text("@\(user.username)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                // Roles
                if !user.roles.isEmpty {
                    Text(user.roles.prefix(2).joined(separator: " · "))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.2)
                        .foregroundStyle(ThemeColor.cyan)
                        .lineLimit(1)
                }

                // Genres
                if !user.genres.isEmpty {
                    Text(user.genres.prefix(3).joined(separator: " · "))
                        .font(.system(size: 10).italic())
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .overlay(
            Rectangle()
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}
