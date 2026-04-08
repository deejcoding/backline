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

    @Binding var searchText: String
    @State private var selectedRole: String?

    private static let allRoles = [
        "Guitar", "Vocals", "Keyboardist", "Synth", "Woodwinds",
        "Strings", "Brass", "Bass", "Drums", "Producing",
        "Rapper", "DJ", "Live Sound Engineering", "Mixing Engineer",
        "Mastering Engineer", "Recording Engineer", "Graphic Design"
    ]

    private var filteredUsers: [UserProfile] {
        var results = listingManager.allUsers

        // Exclude current user
        if let currentUID = authManager.currentUser?.uid {
            results = results.filter { $0.id != currentUID }
        }

        if let role = selectedRole {
            results = results.filter { $0.roles.contains(role) }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.username.lowercased().contains(query)
                || $0.roles.contains(where: { $0.lowercased().contains(query) })
            }
        }

        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Role filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    roleChip("All", role: nil)
                    ForEach(Self.allRoles, id: \.self) { role in
                        roleChip(role, role: role)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredUsers.isEmpty {
                Spacer()
                Image(systemName: "person.2")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No artists found")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                Text("Musicians on backline will appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
        .task {
            await listingManager.fetchAllUsers()
        }
    }

    // MARK: - Role Chip

    private func roleChip(_ title: String, role: String?) -> some View {
        Button {
            selectedRole = role
        } label: {
            Text(title)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedRole == role ? .white : .clear)
                .foregroundStyle(selectedRole == role ? .black : .primary)
                .overlay(
                    Capsule()
                        .stroke(selectedRole == role ? .white : .white.opacity(0.2), lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - User Card

    private func userCard(_ user: UserProfile) -> some View {
        VStack(spacing: 8) {
            // Profile photo
            if let urlString = user.profilePhotoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(.systemGray4))
            }

            // Username
            Text("@\(user.username)")
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            // Bio
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            // Roles
            if !user.roles.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(user.roles.prefix(3), id: \.self) { role in
                        Text(role)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
    }
}
