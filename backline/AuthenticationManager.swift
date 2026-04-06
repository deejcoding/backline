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
    var instagramHandle: String?
    var musicProjects: [MusicProject] = []
    var genres: [String] = []
    var isAuthenticated: Bool { currentUser != nil }
    var isEmailVerified: Bool { currentUser?.isEmailVerified ?? false }
    var errorMessage: String?
    var isLoading = false

    var profileScore: Int {
        var score = 0
        if let url = profilePhotoURL, !url.isEmpty { score += 10 }
        if let bio, !bio.isEmpty { score += 10 }
        score += musicProjects.count * 15
        if let instagramHandle, !instagramHandle.isEmpty { score += 10 }
        return score
    }

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
                self?.instagramHandle = nil
                self?.musicProjects = []
                self?.genres = []
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
                self.instagramHandle = data?["instagramHandle"] as? String

                if let projectDicts = data?["musicProjects"] as? [[String: String]] {
                    self.musicProjects = projectDicts.compactMap { dict in
                        guard let id = dict["id"],
                              let title = dict["title"],
                              let url = dict["url"],
                              let platformRaw = dict["platform"],
                              let platform = MusicPlatform(rawValue: platformRaw)
                        else { return nil }
                        return MusicProject(id: id, title: title, url: url, platform: platform)
                    }
                } else {
                    self.musicProjects = []
                }

                self.genres = data?["genres"] as? [String] ?? []
            } catch {
                // Profile fetch failed silently
            }
        }
    }

    // MARK: - FCM Token

    func updateFCMToken(_ token: String) {
        guard let uid = currentUser?.uid else { return }
        db.collection("users").document(uid).updateData([
            "fcmToken": token
        ])
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

    func updateProfile(bio: String, instagramHandle: String, musicProjects: [MusicProject], genres: [String]) async {
        guard let uid = currentUser?.uid else { return }
        let trimmedHandle = instagramHandle.trimmingCharacters(in: .whitespaces)
        let encodedProjects: [[String: String]] = musicProjects.map { project in
            [
                "id": project.id,
                "title": project.title,
                "url": project.url,
                "platform": project.platform.rawValue
            ]
        }
        do {
            var data: [String: Any] = [
                "bio": bio,
                "musicProjects": encodedProjects,
                "genres": genres
            ]
            if trimmedHandle.isEmpty {
                data["instagramHandle"] = FieldValue.delete()
            } else {
                data["instagramHandle"] = trimmedHandle
            }
            try await db.collection("users").document(uid).updateData(data)
            self.bio = bio
            self.instagramHandle = trimmedHandle.isEmpty ? nil : trimmedHandle
            self.musicProjects = musicProjects
            self.genres = genres
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Email Verification

    func sendVerificationEmail() async {
        do {
            try await currentUser?.sendEmailVerification()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadUser() async {
        do {
            try await currentUser?.reload()
            currentUser = Auth.auth().currentUser
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

            // Send verification email
            try await result.user.sendEmailVerification()
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
