//
//  MarketplaceView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth

struct MarketplaceView: View {

    @Environment(ListingManager.self) private var listingManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    @State private var searchText = ""
    @State private var selectedCategory: ListingCategory?
    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    private var filteredListings: [Listing] {
        var results = listingManager.listings

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
            }
        }

        return results
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip("All", category: nil)
                        ForEach(ListingCategory.allCases, id: \.self) { cat in
                            categoryChip(cat.rawValue, category: cat)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if filteredListings.isEmpty {
                    Spacer()
                    Image(systemName: "guitars")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No listings yet")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.top, 4)
                    Text("Listings you and others post will appear here.")
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
                            ForEach(filteredListings) { listing in
                                NavigationLink {
                                    ListingDetailView(listing: listing)
                                } label: {
                                    listingCard(listing)
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
            .navigationTitle("Marketplace")
            .searchable(text: $searchText, prompt: "Search gear and instruments")
            .task {
                await listingManager.fetchListings()
            }
            .refreshable {
                await listingManager.fetchListings()
            }
            .navigationDestination(isPresented: $navigateToChat) {
                if let convId = activeChatConversationId,
                   let conv = activeChatConversation {
                    ChatView(conversationId: convId, conversation: conv)
                }
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                PublicProfileView(uid: dest.uid, username: dest.username)
            }
            .navigationDestination(for: ISOPost.self) { post in
                ISOPostDetailView(post: post)
            }
            .navigationDestination(for: ServiceListing.self) { service in
                ServiceListingDetailView(service: service)
            }
        }
    }
    
    //TODO: add a map view in the top right corner. This will show listings on a map but not exact addresses for privacy.

    // MARK: - Category Chip

    private func categoryChip(_ title: String, category: ListingCategory?) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedCategory == category ? .white : .clear)
                .foregroundStyle(selectedCategory == category ? .black : .primary)
                .overlay(
                    Capsule()
                        .stroke(selectedCategory == category ? .white : .white.opacity(0.2), lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Listing Card

    private func listingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Photo
            Color.clear
                .frame(height: 120)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                imagePlaceholder
                            case .empty:
                                ProgressView()
                            @unknown default:
                                imagePlaceholder
                            }
                        }
                    } else {
                        imagePlaceholder
                    }
                }
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(listing.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Price info
                if let price = listing.price {
                    Text("$\(price, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundStyle(ThemeColor.green)
                }
                if let rentPrice = listing.rentPrice, !rentPrice.isEmpty {
                    Text(rentPrice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Listing type tags
                HStack(spacing: 3) {
                    ForEach(Array(listing.listingTypes.enumerated()), id: \.element) { index, type in
                        let color = ThemeColor.cycle(index)
                        Text(type.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(listing.location)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            if listing.sellerUID != authManager.currentUser?.uid {
                Button {
                    Task {
                        guard let uid = authManager.currentUser?.uid,
                              let username = authManager.username else { return }
                        if let convId = await messagesManager.startConversation(
                            currentUID: uid,
                            currentUsername: username,
                            otherUID: listing.sellerUID,
                            otherUsername: listing.sellerUsername
                        ) {
                            let conversation = messagesManager.conversations.first(where: { $0.id == convId })
                                ?? Conversation(
                                    id: convId,
                                    participants: [uid, listing.sellerUID],
                                    participantUsernames: [uid: username, listing.sellerUID: listing.sellerUsername],
                                    lastMessage: "",
                                    lastMessageAt: Date(),
                                    lastMessageSenderUID: "",
                                    lastReadAt: [:]
                                )
                            activeChatConversationId = convId
                            activeChatConversation = conversation
                            navigateToChat = true
                        }
                    }
                } label: {
                    Text("Message Seller")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}
