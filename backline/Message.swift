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
}

// MARK: - Message

struct Message: Identifiable, Codable {
    var id: String
    var senderUID: String
    var text: String
    var sentAt: Date
}
