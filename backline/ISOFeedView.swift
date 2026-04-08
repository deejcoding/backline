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
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No posts yet")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                Text("ISO posts from musicians will appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPosts) { post in
                            NavigationLink(value: post) {
                                isoPostCard(post)
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
        .navigationDestination(isPresented: $navigateToChat) {
            if let convId = activeChatConversationId,
               let conv = activeChatConversation {
                ChatView(conversationId: convId, conversation: conv)
            }
        }
        .task {
            let uids = Array(Set(listingManager.isoPosts.map(\.posterUID)))
            await listingManager.fetchProfilePhotos(for: uids)
        }
        .onChange(of: listingManager.isoPosts.count) {
            Task {
                let uids = Array(Set(listingManager.isoPosts.map(\.posterUID)))
                await listingManager.fetchProfilePhotos(for: uids)
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ title: String, category: ISOCategory?) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(title)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedCategory == category ? .white : .clear)
                .foregroundStyle(selectedCategory == category ? .black : .primary)
                .overlay(
                    Capsule()
                        .stroke(selectedCategory == category ? .white : .white.opacity(0.2), lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - ISO Post Card

    private func isoPostCard(_ post: ISOPost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Role + category badge
            HStack {
                Text(post.roleNeeded)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(post.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
            }

            HStack(spacing: 5) {
                if let photoURL = listingManager.profilePhotos[post.posterUID],
                   let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color(.systemGray4))
                    }
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(.systemGray3))
                }
                Text("@\(post.posterUsername)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(post.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Location, timeframe, budget
            HStack(spacing: 10) {
                Label(post.location, systemImage: "mappin")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label(post.timeframe.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(post.budget)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Message button
            if post.posterUID != authManager.currentUser?.uid {
                Button {
                    Task { await messagePosterTapped(post) }
                } label: {
                    Text("Message")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
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
