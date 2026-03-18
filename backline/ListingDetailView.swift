//
//  ListingDetailView.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import SwiftUI
import FirebaseAuth

struct ListingDetailView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    let listing: Listing

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Photo carousel
                TabView {
                    ForEach(listing.photoURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    photoPlaceholder
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                @unknown default:
                                    photoPlaceholder
                                }
                            }
                        }
                    }
                }
                .frame(height: 300)
                .tabViewStyle(.page)
                .clipShape(Rectangle())

                VStack(alignment: .leading, spacing: 12) {

                    // Title and price
                    Text(listing.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("$\(listing.price, specifier: "%.0f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)

                    Divider()

                    // Details
                    detailRow("Condition", value: listing.condition.rawValue)
                    detailRow("Category", value: listing.category.rawValue)
                    detailRow("Location", value: listing.location)
                    detailRow("Seller", value: "@\(listing.sellerUsername)")

                    Divider()

                    // Description
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(listing.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Message Seller button
                    if listing.sellerUID != authManager.currentUser?.uid {
                        Button {
                            Task { await messageSellerTapped() }
                        } label: {
                            Text("Message Seller")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Rectangle())
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToChat) {
            if let convId = activeChatConversationId,
               let conv = activeChatConversation {
                ChatView(conversationId: convId, conversation: conv)
            }
        }
    }

    // MARK: - Detail Row

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Photo Placeholder

    private var photoPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .overlay {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Message Seller

    private func messageSellerTapped() async {
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
                    lastMessageSenderUID: ""
                )
            activeChatConversationId = convId
            activeChatConversation = conversation
            navigateToChat = true
        }
    }
}
