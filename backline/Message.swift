//
//  Message.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import Foundation

// MARK: - Conversation

struct Conversation: Identifiable, Codable {
    var id: String
    var participants: [String]
    var participantUsernames: [String: String]
    var lastMessage: String
    var lastMessageAt: Date
    var lastMessageSenderUID: String
    var lastReadAt: [String: Date]

    func isUnread(forUID uid: String) -> Bool {
        // Unread if: there's a message, the last message wasn't sent by us,
        // and we either have no lastReadAt or it's before lastMessageAt
        guard !lastMessage.isEmpty, lastMessageSenderUID != uid else { return false }
        guard let readDate = lastReadAt[uid] else { return true }
        return lastMessageAt > readDate
    }
}

// MARK: - Message

struct Message: Identifiable, Codable {
    var id: String
    var senderUID: String
    var text: String
    var sentAt: Date
}
