//
//  MessagesManager.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import Foundation
import FirebaseFirestore

@Observable
final class MessagesManager {

    // MARK: - State

    var conversations: [Conversation] = []
    var messages: [Message] = []
    var errorMessage: String?

    private let db = Firestore.firestore()

    // MARK: - Retry Helper

    private func withRetry<T>(maxAttempts: Int = 3, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }
        throw lastError ?? NSError(domain: "MessagesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during retry operation"])
    }

    // MARK: - Listeners

    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?

    deinit {
        conversationsListener?.remove()
        messagesListener?.remove()
    }

    // MARK: - Listen to Conversations

    func listenToConversations(forUID uid: String) {
        conversationsListener?.remove()
        conversationsListener = db.collection("conversations")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.conversations = documents.compactMap { doc in
                    let data = doc.data()
                    guard let participants = data["participants"] as? [String],
                          let participantUsernames = data["participantUsernames"] as? [String: String],
                          let lastMessage = data["lastMessage"] as? String,
                          let lastMessageSenderUID = data["lastMessageSenderUID"] as? String
                    else { return nil }
                    let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date()

                    var lastReadAt: [String: Date] = [:]
                    if let readMap = data["lastReadAt"] as? [String: Timestamp] {
                        for (uid, timestamp) in readMap {
                            lastReadAt[uid] = timestamp.dateValue()
                        }
                    }

                    return Conversation(
                        id: doc.documentID,
                        participants: participants,
                        participantUsernames: participantUsernames,
                        lastMessage: lastMessage,
                        lastMessageAt: lastMessageAt,
                        lastMessageSenderUID: lastMessageSenderUID,
                        lastReadAt: lastReadAt
                    )
                }
            }
    }

    // MARK: - Unread Count

    func unreadCount(forUID uid: String) -> Int {
        conversations.filter { $0.isUnread(forUID: uid) }.count
    }

    // MARK: - Mark as Read

    func markAsRead(conversationId: String, uid: String) async {
        do {
            try await db.collection("conversations")
                .document(conversationId)
                .updateData([
                    "lastReadAt.\(uid)": FieldValue.serverTimestamp()
                ])
        } catch {
            // Silently fail
        }
    }

    // MARK: - Listen to Messages

    func listenToMessages(conversationId: String) {
        messagesListener?.remove()
        messages = []
        messagesListener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "sentAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.messages = documents.compactMap { doc in
                    let data = doc.data()
                    guard let senderUID = data["senderUID"] as? String,
                          let text = data["text"] as? String
                    else { return nil }
                    let sentAt = (data["sentAt"] as? Timestamp)?.dateValue() ?? Date()
                    return Message(
                        id: doc.documentID,
                        senderUID: senderUID,
                        text: text,
                        sentAt: sentAt
                    )
                }
            }
    }

    func stopListeningToMessages() {
        messagesListener?.remove()
        messagesListener = nil
        messages = []
    }

    // MARK: - Start or Open Conversation

    func startConversation(
        currentUID: String,
        currentUsername: String,
        otherUID: String,
        otherUsername: String,
        initialMessage: String? = nil
    ) async -> String? {
        do {
            var conversationId: String?
            let snapshot = try await db.collection("conversations")
                .whereField("participants", arrayContains: currentUID)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                if let participants = data["participants"] as? [String],
                   participants.contains(otherUID) {
                    conversationId = doc.documentID
                    break
                }
            }

            if conversationId == nil {
                // No existing conversation — create a new one
                let conversationRef = db.collection("conversations").document()
                let data: [String: Any] = [
                    "participants": [currentUID, otherUID],
                    "participantUsernames": [
                        currentUID: currentUsername,
                        otherUID: otherUsername
                    ],
                    "lastMessage": "",
                    "lastMessageAt": FieldValue.serverTimestamp(),
                    "lastMessageSenderUID": "",
                    "lastReadAt": [
                        currentUID: FieldValue.serverTimestamp(),
                        otherUID: FieldValue.serverTimestamp()
                    ]
                ]
                try await withRetry { try await conversationRef.setData(data) }
                BLAnalytics.startConversation()
                conversationId = conversationRef.documentID
            }

            if let conversationId, let initialMessage {
                await sendMessage(conversationId: conversationId, senderUID: currentUID, text: initialMessage)
            }

            return conversationId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Send Message

    func sendMessage(
        conversationId: String,
        senderUID: String,
        text: String
    ) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Rate limit: 20 messages per 30 seconds
        guard RateLimiter.shared.allow(key: "sendMessage_\(senderUID)", maxAttempts: 20, window: 30) else {
            errorMessage = "You're sending messages too fast. Please wait a moment."
            return
        }

        do {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document()
            let messageData: [String: Any] = [
                "senderUID": senderUID,
                "text": trimmedText,
                "sentAt": FieldValue.serverTimestamp()
            ]
            try await withRetry {
                try await messageRef.setData(messageData)
            }

            try await withRetry {
                try await self.db.collection("conversations")
                    .document(conversationId)
                    .updateData([
                        "lastMessage": trimmedText,
                        "lastMessageAt": FieldValue.serverTimestamp(),
                        "lastMessageSenderUID": senderUID
                    ])
            }
            BLAnalytics.sendMessage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
