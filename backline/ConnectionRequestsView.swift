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
            if let error = connectionsManager.errorMessage {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ThemeColor.red)
                    .listRowBackground(Color.clear)
            }

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
        .onAppear { BLAnalytics.viewConnectionRequests() }
    }

    private func requestRow(_ request: Connection) -> some View {
        let user = listingManager.allUsers.first(where: { $0.id == request.fromUID })

        return HStack(spacing: 12) {
            // Profile photo
            if let urlString = user?.profilePhotoURL, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(Rectangle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Color(.systemGray4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(request.participantUsernames[request.fromUID] ?? "Unknown")")
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ThemeColor.blue)
                        .foregroundStyle(.black)
                        .clipShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await connectionsManager.rejectRequest(request.id) }
                } label: {
                    Text("Decline")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(Rectangle().stroke(.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
