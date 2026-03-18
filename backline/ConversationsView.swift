//
//  ConversationsView.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import SwiftUI
import FirebaseAuth

struct ConversationsView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    var body: some View {
        NavigationStack {
            Group {
                if messagesManager.conversations.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No messages yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        Text("Start a conversation from a listing or service.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List(messagesManager.conversations) { conversation in
                        NavigationLink {
                            ChatView(conversationId: conversation.id, conversation: conversation)
                        } label: {
                            conversationRow(conversation)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .task {
                if let uid = authManager.currentUser?.uid {
                    messagesManager.listenToConversations(forUID: uid)
                }
            }
        }
    }

    // MARK: - Conversation Row

    private func conversationRow(_ conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(otherUsername(in: conversation))
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(conversation.lastMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func otherUsername(in conversation: Conversation) -> String {
        guard let uid = authManager.currentUser?.uid else { return "Unknown" }
        let otherUID = conversation.participants.first(where: { $0 != uid }) ?? ""
        return conversation.participantUsernames[otherUID] ?? "Unknown"
    }
}
