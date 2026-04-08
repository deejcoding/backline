//
//  GigsView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct GigsView: View {

    @Environment(ListingManager.self) private var listingManager

    @State private var selectedSegment = 0
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedSegment) {
                    Text("ISOs").tag(0)
                    Text("Meet Artists").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                if selectedSegment == 0 {
                    ISOFeedView(searchText: $searchText)
                } else {
                    ServicesFeedView(searchText: $searchText)
                }
            }
            .navigationTitle("Services")
            .searchable(
                text: $searchText,
                prompt: selectedSegment == 0 ? "Search posts" : "Search artists"
            )
            .navigationDestination(for: ISOPost.self) { post in
                ISOPostDetailView(post: post)
            }
            .navigationDestination(for: ServiceListing.self) { service in
                ServiceListingDetailView(service: service)
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                PublicProfileView(uid: dest.uid, username: dest.username)
            }
            .navigationDestination(for: Listing.self) { listing in
                ListingDetailView(listing: listing)
            }
            .task {
                async let iso: () = listingManager.fetchIsoPosts()
                async let users: () = listingManager.fetchAllUsers()
                _ = await (iso, users)
            }
            .refreshable {
                if selectedSegment == 0 {
                    await listingManager.fetchIsoPosts()
                } else {
                    await listingManager.fetchAllUsers()
                }
            }
        }
    }
}
