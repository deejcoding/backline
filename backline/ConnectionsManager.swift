//
//  ConnectionsManager.swift
//  backline
//
//  Created by Khadija Aslam on 4/21/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Models

enum ConnectionStatus: String {
    case pending, accepted, rejected
}

struct Connection: Identifiable {
    let id: String
    let fromUID: String
    let toUID: String
    let participants: [String]
    let participantUsernames: [String: String]
    let status: ConnectionStatus
    let createdAt: Date
    var respondedAt: Date?

    /// Returns the UID of the other participant given the current user's UID.
    func otherUID(currentUID: String) -> String {
        participants.first(where: { $0 != currentUID }) ?? ""
    }

    /// Returns the username of the other participant.
    func otherUsername(currentUID: String) -> String {
        let other = otherUID(currentUID: currentUID)
        return participantUsernames[other] ?? "Unknown"
    }
}

// MARK: - Manager

@Observable
final class ConnectionsManager {

    var connections: [Connection] = []       // accepted
    var incomingRequests: [Connection] = []  // pending, toUID == me
    var outgoingRequests: [Connection] = []  // pending, fromUID == me
    var errorMessage: String?

    private let db = Firestore.firestore()
    private var connectionsListener: ListenerRegistration?
    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?

    deinit {
        connectionsListener?.remove()
        incomingListener?.remove()
        outgoingListener?.remove()
    }

    // MARK: - Listeners

    func listenToConnections(forUID uid: String) {
        connectionsListener?.remove()
        connectionsListener = db.collection("connectionRequests")
            .whereField("participants", arrayContains: uid)
            .whereField("status", isEqualTo: "accepted")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.connections = documents.compactMap { Self.parseConnection($0) }
            }
    }

    func listenToIncomingRequests(forUID uid: String) {
        incomingListener?.remove()
        incomingListener = db.collection("connectionRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.incomingRequests = documents.compactMap { Self.parseConnection($0) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }

    func listenToOutgoingRequests(forUID uid: String) {
        outgoingListener?.remove()
        outgoingListener = db.collection("connectionRequests")
            .whereField("fromUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.outgoingRequests = documents.compactMap { Self.parseConnection($0) }
            }
    }

    // MARK: - Connection Status

    /// Returns the relationship status between the current user and the given UID.
    func connectionStatus(with uid: String) -> ConnectionStatusResult {
        if let conn = connections.first(where: { $0.participants.contains(uid) }) {
            return .connected(conn)
        }
        if let req = outgoingRequests.first(where: { $0.toUID == uid }) {
            return .pendingOutgoing(req)
        }
        if let req = incomingRequests.first(where: { $0.fromUID == uid }) {
            return .pendingIncoming(req)
        }
        return .none
    }

    // MARK: - Actions

    func sendRequest(
        fromUID: String,
        fromUsername: String,
        toUID: String,
        toUsername: String
    ) async {
        do {
            let ref = db.collection("connectionRequests").document()
            let data: [String: Any] = [
                "fromUID": fromUID,
                "toUID": toUID,
                "participants": [fromUID, toUID],
                "participantUsernames": [
                    fromUID: fromUsername,
                    toUID: toUsername
                ],
                "status": "pending",
                "createdAt": FieldValue.serverTimestamp()
            ]
            try await ref.setData(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(_ requestId: String) async {
        do {
            try await db.collection("connectionRequests").document(requestId).updateData([
                "status": "accepted",
                "respondedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRequest(_ requestId: String) async {
        do {
            try await db.collection("connectionRequests").document(requestId).updateData([
                "status": "rejected",
                "respondedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func withdrawRequest(_ requestId: String) async {
        do {
            try await db.collection("connectionRequests").document(requestId).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeConnection(_ requestId: String) async {
        do {
            try await db.collection("connectionRequests").document(requestId).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Remove any connection or pending request involving both UIDs (used when blocking).
    func removeAllBetween(currentUID: String, otherUID: String) async {
        do {
            let snapshot = try await db.collection("connectionRequests")
                .whereField("participants", arrayContains: currentUID)
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                if let participants = data["participants"] as? [String],
                   participants.contains(otherUID) {
                    try await doc.reference.delete()
                }
            }
        } catch {
            // Silently fail — blocking still proceeds
        }
    }

    // MARK: - Mutual Connections

    /// Fetches mutual connections between the current user and a target user.
    func fetchMutualConnections(
        currentUID: String,
        targetUID: String,
        allUsers: [UserProfile]
    ) async -> [UserProfile] {
        // Current user's connection UIDs (already loaded via listener)
        let myConnectionUIDs = Set(connections.map { $0.otherUID(currentUID: currentUID) })

        // Fetch target user's accepted connections
        do {
            let snapshot = try await db.collection("connectionRequests")
                .whereField("participants", arrayContains: targetUID)
                .whereField("status", isEqualTo: "accepted")
                .getDocuments()

            let theirConnectionUIDs = Set(snapshot.documents.compactMap { doc -> String? in
                let data = doc.data()
                guard let participants = data["participants"] as? [String] else { return nil }
                return participants.first(where: { $0 != targetUID })
            })

            let mutualUIDs = myConnectionUIDs.intersection(theirConnectionUIDs)
            return allUsers.filter { mutualUIDs.contains($0.id) }
        } catch {
            return []
        }
    }

    // MARK: - Parsing

    private static func parseConnection(_ doc: QueryDocumentSnapshot) -> Connection? {
        let data = doc.data()
        guard let fromUID = data["fromUID"] as? String,
              let toUID = data["toUID"] as? String,
              let participants = data["participants"] as? [String],
              let participantUsernames = data["participantUsernames"] as? [String: String],
              let statusRaw = data["status"] as? String,
              let status = ConnectionStatus(rawValue: statusRaw)
        else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let respondedAt = (data["respondedAt"] as? Timestamp)?.dateValue()

        return Connection(
            id: doc.documentID,
            fromUID: fromUID,
            toUID: toUID,
            participants: participants,
            participantUsernames: participantUsernames,
            status: status,
            createdAt: createdAt,
            respondedAt: respondedAt
        )
    }
}

// MARK: - Status Result

enum ConnectionStatusResult {
    case none
    case pendingOutgoing(Connection)
    case pendingIncoming(Connection)
    case connected(Connection)
}
