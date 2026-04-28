//
//  ConnectionRequestsView.swift
//  backline
//
//  Created by Khadija Aslam on 4/21/26.
//

import SwiftUI

struct ConnectionRequestsView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ConnectionsManager.self) private var connectionsManager
    @Environment(ListingManager.self) private var listingManager

    var body: some View {
        List {
            if connectionsManager.incomingRequests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "person.2",
                    description: Text("Connection requests will appear here.")
                )
            } else {
                ForEach(connectionsManager.incomingRequests) { request in
                    requestRow(request)
                }
            }
        }
        .navigationTitle("Connection Requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestRow(_ request: Connection) -> some View {
        let user = listingManager.allUsers.first(where: { $0.id == request.fromUID })

        return HStack(spacing: 12) {
            // Profile photo
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
                Text("@\(request.fromUsername)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let roles = user?.roles, !roles.isEmpty {
                    Text(roles.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await connectionsManager.acceptRequest(request.id) }
                } label: {
                    Text("Accept")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ThemeColor.blue)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await connectionsManager.rejectRequest(request.id) }
                } label: {
                    Text("Decline")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
