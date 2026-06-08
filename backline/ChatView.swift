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
    @Environment(NetworkMonitor.self) private var networkMonitor

    let conversationId: String
    let conversation: Conversation

    @State private var messageText = ""
    @State private var contactInfoWarning: String?
    @State private var keyboardVisible = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(messagesManager.messages.enumerated()), id: \.element.id) { index, message in
                            if shouldShowDateHeader(for: index) {
                                dateHeader(for: message.sentAt)
                            }
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

            if let warning = contactInfoWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 6)
            }

            if let error = messagesManager.errorMessage {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ThemeColor.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

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
                            : ThemeColor.blue
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !networkMonitor.isConnected)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .padding(.bottom, keyboardVisible ? 4 : 80)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationLink(value: ProfileDestination(uid: otherUID, username: otherUsername)) {
                    Text(otherUsername)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .navigationDestination(for: ProfileDestination.self) { dest in
            PublicProfileView(uid: dest.uid, username: dest.username)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .task {
            messagesManager.listenToMessages(conversationId: conversationId)
            if let uid = authManager.currentUser?.uid {
                await messagesManager.markAsRead(conversationId: conversationId, uid: uid)
            }
        }
        .onDisappear {
            messagesManager.stopListeningToMessages()
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: Message) -> some View {
        let isCurrentUser = message.senderUID == authManager.currentUser?.uid

        return HStack {
            if isCurrentUser { Spacer(minLength: 50) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? ThemeColor.blue : Color(.systemGray5))
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.sentAt, format: .dateTime.hour().minute())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 4)
            }

            if !isCurrentUser { Spacer(minLength: 50) }
        }
    }

    // MARK: - Send Message

    private func sendMessage() async {
        guard let uid = authManager.currentUser?.uid else { return }

        if ProfanityFilter.containsProfanity(messageText) {
            contactInfoWarning = "Your message contains inappropriate language. Please revise and try again."
            return
        }
        contactInfoWarning = nil

        let text = messageText
        messageText = ""
        await messagesManager.sendMessage(
            conversationId: conversationId,
            senderUID: uid,
            text: text
        )
    }

    // MARK: - Helpers

    private var otherUID: String {
        guard let uid = authManager.currentUser?.uid else { return "" }
        return conversation.participants.first(where: { $0 != uid }) ?? ""
    }

    private var otherUsername: String {
        conversation.participantUsernames[otherUID] ?? "Chat"
    }

    // MARK: - Date Separators

    private func shouldShowDateHeader(for index: Int) -> Bool {
        guard index >= 0, index < messagesManager.messages.count else { return false }
        if index == 0 { return true }
        let current = messagesManager.messages[index].sentAt
        let previous = messagesManager.messages[index - 1].sentAt
        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }

    private func dateHeader(for date: Date) -> some View {
        Text(dateLabel(for: date))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }

    private func dateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInYesterday(date) {
            return "YESTERDAY"
        } else if calendar.isDate(date, equalTo: .now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date).uppercased()
        } else if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date).uppercased()
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date).uppercased()
        }
    }
}
