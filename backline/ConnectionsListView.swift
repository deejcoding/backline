//
//  ConnectionsListView.swift
//  backline
//
//  Created by Khadija Aslam on 4/21/26.
//

import SwiftUI

struct ConnectionsListView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ConnectionsManager.self) private var connectionsManager
    @Environment(ListingManager.self) private var listingManager

    private var currentUID: String {
        authManager.currentUser?.uid ?? ""
    }

    private var visibleConnections: [Connection] {
        let blocked = Set(authManager.blockedUsers)
        return connectionsManager.connections.filter { conn in
            !conn.participants.contains(where: { blocked.contains($0) })
        }
    }

    var body: some View {
        List {
            if visibleConnections.isEmpty {
                ContentUnavailableView(
                    "No Connections",
                    systemImage: "person.2",
                    description: Text("Your connections will appear here.")
                )
            } else {
                ForEach(visibleConnections) { connection in
                    let otherUID = connection.otherUID(currentUID: currentUID)
                    let otherUsername = connection.otherUsername(currentUID: currentUID)
                    let user = listingManager.allUsers.first(where: { $0.id == otherUID })

                    NavigationLink(value: ProfileDestination(uid: otherUID, username: otherUsername)) {
                        HStack(spacing: 12) {
                            if let urlString = user?.profilePhotoURL, let url = URL(string: urlString) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color(.systemGray5))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(Color(.systemGray4))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(otherUsername)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let roles = user?.roles, !roles.isEmpty {
                                    Text(roles.prefix(2).joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ProfileDestination.self) { dest in
            PublicProfileView(uid: dest.uid, username: dest.username)
        }
    }
}
