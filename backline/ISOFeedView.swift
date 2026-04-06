//
//  ISOFeedView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI
import FirebaseAuth

struct ISOFeedView: View {

    @Environment(ListingManager.self) private var listingManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    @Binding var searchText: String
    @State private var selectedCategory: ISOCategory?
    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    private var filteredPosts: [ISOPost] {
        var results = listingManager.isoPosts.filter { !$0.isExpired }

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.roleNeeded.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
                || $0.posterUsername.lowercased().contains(query)
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
                    ForEach(ISOCategory.allCases, id: \.self) { cat in
                        categoryChip(cat.rawValue, category: cat)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredPosts.isEmpty {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No posts yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
                Text("ISO posts from musicians will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPosts) { post in
                            isoPostCard(post)
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

    private func categoryChip(_ title: String, category: ISOCategory?) -> some View {
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

    // MARK: - ISO Post Card

    private func isoPostCard(_ post: ISOPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Role + category badge
            HStack {
                Text(post.roleNeeded)
                    .font(.headline)
                Spacer()
                Text(post.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }

            Text("@\(post.posterUsername)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(post.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Location, timeframe, budget
            HStack(spacing: 12) {
                Label(post.location, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(post.timeframe.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(post.budget)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }

            // Message button
            if post.posterUID != authManager.currentUser?.uid {
                Button {
                    Task { await messagePosterTapped(post) }
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

    // MARK: - Message Poster

    private func messagePosterTapped(_ post: ISOPost) async {
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
