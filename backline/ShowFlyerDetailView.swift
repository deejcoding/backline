//
//  ShowFlyerDetailView.swift
//  backline
//

import SwiftUI
import FirebaseAuth

struct ShowFlyerDetailView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(\.dismiss) private var dismiss

    let flyer: ShowFlyer

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?
    @State private var showDeleteConfirmation = false
    @State private var showEditFlyer = false
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showGuestPrompt = false

    private var isOwnFlyer: Bool {
        flyer.posterUID == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Flyer image
                if let url = URL(string: flyer.imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray6))
                            .aspectRatio(3/4, contentMode: .fit)
                            .overlay { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }

                // Title and info
                VStack(alignment: .leading, spacing: 8) {
                    Text(flyer.title)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.3)

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let venue = flyer.venue, !venue.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ThemeColor.cyan)
                                    Text(venue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(ThemeColor.cyan)
                                }
                            }

                            if let eventDate = flyer.eventDate {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                    Text(eventDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(ThemeColor.yellow)
                            }
                        }

                        Spacer()

                        if let ticketURL = flyer.ticketURL, let url = URL(string: ticketURL) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "ticket")
                                        .font(.system(size: 10))
                                    Text("TICKETS")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .tracking(0.5)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .foregroundStyle(.black)
                            }
                        }
                    }

                    if flyer.isExpired {
                        Text("EXPIRED")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(ThemeColor.red)
                            .overlay(
                                Rectangle()
                                    .stroke(ThemeColor.red.opacity(0.3), lineWidth: 1)
                            )
                    }

                    NavigationLink(value: ProfileDestination(uid: flyer.posterUID, username: flyer.posterUsername)) {
                        Text("@\(flyer.posterUsername)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(ThemeColor.cyan)
                    }

                    Text(flyer.timeAgoString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 16)

                // Message button
                if !isOwnFlyer && !flyer.isExpired && !authManager.isBlocked(flyer.posterUID) {
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
                        .padding(.top, 4)
                    } else if authManager.canInteract {
                        Button {
                            Task { await messagePosterTapped() }
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
                        .padding(.top, 4)
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
                        .padding(.top, 4)
                    }
                }

                // Edit / Delete for own flyers
                if isOwnFlyer {
                    VStack(spacing: 10) {
                        Button {
                            showEditFlyer = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                Text("EDIT FLYER")
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
                                Text("DELETE FLYER")
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
        .navigationTitle("Show Flyer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { BLAnalytics.viewShowFlyer(flyerId: flyer.id) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareURL = URL(string: "backline://flyer/\(flyer.id)") {
                    ShareLink(
                        item: shareURL,
                        subject: Text(flyer.title),
                        message: Text("Check out this show on Backline: \(flyer.title)\(flyer.venue.map { " at \($0)" } ?? "")")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                    }
                }
            }
            if !isOwnFlyer && !authManager.isGuestMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label("Report Flyer", systemImage: "exclamationmark.triangle")
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
                }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportView(contentType: "showFlyer", contentId: flyer.id, reportedUID: flyer.posterUID)
        }
        .alert("Block @\(flyer.posterUsername)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) {
                Task { await authManager.blockUser(flyer.posterUID) }
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
        .sheet(isPresented: $showEditFlyer) {
            EditShowFlyerView(flyer: flyer)
        }
        .alert("Delete Flyer", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await listingManager.deleteShowFlyer(id: flyer.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this flyer? This cannot be undone.")
        }
    }

    // MARK: - Message Poster

    private func messagePosterTapped() async {
        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        if let convId = await messagesManager.startConversation(
            currentUID: uid,
            currentUsername: username,
            otherUID: flyer.posterUID,
            otherUsername: flyer.posterUsername,
            initialMessage: "Inquiry about your show: \(flyer.title)"
        ) {
            let conversation = messagesManager.conversations.first(where: { $0.id == convId })
                ?? Conversation(
                    id: convId,
                    participants: [uid, flyer.posterUID],
                    participantUsernames: [uid: username, flyer.posterUID: flyer.posterUsername],
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
