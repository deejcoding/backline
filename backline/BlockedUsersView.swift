//
//  BlockedUsersView.swift
//  backline
//
//  Created by Khadija Aslam on 4/20/26.
//

import SwiftUI

struct BlockedUsersView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager

    var body: some View {
        List {
            if authManager.blockedUsers.isEmpty {
                Text("You haven't blocked anyone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(authManager.blockedUsers, id: \.self) { uid in
                    let username = listingManager.allUsers
                        .first(where: { $0.id == uid })?.username ?? uid
                    HStack {
                        Text("@\(username)")
                            .font(.subheadline)
                        Spacer()
                        Button("Unblock") {
                            Task { await authManager.unblockUser(uid) }
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
    }
}
