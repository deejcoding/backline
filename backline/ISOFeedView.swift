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
        let blocked = Set(authManager.blockedUsers)
        var results = listingManager.isoPosts.filter { !blocked.contains($0.posterUID) }

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.roleNeeded.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || ($0.location?.lowercased().contains(query) ?? false)
                || $0.posterUsername.lowercased().contains(query)
            }
        }

        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = listingManager.errorMessage {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(ThemeColor.red.opacity(0.85))
            }

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
                Text("Open roles from musicians will appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPosts) { post in
                            NavigationLink(value: post) {
                                isoPostCard(post)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await listingManager.fetchIsoPosts()
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
        BroadcastChip(
            title: title,
            isSelected: selectedCategory == category,
            action: { selectedCategory = category }
        )
    }

    // MARK: - ISO Post Card

    private func isoPostCard(_ post: ISOPost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // Square avatar
                if let photoURL = listingManager.profilePhotos[post.posterUID],
                   let url = URL(string: photoURL) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .frame(width: 56, height: 56)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color(.systemGray3))
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Handle + time
                    HStack {
                        Text("@\(post.posterUsername)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text(post.timeAgoString)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    // Kicker
                    Text("LOOKING FOR")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(ThemeColor.cyan)

                    // Role
                    Text(post.roleNeeded)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.1)
                        .lineLimit(1)

                    // Description
                    Text(post.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)

                    // Meta row
                    HStack(spacing: 6) {
                        Text(post.budget)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(ThemeColor.green)
                            .tracking(-0.1)

                        if let genres = posterGenres(for: post.posterUID), !genres.isEmpty {
                            Text("·")
                                .foregroundStyle(.white.opacity(0.4))
                            Text(genres)
                                .font(.system(size: 12).italic())
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 2)

                    // Message button
                    if post.posterUID != authManager.currentUser?.uid {
                        if authManager.canInteract {
                            Button {
                                Task { await messagePosterTapped(post) }
                            } label: {
                                Text("Message")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .tracking(0.4)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        Rectangle()
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    )
                            }
                            .padding(.top, 8)
                        } else {
                            Text("Complete profile to message!")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(ThemeColor.yellow.opacity(0.7))
                                .padding(.top, 8)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ThemeColor.hairline)
                .frame(height: 1)
        }
    }

    // MARK: - Poster Genres

    private func posterGenres(for uid: String) -> String? {
        guard let user = listingManager.allUsers.first(where: { $0.id == uid }),
              !user.genres.isEmpty else { return nil }
        return user.genres.joined(separator: " · ")
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
