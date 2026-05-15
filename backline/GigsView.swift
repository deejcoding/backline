//
//  GigsView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct GigsView: View {

    @Binding var navigationPath: NavigationPath

    @Environment(ListingManager.self) private var listingManager

    @State private var selectedSegment = 0
    @State private var searchText = ""

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Segmented control
                HStack(spacing: 0) {
                    segmentButton("Open Roles", tag: 0)
                    segmentButton("Meet Artists", tag: 1)
                    segmentButton("Upcoming Shows", tag: 2)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }

                // Content
                if selectedSegment == 0 {
                    ISOFeedView(searchText: $searchText)
                } else if selectedSegment == 1 {
                    ServicesFeedView(searchText: $searchText)
                } else {
                    ShowFlyersFeedView(searchText: $searchText)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("backline")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(-0.2)
                }

            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: selectedSegment == 0 ? "Search posts" : selectedSegment == 1 ? "Search artists" : "Search shows"
            )
            .onSubmit(of: .search) {
                if selectedSegment == 0 {
                    BLAnalytics.searchISOPosts(query: searchText)
                } else if selectedSegment == 1 {
                    BLAnalytics.searchArtists(query: searchText)
                } else {
                    BLAnalytics.searchShowFlyers(query: searchText)
                }
            }
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
            .navigationDestination(for: ShowFlyer.self) { flyer in
                ShowFlyerDetailView(flyer: flyer)
            }
            .task {
                async let iso: () = listingManager.fetchIsoPosts()
                async let users: () = listingManager.fetchAllUsers()
                async let flyers: () = listingManager.fetchShowFlyers()
                _ = await (iso, users, flyers)
            }

        }
    }

    // MARK: - Segment Button

    private func segmentButton(_ title: String, tag: Int) -> some View {
        Button {
            selectedSegment = tag
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: selectedSegment == tag ? .bold : .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(selectedSegment == tag ? .white : .white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Rectangle()
                    .fill(selectedSegment == tag ? ThemeColor.cyan : .clear)
                    .frame(height: 2)
            }
        }
        .accessibilityLabel(title)
    }
}
