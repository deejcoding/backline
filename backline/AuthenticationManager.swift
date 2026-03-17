//
//  AuthenticationManager.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@Observable
final class AuthenticationManager {

    // MARK: - State

    var currentUser: User?
    var username: String?
    var profilePhotoURL: String?
    var bio: String?
    var isAuthenticated: Bool { currentUser != nil }
    var errorMessage: String?
    var isLoading = false

    private let db = Firestore.firestore()

    // MARK: - Private

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init / Deinit

    init() {
        currentUser = Auth.auth().currentUser
        listenToAuthState()
    }

    deinit {
        let handle = authStateListenerHandle
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener

    private func listenToAuthState() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            if let uid = user?.uid {
                self?.fetchUserProfile(uid: uid)
            } else {
                self?.username = nil
                self?.profilePhotoURL = nil
                self?.bio = nil
            }
        }
    }

    private func fetchUserProfile(uid: String) {
        Task {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                let data = doc.data()
                self.username = data?["username"] as? String
                self.profilePhotoURL = data?["profilePhotoURL"] as? String
                self.bio = data?["bio"] as? String
            } catch {
                // Profile fetch failed silently
            }
        }
    }

    // MARK: - Profile Updates

    func updateBio(_ bio: String) async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData(["bio": bio])
            self.bio = bio
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadProfilePhoto(imageData: Data) async {
        guard let uid = currentUser?.uid else { return }
        let storageRef = Storage.storage().reference().child("profile_photos/\(uid).jpg")
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            let url = try await storageRef.downloadURL()
            let urlString = url.absoluteString
            try await db.collection("users").document(uid).updateData(["profilePhotoURL": urlString])
            self.profilePhotoURL = urlString
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            currentUser = result.user
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Username Validation

    func isUsernameTaken(_ username: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: username.lowercased())
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil

        let trimmedUsername = username.lowercased()

        // Create account first so we have an authenticated user for Firestore
        do {
            print("[AuthManager] Attempting to create user with email: \(email)")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print("[AuthManager] User created successfully: \(result.user.uid)")

            // Check username uniqueness (now authenticated)
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: trimmedUsername)
                .getDocuments()

            if !snapshot.documents.isEmpty {
                // Username taken — delete the account we just created
                try? await result.user.delete()
                errorMessage = "That username is already taken."
                isLoading = false
                return
            }

            // Store username in Firestore
            try await db.collection("users").document(result.user.uid).setData([
                "username": trimmedUsername,
                "email": email
            ])
            self.username = trimmedUsername
            currentUser = result.user
        } catch {
            print("[AuthManager] Sign up error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Forgot Password

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = "Password reset email sent. Check your inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
