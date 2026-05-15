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
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showGuestPrompt = false

    private var isOwnListing: Bool {
        service.sellerUID == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(service.title)
                            .font(.system(size: 24, weight: .bold))
                            .tracking(-0.3)
                        Spacer()
                        Text(service.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(ThemeColor.yellow)
                            .overlay(
                                Rectangle()
                                    .stroke(ThemeColor.yellow.opacity(0.3), lineWidth: 1)
                            )
                    }

                    NavigationLink(value: ProfileDestination(uid: service.sellerUID, username: service.sellerUsername)) {
                        Text("@\(service.sellerUsername)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(ThemeColor.cyan)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Details
                VStack(spacing: 0) {
                    detailRow("RATE", value: service.rate, icon: "dollarsign.circle")
                    detailRow("POSTED", value: service.createdAt.formatted(date: .abbreviated, time: .omitted), icon: "clock")

                    if let portfolio = service.portfolioURL, !portfolio.isEmpty {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.35))
                                Text("PORTFOLIO")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(0.8)
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                            if let url = URL(string: portfolio) {
                                Link(portfolio, destination: url)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ThemeColor.cyan)
                                    .lineLimit(1)
                            } else {
                                Text(portfolio)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 8)

                // Description
                Text("DESCRIPTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Text(service.description)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                // Message button
                if !isOwnListing && !authManager.isBlocked(service.sellerUID) {
                    if authManager.isGuestMode {
                        Button {
                            showGuestPrompt = true
                        } label: {
                            Text("MESSAGE")
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
                            Text("MESSAGE")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .foregroundStyle(Color.black)
                        }
                        .accessibilityLabel("Message \(service.sellerUsername) about \(service.title)")
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
                            showEditService = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                Text("EDIT SERVICE")
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
                                Text("DELETE SERVICE")
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
            .padding(.bottom, 100)
        }
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { BLAnalytics.viewServiceListing(serviceId: service.id) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareURL = URL(string: "backline://service/\(service.id)") {
                    ShareLink(
                        item: shareURL,
                        subject: Text(service.title),
                        message: Text("Check out \(service.title) on Backline")
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
                            Label("Report Service", systemImage: "exclamationmark.triangle")
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
            ReportView(contentType: "service", contentId: service.id, reportedUID: service.sellerUID)
        }
        .alert("Block @\(service.sellerUsername)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) {
                Task { await authManager.blockUser(service.sellerUID) }
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
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.45))
            }
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

    // MARK: - Message Seller

    private func messageSellerTapped() async {
        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        if let convId = await messagesManager.startConversation(
            currentUID: uid,
            currentUsername: username,
            otherUID: service.sellerUID,
            otherUsername: service.sellerUsername,
            initialMessage: "Inquiry about your service: \(service.title)"
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
