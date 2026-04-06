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
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No listings yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                    Text("Listings you and others post will appear here.")
                        .font(.subheadline)
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
        }
    }
    
    //TODO: add a map view in the top right corner. This will show listings on a map but not exact addresses for privacy.

    // MARK: - Category Chip

    private func categoryChip(_ title: String, category: ListingCategory?) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == category ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(selectedCategory == category ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Listing Card

    private func listingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Photo
            Color.clear
                .frame(height: 140)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                // Price info
                if let price = listing.price {
                    Text("$\(price, specifier: "%.0f")")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                if let rentPrice = listing.rentPrice, !rentPrice.isEmpty {
                    Text(rentPrice)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }

                // Listing type tags
                HStack(spacing: 4) {
                    ForEach(listing.listingTypes, id: \.self) { type in
                        Text(type.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }

                Text(listing.location)
                    .font(.caption)
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
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .background(Color(.systemGray6))
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
