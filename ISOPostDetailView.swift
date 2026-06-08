//
//  ISOPostDetailView.swift
//  backline
//
//  Created by Khadija Aslam on 4/7/26.
//

import SwiftUI
import FirebaseAuth

struct ISOPostDetailView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(\.dismiss) private var dismiss

    let post: ISOPost

    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?
    @State private var showDeleteConfirmation = false
    @State private var showEditPost = false
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showGuestPrompt = false

    private var isOwnPost: Bool {
        post.posterUID == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LOOKING FOR")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(ThemeColor.cyan)

                            Text(post.roleNeeded)
                                .font(.system(size: 24, weight: .bold))
                                .tracking(-0.3)
                        }
                        Spacer()
                        Text(post.category.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(ThemeColor.cyan)
                            .overlay(
                                Rectangle()
                                    .stroke(ThemeColor.cyan.opacity(0.3), lineWidth: 1)
                            )
                    }

                    NavigationLink(value: ProfileDestination(uid: post.posterUID, username: post.posterUsername)) {
                        Text("@\(post.posterUsername)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(ThemeColor.cyan)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Details
                VStack(spacing: 0) {
                    if let location = post.location, !location.isEmpty {
                        detailRow("LOCATION", value: location, icon: "mappin")
                    }
                    if post.isOngoing == true {
                        detailRow("TIMEFRAME", value: "Ongoing", icon: "calendar")
                    } else if let timeframe = post.timeframe {
                        detailRow("TIMEFRAME", value: timeframe.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                    }
                    if let budget = post.budget, !budget.isEmpty {
                        detailRow("COMPENSATION", value: budget, icon: "dollarsign.circle")
                    }
                    detailRow("POSTED", value: post.createdAt.formatted(date: .abbreviated, time: .omitted), icon: "clock")
                }
                .padding(.top, 8)

                // Description
                Text("DESCRIPTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Text(post.description)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                // Message button
                if !isOwnPost && !authManager.isBlocked(post.posterUID) {
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
                        .accessibilityLabel("Message \(post.posterUsername) about this gig")
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

                // Edit / Delete for own posts
                if isOwnPost {
                    VStack(spacing: 10) {
                        Button {
                            showEditPost = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                Text("EDIT POST")
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
                                Text("DELETE POST")
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
        .navigationTitle("Open Role")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { BLAnalytics.viewISOPost(postId: post.id) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareURL = URL(string: "backline://iso/\(post.id)") {
                    ShareLink(
                        item: shareURL,
                        subject: Text("\(post.roleNeeded) needed"),
                        message: Text("Check out this gig on Backline: \(post.roleNeeded) needed\(post.location.map { " in \($0)" } ?? "")")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                    }
                }
            }
            if !isOwnPost && !authManager.isGuestMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label("Report Post", systemImage: "exclamationmark.triangle")
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
            ReportView(contentType: "isoPost", contentId: post.id, reportedUID: post.posterUID)
        }
        .alert("Block @\(post.posterUsername)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) {
                Task { await authManager.blockUser(post.posterUID) }
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
        .sheet(isPresented: $showEditPost) {
            EditISOPostView(post: post)
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await listingManager.deleteISOPost(id: post.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this post? This cannot be undone.")
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

    // MARK: - Message Poster

    private func messagePosterTapped() async {
        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        if let convId = await messagesManager.startConversation(
            currentUID: uid,
            currentUsername: username,
            otherUID: post.posterUID,
            otherUsername: post.posterUsername,
            initialMessage: "Inquiry about your post: \(post.roleNeeded)"
        ) {
            let conversation = messagesManager.conversations.first(where: { $0.id == convId })
                ?? Conversation(
                    id: convId,
                    participants: [uid, post.posterUID],
                    participantUsernames: [uid: username, post.posterUID: post.posterUsername],
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
