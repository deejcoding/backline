//
//  ShowFlyersFeedView.swift
//  backline
//

import SwiftUI
import FirebaseAuth

struct ShowFlyersFeedView: View {

    @Environment(ListingManager.self) private var listingManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ConnectionsManager.self) private var connectionsManager

    @Binding var searchText: String
    @State private var showConnectedOnly = false

    private var filteredFlyers: [ShowFlyer] {
        let blocked = Set(authManager.blockedUsers)
        let currentUID = authManager.currentUser?.uid ?? ""
        var results = listingManager.showFlyers.filter { !$0.isExpired && !blocked.contains($0.posterUID) }

        if showConnectedOnly {
            let connectedUIDs = Set(connectionsManager.connections.map { $0.otherUID(currentUID: currentUID) })
            results = results.filter { connectedUIDs.contains($0.posterUID) }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query)
                || ($0.venue?.lowercased().contains(query) ?? false)
                || $0.posterUsername.lowercased().contains(query)
            }
        }

        return results
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Connected / All toggle
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BroadcastChip(
                        title: "All",
                        isSelected: !showConnectedOnly,
                        action: { showConnectedOnly = false }
                    )
                    BroadcastChip(
                        title: "Connected",
                        isSelected: showConnectedOnly,
                        action: { showConnectedOnly = true }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredFlyers.isEmpty {
                Spacer()
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No flyers yet")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                Text("Show flyers from musicians will appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredFlyers) { flyer in
                            NavigationLink(value: flyer) {
                                flyerCard(flyer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await listingManager.fetchShowFlyers()
                }
            }
        }
    }

    // MARK: - Flyer Card

    private func flyerCard(_ flyer: ShowFlyer) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Background: flyer image blurred (3:4 aspect)
            Color.clear
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    if let url = URL(string: flyer.imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 12, opaque: false)
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray6))
                                .overlay { ProgressView() }
                        }
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(Color(.systemGray4))
                            }
                    }
                }
                .clipped()

            // Foreground: gradient + details on top
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(flyer.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                if let venue = flyer.venue, !venue.isEmpty {
                    Text(venue)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(ThemeColor.cyan)
                        .lineLimit(1)
                }

                if let eventDate = flyer.eventDate {
                    Text(eventDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(ThemeColor.yellow)
                }

                Text("@\(flyer.posterUsername)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipped()
    }
}

