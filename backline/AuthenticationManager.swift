//
//  AuthenticationManager.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import AuthenticationServices
import CryptoKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

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
    var roles: [String] = []
    var isAuthenticated: Bool { currentUser != nil }
    var isEmailVerified: Bool { currentUser?.isEmailVerified ?? false }
    var needsUsername = false
    var needsOnboarding = false
    var onboardingStep = 0 // 0 = location, 1 = roles, 2 = photo, 3 = bio
    var errorMessage: String?
    var isLoading = false

    var isSocialAuthUser: Bool {
        guard let providerData = currentUser?.providerData else { return false }
        return providerData.contains { $0.providerID == "apple.com" || $0.providerID == "google.com" }
    }

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
    private var currentNonce: String?

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
                self?.roles = []
                self?.needsOnboarding = false
                self?.onboardingStep = 0
            }
        }
    }

    private func fetchUserProfile(uid: String) {
        Task {
            do {
                let doc = try await db.collection("users").document(uid).getDocument()
                let data = doc.data()
                let fetchedUsername = data?["username"] as? String
                self.username = fetchedUsername
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
                self.roles = data?["roles"] as? [String] ?? []

                // Check if user needs to set a username (social sign-in without username)
                self.needsUsername = (fetchedUsername == nil || fetchedUsername!.isEmpty) && doc.exists

                // Check if user needs onboarding (no "onboardingComplete" flag)
                let onboardingComplete = data?["onboardingComplete"] as? Bool ?? false
                if !onboardingComplete && doc.exists && !(self.needsUsername) {
                    self.needsOnboarding = true
                } else if onboardingComplete {
                    self.needsOnboarding = false
                }
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

            // Set onboarding flag after everything else to avoid race with auth listener
            self.needsOnboarding = true
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

    // MARK: - Sign in with Apple

    func prepareAppleSignIn() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    func signInWithApple(authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Unable to get Apple ID credential."
            return
        }
        guard let nonce = currentNonce else {
            errorMessage = "Invalid state: no nonce found."
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to get identity token."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            let result = try await Auth.auth().signIn(with: credential)
            currentUser = result.user

            // Create Firestore user doc if it doesn't exist
            let docRef = db.collection("users").document(result.user.uid)
            let doc = try await docRef.getDocument()
            if !doc.exists {
                var userData: [String: Any] = [
                    "email": result.user.email ?? ""
                ]
                // Apple only provides the name on first sign-in
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !displayName.isEmpty {
                        userData["displayName"] = displayName
                    }
                }
                try await docRef.setData(userData)
                self.needsUsername = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign in with Google

    @MainActor
    func signInWithGoogle() async {
        #if canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In is not configured. Missing client ID."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "Unable to get root view controller."
                isLoading = false
                return
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Unable to get Google ID token."
                isLoading = false
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            currentUser = authResult.user

            // Create Firestore user doc if it doesn't exist
            let docRef = db.collection("users").document(authResult.user.uid)
            let doc = try await docRef.getDocument()
            if !doc.exists {
                try await docRef.setData([
                    "email": authResult.user.email ?? "",
                    "displayName": authResult.user.displayName ?? ""
                ])
                self.needsUsername = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        #else
        errorMessage = "Google Sign-In is not available. Add the GoogleSignIn-iOS package to enable this feature."
        #endif
    }

    // MARK: - Set Username (for social sign-in users)

    func setUsername(_ username: String) async {
        guard let uid = currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        let trimmedUsername = username.lowercased()

        do {
            // Check uniqueness
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: trimmedUsername)
                .getDocuments()

            if !snapshot.documents.isEmpty {
                errorMessage = "That username is already taken."
                isLoading = false
                return
            }

            try await db.collection("users").document(uid).updateData([
                "username": trimmedUsername
            ])
            self.username = trimmedUsername
            self.needsUsername = false
            // Check if onboarding is still needed
            let doc = try await db.collection("users").document(uid).getDocument()
            let onboardingComplete = doc.data()?["onboardingComplete"] as? Bool ?? false
            self.needsOnboarding = !onboardingComplete
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Onboarding

    func updateRoles(_ roles: [String]) async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData(["roles": roles])
            self.roles = roles
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeOnboarding() async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData(["onboardingComplete": true])
            self.needsOnboarding = false
            self.onboardingStep = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            needsUsername = false
            needsOnboarding = false
            onboardingStep = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
