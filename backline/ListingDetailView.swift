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
    @Environment(ListingManager.self) private var listingManager
    @Environment(\.dismiss) private var dismiss

    let listing: Listing

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?
    @State private var showDeleteConfirmation = false
    @State private var showEditListing = false
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showGuestPrompt = false

    private var isOwnListing: Bool {
        listing.sellerUID == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Photo carousel
                TabView {
                    ForEach(Array(listing.photoURLs.enumerated()), id: \.element) { index, urlString in
                        if let url = URL(string: urlString) {
                            CachedAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .accessibilityLabel("Photo \(index + 1) of \(listing.photoURLs.count) for \(listing.title)")
                        }
                    }
                }
                .frame(height: 300)
                .tabViewStyle(.page)
                .clipShape(Rectangle())

                VStack(alignment: .leading, spacing: 0) {

                    // Title
                    Text(listing.title)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.3)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Prices
                    HStack(spacing: 8) {
                        if let price = listing.price {
                            Text("$\(price, specifier: "%.0f")")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(ThemeColor.green)
                        }
                        if let rentPrice = listing.rentPrice, !rentPrice.isEmpty {
                            Text(rentPrice)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundStyle(ThemeColor.cyan)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    // Listing type tags
                    HStack(spacing: 6) {
                        ForEach(Array(listing.listingTypes.enumerated()), id: \.element) { index, type in
                            let color = ThemeColor.cycle(index)
                            Text(type.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(color)
                                .overlay(
                                    Rectangle()
                                        .stroke(color.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Details grid
                    VStack(spacing: 0) {
                        detailRow("CONDITION", value: listing.condition.rawValue)
                        detailRow("CATEGORY", value: listing.category.rawValue)
                        detailRow("LOCATION", value: listing.location)
                        HStack {
                            Text("SELLER")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                            NavigationLink(value: ProfileDestination(uid: listing.sellerUID, username: listing.sellerUsername)) {
                                Text("@\(listing.sellerUsername)")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(ThemeColor.cyan)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                        }
                    }
                    .padding(.top, 16)

                    // Description
                    Text("DESCRIPTION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    Text(listing.description)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                    // Message Seller button
                    if !isOwnListing && !authManager.isBlocked(listing.sellerUID) {
                        if authManager.isGuestMode {
                            Button {
                                showGuestPrompt = true
                            } label: {
                                Text("MESSAGE SELLER")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .foregroundStyle(Color.black)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        } else if authManager.canInteract {
                            Button {
                                Task { await messageSellerTapped() }
                            } label: {
                                Text("MESSAGE SELLER")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .foregroundStyle(Color.black)
                            }
                            .accessibilityLabel("Message \(listing.sellerUsername) about \(listing.title)")
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        } else {
                            VStack(spacing: 4) {
                                Text("COMPLETE YOUR PROFILE TO MESSAGE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundStyle(ThemeColor.red)
                                Text("\(authManager.profileCompleteness)% complete — 80% required")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                    }

                    // Edit / Delete for own listings
                    if isOwnListing {
                        VStack(spacing: 10) {
                            Button {
                                showEditListing = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                    Text("EDIT LISTING")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .tracking(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    Rectangle()
                                        .stroke(.white.opacity(0.18), lineWidth: 1)
                                )
                            }

                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("DELETE LISTING")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .tracking(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(ThemeColor.red)
                                .overlay(
                                    Rectangle()
                                        .stroke(ThemeColor.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.bottom, 100)
        }
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { BLAnalytics.viewListing(listingId: listing.id) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareURL = URL(string: "backline://listing/\(listing.id)") {
                    ShareLink(
                        item: shareURL,
                        subject: Text(listing.title),
                        message: Text("Check out \(listing.title) on Backline")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                    }
                }
            }
            if !isOwnListing && !authManager.isGuestMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label("Report Listing", systemImage: "exclamationmark.triangle")
                        }
                        Button(role: .destructive) {
                            showBlockConfirmation = true
                        } label: {
                            Label("Block User", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.body)
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportView(contentType: "listing", contentId: listing.id, reportedUID: listing.sellerUID)
        }
        .alert("Block @\(listing.sellerUsername)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) {
                Task { await authManager.blockUser(listing.sellerUID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to message you, and their content will be hidden from your feeds.")
        }
        .sheet(isPresented: $showGuestPrompt) {
            GuestPromptView()
        }
        .navigationDestination(isPresented: $navigateToChat) {
            if let convId = activeChatConversationId,
               let conv = activeChatConversation {
                ChatView(conversationId: convId, conversation: conv)
            }
        }
        .sheet(isPresented: $showEditListing) {
            EditListingView(listing: listing)
        }
        .alert("Delete Listing", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await listingManager.deleteListing(id: listing.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this listing? This cannot be undone.")
        }
    }

    // MARK: - Detail Row

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
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
            otherUsername: listing.sellerUsername,
            initialMessage: "Inquiry about your listing: \(listing.title)"
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
}
