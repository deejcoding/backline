//
//  ChatView.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import SwiftUI
import FirebaseAuth

struct ChatView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    let conversationId: String
    let conversation: Conversation

    @State private var messageText = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messagesManager.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: messagesManager.messages.count) { _, _ in
                    if let lastMessage = messagesManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray4)
                            : Color.accentColor
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(otherUsername)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            messagesManager.listenToMessages(conversationId: conversationId)
        }
        .onDisappear {
            messagesManager.stopListeningToMessages()
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: Message) -> some View {
        let isCurrentUser = message.senderUID == authManager.currentUser?.uid

        return HStack {
            if isCurrentUser { Spacer(minLength: 60) }

            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isCurrentUser ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Send Message

    private func sendMessage() async {
        guard let uid = authManager.currentUser?.uid else { return }
        let text = messageText
        messageText = ""
        await messagesManager.sendMessage(
            conversationId: conversationId,
            senderUID: uid,
            text: text
        )
    }

    // MARK: - Helpers

    private var otherUsername: String {
        guard let uid = authManager.currentUser?.uid else { return "Chat" }
        let otherUID = conversation.participants.first(where: { $0 != uid }) ?? ""
        return conversation.participantUsernames[otherUID] ?? "Chat"
    }
}
