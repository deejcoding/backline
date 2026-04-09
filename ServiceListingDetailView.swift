//
//  ServiceListingDetailView.swift
//  backline
//
//  Created by Khadija Aslam on 4/7/26.
//

import SwiftUI
import FirebaseAuth

struct ServiceListingDetailView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(\.dismiss) private var dismiss

    let service: ServiceListing

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?
    @State private var showDeleteConfirmation = false
    @State private var showEditService = false

    private var isOwnListing: Bool {
        service.sellerUID == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(service.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text(service.category.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ThemeColor.blue.opacity(0.15))
                            .foregroundStyle(ThemeColor.blue)
                            .clipShape(Capsule())
                    }

                    NavigationLink(value: ProfileDestination(uid: service.sellerUID, username: service.sellerUsername)) {
                        Text("@\(service.sellerUsername)")
                            .font(.subheadline)
                            .foregroundStyle(ThemeColor.blue)
                    }
                }

                Divider()

                // Details
                detailRow("Rate", value: service.rate, icon: "dollarsign.circle")
                detailRow("Posted", value: service.createdAt.formatted(date: .abbreviated, time: .omitted), icon: "clock")

                if let portfolio = service.portfolioURL, !portfolio.isEmpty {
                    HStack {
                        Label("Portfolio", systemImage: "link")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link(portfolio, destination: URL(string: portfolio) ?? URL(string: "https://example.com")!)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }

                Divider()

                // Description
                Text("Description")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(service.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Message button
                if !isOwnListing {
                    Button {
                        Task { await messageSellerTapped() }
                    } label: {
                        Text("Message")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ThemeColor.blue)
                            .foregroundStyle(.white)
                            .clipShape(Rectangle())
                    }
                    .padding(.top, 8)
                }

                // Edit / Delete for own listings
                if isOwnListing {
                    VStack(spacing: 10) {
                        Button {
                            showEditService = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Service")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ThemeColor.blue)
                            .foregroundStyle(.white)
                            .clipShape(Rectangle())
                        }

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Service")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(Rectangle())
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToChat) {
            if let convId = activeChatConversationId,
               let conv = activeChatConversation {
                ChatView(conversationId: convId, conversation: conv)
            }
        }
        .sheet(isPresented: $showEditService) {
            EditServiceListingView(service: service)
        }
        .alert("Delete Service", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await listingManager.deleteServiceListing(id: service.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this service? This cannot be undone.")
        }
    }

    // MARK: - Detail Row

    private func detailRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Message Seller

    private func messageSellerTapped() async {
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
