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

    private var isOwnPost: Bool {
        post.posterUID == authManager.currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(post.roleNeeded)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text(post.category.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }

                    if post.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }

                    NavigationLink(value: ProfileDestination(uid: post.posterUID, username: post.posterUsername)) {
                        Text("@\(post.posterUsername)")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Divider()

                // Details
                detailRow("Location", value: post.location, icon: "mappin")
                detailRow("Timeframe", value: post.timeframe.formatted(date: .abbreviated, time: .omitted), icon: "calendar")
                detailRow("Budget", value: post.budget, icon: "dollarsign.circle")
                detailRow("Posted", value: post.createdAt.formatted(date: .abbreviated, time: .omitted), icon: "clock")

                Divider()

                // Description
                Text("Description")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(post.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Message button
                if !isOwnPost && !post.isExpired {
                    Button {
                        Task { await messagePosterTapped() }
                    } label: {
                        Text("Message")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Rectangle())
                    }
                    .padding(.top, 8)
                }

                // Edit / Delete for own posts
                if isOwnPost {
                    VStack(spacing: 10) {
                        Button {
                            showEditPost = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Post")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Rectangle())
                        }

                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Post")
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
        .navigationTitle("ISO Post")
        .navigationBarTitleDisplayMode(.inline)
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
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
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
            otherUsername: post.posterUsername
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
