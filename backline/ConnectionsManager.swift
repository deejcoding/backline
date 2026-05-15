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
        throw lastError ?? NSError(domain: "ConnectionsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during retry operation"])
    }

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
                if let error {
                    blPrint("[ConnectionsManager] connections listener error: \(error)")
                    return
                }
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
                if let error {
                    blPrint("[ConnectionsManager] incoming requests listener error: \(error)")
                    return
                }
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
                if let error {
                    blPrint("[ConnectionsManager] outgoing requests listener error: \(error)")
                    return
                }
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
        // Rate limit: 10 connection requests per hour
        guard RateLimiter.shared.allow(key: "sendRequest_\(fromUID)", maxAttempts: 10, window: 3600) else {
            errorMessage = "You're sending too many requests. Please wait before trying again."
            return
        }

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
            try await withRetry { try await ref.setData(data) }
            BLAnalytics.sendConnectionRequest()
            blPrint("[ConnectionsManager] request sent successfully: \(ref.documentID)")
        } catch {
            blPrint("[ConnectionsManager] sendRequest error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(_ requestId: String) async {
        do {
            try await withRetry {
                try await self.db.collection("connectionRequests").document(requestId).updateData([
                    "status": "accepted",
                    "respondedAt": FieldValue.serverTimestamp()
                ])
            }
            BLAnalytics.acceptConnectionRequest()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rejectRequest(_ requestId: String) async {
        do {
            try await withRetry {
                try await self.db.collection("connectionRequests").document(requestId).updateData([
                    "status": "rejected",
                    "respondedAt": FieldValue.serverTimestamp()
                ])
            }
            BLAnalytics.rejectConnectionRequest()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func withdrawRequest(_ requestId: String) async {
        do {
            try await db.collection("connectionRequests").document(requestId).delete()
            BLAnalytics.withdrawConnectionRequest()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeConnection(_ requestId: String) async {
        do {
            try await db.collection("connectionRequests").document(requestId).delete()
            BLAnalytics.removeConnection()
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

    /// Cached map of uid → number of mutual connections with the current user.
    var mutualCounts: [String: Int] = [:]

    /// Precomputes mutual connection counts for all non-connected users.
    /// Call once when the feed loads; results are cached in `mutualCounts`.
    func precomputeMutualCounts(currentUID: String) async {
        let myConnectionUIDs = connections.map { $0.otherUID(currentUID: currentUID) }
        guard !myConnectionUIDs.isEmpty else {
            mutualCounts = [:]
            return
        }

        // For each of the current user's connections, fetch *their* connections
        // and tally how often each UID appears.
        var counts: [String: Int] = [:]
        await withTaskGroup(of: [String].self) { group in
            for connUID in myConnectionUIDs {
                group.addTask { [db] in
                    do {
                        let snap = try await db.collection("connectionRequests")
                            .whereField("participants", arrayContains: connUID)
                            .whereField("status", isEqualTo: "accepted")
                            .getDocuments()
                        return snap.documents.compactMap { doc -> String? in
                            guard let participants = doc.data()["participants"] as? [String] else { return nil }
                            return participants.first(where: { $0 != connUID })
                        }
                    } catch {
                        return []
                    }
                }
            }
            for await uids in group {
                for uid in uids {
                    if uid != currentUID {
                        counts[uid, default: 0] += 1
                    }
                }
            }
        }
        mutualCounts = counts
    }

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
