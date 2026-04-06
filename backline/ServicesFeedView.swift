//
//  ServicesFeedView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI
import FirebaseAuth

struct ServicesFeedView: View {

    @Environment(ListingManager.self) private var listingManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    @Binding var searchText: String
    @State private var selectedCategory: ServiceCategory?
    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    private var filteredServices: [ServiceListing] {
        var results = listingManager.serviceListings

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || $0.sellerUsername.lowercased().contains(query)
            }
        }

        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip("All", category: nil)
                    ForEach(ServiceCategory.allCases, id: \.self) { cat in
                        categoryChip(cat.rawValue, category: cat)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredServices.isEmpty {
                Spacer()
                Image(systemName: "music.mic")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No services yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                Text("Services posted by musicians will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredServices) { service in
                            serviceCard(service)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToChat) {
            if let convId = activeChatConversationId,
               let conv = activeChatConversation {
                ChatView(conversationId: convId, conversation: conv)
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ title: String, category: ServiceCategory?) -> some View {
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

    // MARK: - Service Card

    private func serviceCard(_ service: ServiceListing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.title)
                        .font(.headline)
                    Text("@\(service.sellerUsername)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(service.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }

            Text(service.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Text(service.rate)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)

                Spacer()

                if let portfolio = service.portfolioURL, !portfolio.isEmpty {
                    Link(destination: URL(string: portfolio) ?? URL(string: "https://example.com")!) {
                        Label("Portfolio", systemImage: "link")
                            .font(.caption)
                    }
                }
            }

            if service.sellerUID != authManager.currentUser?.uid {
                Button {
                    Task { await messageSellerTapped(service) }
                } label: {
                    Text("Message")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Message Seller

    private func messageSellerTapped(_ service: ServiceListing) async {
        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        if let convId = await messagesManager.startConversation(
            currentUID: uid,
            currentUsername: username,
            otherUID: service.sellerUID,
            otherUsername: service.sellerUsername
        ) {
            let conversation = messagesManager.conversations.first(where: { $0.id == convId })
                ?? Conversation(
                    id: convId,
                    participants: [uid, service.sellerUID],
                    participantUsernames: [uid: username, service.sellerUID: service.sellerUsername],
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
}
