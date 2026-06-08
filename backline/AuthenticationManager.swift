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
import FirebaseMessaging
import FirebaseCrashlytics
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
    var displayName: String?
    var profilePhotoURL: String?
    var bio: String?
    var instagramHandle: String?
    var musicProjects: [MusicProject] = []
    var featuredProjects: [SpotifyTrack] = []
    var genres: [String] = []
    var roles: [String] = []
    var neighborhood: String?
    var blockedUsers: [String] = []
    var referralCode: String?
    var allowMessagesFrom: String = "anyone" // "anyone" or "connections"
    var isGuestMode = false
    var isAuthenticated: Bool { currentUser != nil }
    var isEmailVerified: Bool { currentUser?.isEmailVerified ?? false }
    var needsUsername = false
    var needsReferralCode = false
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

    /// Profile completeness percentage (0–100).
    /// +25% photo, +20% bio, +15% music, +15% skills, +15% genres, +10% neighborhood.
    var profileCompleteness: Int {
        var score = 0
        if profilePhotoURL != nil { score += 25 }
        if let bio, !bio.isEmpty { score += 20 }
        if !musicProjects.isEmpty || !featuredProjects.isEmpty { score += 15 }
        if !roles.isEmpty { score += 15 }
        if !genres.isEmpty { score += 15 }
        if let neighborhood, !neighborhood.isEmpty { score += 10 }
        return score
    }

    /// `true` when the user's profile is complete enough to message / connect (≥ 80%).
    var canInteract: Bool { profileCompleteness >= 80 }

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
        throw lastError ?? NSError(domain: "AuthenticationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error during retry operation"])
    }

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
            Crashlytics.crashlytics().setUserID(user?.uid ?? "")
            if let uid = user?.uid {
                self?.fetchUserProfile(uid: uid)
            } else {
                self?.username = nil
                self?.displayName = nil
                self?.profilePhotoURL = nil
                self?.bio = nil
                self?.instagramHandle = nil
                self?.musicProjects = []
                self?.featuredProjects = []
                self?.genres = []
                self?.roles = []
                self?.blockedUsers = []
                self?.allowMessagesFrom = "anyone"
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
                self.displayName = data?["displayName"] as? String
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
                        return MusicProject(id: id, title: title, url: url, platform: platform, thumbnailURL: dict["thumbnailURL"])
                    }
                } else {
                    self.musicProjects = []
                }

                if let projectDictsRaw = data?["featuredProjects"] as? [[String: String]] {
                    self.featuredProjects = projectDictsRaw.compactMap { dict in
                        guard let id = dict["id"],
                              let name = dict["name"],
                              let artistName = dict["artistName"],
                              let albumName = dict["albumName"],
                              let externalURL = dict["externalURL"]
                        else { return nil }
                        let itemTypeRaw = dict["itemType"] ?? "track"
                        let itemType = SpotifyItemType(rawValue: itemTypeRaw) ?? .track
                        return SpotifyTrack(
                            id: id, name: name, artistName: artistName,
                            albumName: albumName,
                            albumImageURL: dict["albumImageURL"],
                            previewURL: dict["previewURL"],
                            externalURL: externalURL,
                            itemType: itemType
                        )
                    }
                } else if let songDict = data?["featuredSong"] as? [String: String],
                          let id = songDict["id"],
                          let name = songDict["name"],
                          let artistName = songDict["artistName"],
                          let albumName = songDict["albumName"],
                          let externalURL = songDict["externalURL"] {
                    // Migration: read old single featuredSong format
                    self.featuredProjects = [SpotifyTrack(
                        id: id, name: name, artistName: artistName,
                        albumName: albumName,
                        albumImageURL: songDict["albumImageURL"],
                        previewURL: songDict["previewURL"],
                        externalURL: externalURL
                    )]
                } else {
                    self.featuredProjects = []
                }

                self.genres = data?["genres"] as? [String] ?? []
                self.roles = data?["roles"] as? [String] ?? []
                self.neighborhood = data?["neighborhood"] as? String
                self.blockedUsers = data?["blockedUsers"] as? [String] ?? []
                self.referralCode = (data?["referralCode"] as? String)?.uppercased()
                self.allowMessagesFrom = data?["allowMessagesFrom"] as? String ?? "anyone"

                // Check if user needs to set a username (social sign-in without username)
                self.needsUsername = (fetchedUsername == nil || (fetchedUsername?.isEmpty ?? true)) && doc.exists

                // Handle referral code for legacy vs new users
                let hasReferralField = data?.keys.contains("referralCode") ?? false
                let onboardingComplete = data?["onboardingComplete"] as? Bool ?? false
                
                if !hasReferralField && doc.exists {
                    if !onboardingComplete {
                        // Genuinely new user (no referral, no onboarding)
                        self.needsReferralCode = true
                    } else {
                        // Legacy user (no referral, but onboarding was done)
                        // Assign code silently, don't block.
                        self.needsReferralCode = false
                        self.assignLegacyReferralCode(uid: uid)
                    }
                } else {
                    self.needsReferralCode = false
                }

                // Check if user needs onboarding (no "onboardingComplete" flag)
                if !onboardingComplete && doc.exists && !(self.needsUsername) && !(self.needsReferralCode) {
                    self.needsOnboarding = true
                } else if onboardingComplete {
                    self.needsOnboarding = false
                }

                // Ensure FCM token is up to date
                if let token = Messaging.messaging().fcmToken {
                    self.updateFCMToken(token)
                }
            } catch {
                // If profile fetch fails, assume username is missing so the user
                // is sent to UsernamePromptView instead of MainTabView.
                // A successful fetch on retry will clear this if they already have one.
                self.needsUsername = true
            }
        }
    }

    // MARK: - FCM Token

    func updateFCMToken(_ token: String) {
        guard let uid = currentUser?.uid else { return }
        db.collection("users").document(uid).setData([
            "fcmToken": token
        ], merge: true)
    }

    // MARK: - Block / Unblock

    func isBlocked(_ uid: String) -> Bool {
        blockedUsers.contains(uid)
    }

    func blockUser(_ uid: String) async {
        guard let currentUID = currentUser?.uid, uid != currentUID else { return }
        guard !blockedUsers.contains(uid) else { return }
        do {
            try await withRetry {
                try await self.db.collection("users").document(currentUID).updateData([
                    "blockedUsers": FieldValue.arrayUnion([uid])
                ])
            }
            blockedUsers.append(uid)
            BLAnalytics.blockUser()

            // Auto-report to notify developer (App Store Guideline 1.2)
            try? await db.collection("reports").addDocument(data: [
                "reporterUID": currentUID,
                "reportedUID": uid,
                "contentType": "user",
                "contentId": uid,
                "reason": "Blocked by user",
                "details": "User was blocked. This report was auto-generated.",
                "createdAt": FieldValue.serverTimestamp(),
                "autoGenerated": true
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblockUser(_ uid: String) async {
        guard let currentUID = currentUser?.uid else { return }
        do {
            try await withRetry {
                try await self.db.collection("users").document(currentUID).updateData([
                    "blockedUsers": FieldValue.arrayRemove([uid])
                ])
            }
            blockedUsers.removeAll { $0 == uid }
            BLAnalytics.unblockUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Profile Updates

    func updateBio(_ bio: String) async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await withRetry {
                try await self.db.collection("users").document(uid).updateData(["bio": bio])
            }
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
            try await withRetry {
                try await self.db.collection("users").document(uid).updateData(["profilePhotoURL": urlString])
            }
            self.profilePhotoURL = urlString
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(bio: String, displayName: String, instagramHandle: String, musicProjects: [MusicProject], genres: [String], featuredProjects: [SpotifyTrack] = []) async {
        guard let uid = currentUser?.uid else { return }
        let trimmedHandle = instagramHandle.trimmingCharacters(in: .whitespaces)
        let encodedProjects: [[String: String]] = musicProjects.map { project in
            var dict: [String: String] = [
                "id": project.id,
                "title": project.title,
                "url": project.url,
                "platform": project.platform.rawValue
            ]
            if let thumb = project.thumbnailURL { dict["thumbnailURL"] = thumb }
            return dict
        }
        do {
            let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
            var data: [String: Any] = [
                "bio": bio,
                "displayName": trimmedName,
                "musicProjects": encodedProjects,
                "genres": genres
            ]
            if trimmedHandle.isEmpty {
                data["instagramHandle"] = FieldValue.delete()
            } else {
                data["instagramHandle"] = trimmedHandle
            }
            if !featuredProjects.isEmpty {
                let encodedFeatured: [[String: String]] = featuredProjects.map { song in
                    var dict: [String: String] = [
                        "id": song.id,
                        "name": song.name,
                        "artistName": song.artistName,
                        "albumName": song.albumName,
                        "externalURL": song.externalURL,
                        "itemType": song.itemType.rawValue
                    ]
                    if let img = song.albumImageURL { dict["albumImageURL"] = img }
                    if let preview = song.previewURL { dict["previewURL"] = preview }
                    return dict
                }
                data["featuredProjects"] = encodedFeatured
                data["featuredSong"] = FieldValue.delete()
            } else {
                data["featuredProjects"] = FieldValue.delete()
                data["featuredSong"] = FieldValue.delete()
            }
            try await withRetry {
                try await self.db.collection("users").document(uid).updateData(data)
            }
            self.bio = bio
            self.displayName = trimmedName.isEmpty ? nil : trimmedName
            self.instagramHandle = trimmedHandle.isEmpty ? nil : trimmedHandle
            self.musicProjects = musicProjects
            self.featuredProjects = featuredProjects
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

    func signIn(emailOrUsername: String, password: String) async {
        isLoading = true
        errorMessage = nil

        var loginEmail = emailOrUsername.trimmingCharacters(in: .whitespaces)

        // If it doesn't look like an email, treat it as a username
        if !loginEmail.contains("@") {
            do {
                let snapshot = try await db.collection("users")
                    .whereField("username", isEqualTo: loginEmail.lowercased())
                    .getDocuments()
                guard let doc = snapshot.documents.first,
                      let email = doc.data()["email"] as? String else {
                    errorMessage = "No account found with that username."
                    isLoading = false
                    return
                }
                loginEmail = email
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                return
            }
        }

        do {
            let result = try await Auth.auth().signIn(withEmail: loginEmail, password: password)
            currentUser = result.user
            BLAnalytics.login(method: "email")
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

    // MARK: - Referral Validation

    func validateReferralCode(_ code: String) async -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        blPrint("[AuthManager] Validating referral code: '\(trimmed)'")
        guard !trimmed.isEmpty else { return false }
        
        // Hardcoded fallback codes (work even if Firestore is unreachable)
        let hardcodedCodes: Set<String> = [
            "BACKLINE2026",
            "POTLUCK2026",
        ]
        if hardcodedCodes.contains(trimmed) {
            blPrint("[AuthManager] Hardcoded master code used: \(trimmed)")
            return true
        }
        
        // Check Firestore masterCodes collection (managed via admin dashboard)
        do {
            let masterDoc = try await db.collection("masterCodes").document(trimmed).getDocument()
            if masterDoc.exists {
                let data = masterDoc.data()
                let isActive = data?["active"] as? Bool ?? true
                if isActive {
                    blPrint("[AuthManager] Firestore master code used: \(trimmed)")
                    return true
                }
            }
        } catch {
            blPrint("[AuthManager] Master codes lookup error: \(error.localizedDescription)")
        }
        
        // Check user referral codes
        do {
            let snapshot = try await db.collection("users")
                .whereField("referralCode", isEqualTo: trimmed)
                .getDocuments()
            let isValid = !snapshot.documents.isEmpty
            blPrint("[AuthManager] Validation result for \(trimmed): \(isValid) (found \(snapshot.documents.count) docs)")
            return isValid
        } catch {
            blPrint("[AuthManager] Validation error: \(error.localizedDescription)")
            return false
        }
    }

    private func generateReferralCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! }).uppercased()
    }

    private func assignLegacyReferralCode(uid: String) {
        let code = generateReferralCode()
        Task {
            do {
                try await db.collection("users").document(uid).updateData([
                    "referralCode": code
                ])
                await MainActor.run {
                    self.referralCode = code
                }
            } catch {
                blPrint("[AuthManager] Failed to assign legacy referral code: \(error)")
            }
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, username: String, referralCode: String) async {
        isLoading = true
        errorMessage = nil

        let trimmedUsername = username.lowercased()
        let trimmedReferral = referralCode.trimmingCharacters(in: .whitespaces).uppercased()

        if ProfanityFilter.containsProfanity(trimmedUsername) {
            errorMessage = "That username is not allowed."
            isLoading = false
            return
        }

        // Create account first so we have an authenticated user context for Firestore queries
        do {
            blPrint("[AuthManager] Attempting to create user with email: \(email)")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            blPrint("[AuthManager] User created successfully: \(result.user.uid)")
            
            // Now that we are authenticated, we can query Firestore (bypassing unauth blocks)
            let isReferralValid = await validateReferralCode(trimmedReferral)
            if !isReferralValid {
                blPrint("[AuthManager] Referral validation failed for '\(trimmedReferral)'. Deleting Auth account.")
                try? await result.user.delete()
                errorMessage = "Invalid referral code."
                isLoading = false
                return
            }

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

            let newUserReferral = generateReferralCode()

            // Store username in Firestore
            try await db.collection("users").document(result.user.uid).setData([
                "username": trimmedUsername,
                "email": email,
                "referralCode": newUserReferral,
                "referredBy": trimmedReferral
            ], merge: true)
            self.username = trimmedUsername
            self.referralCode = newUserReferral
            currentUser = result.user

            // Send verification email
            try await result.user.sendEmailVerification()

            BLAnalytics.signUp(method: "email")

            // Set onboarding flag after everything else to avoid race with auth listener
            self.needsOnboarding = true
        } catch {
            blPrint("[AuthManager] Sign up error: \(error)")
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
            BLAnalytics.forgotPassword()
            errorMessage = "Password reset email sent. Check your inbox and spam folder."
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign in with Apple

    func prepareAppleSignInNonce() -> String? {
        guard let nonce = randomNonceString() else {
            errorMessage = "Unable to generate secure security token. Please try again or use another sign-in method."
            return nil
        }
        currentNonce = nonce
        return sha256(nonce)
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
                try await docRef.setData(userData, merge: true)
                self.needsUsername = true
                self.needsReferralCode = true
                BLAnalytics.signUp(method: "apple")
            } else {
                BLAnalytics.login(method: "apple")
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
                ], merge: true)
                self.needsUsername = true
                self.needsReferralCode = true
                BLAnalytics.signUp(method: "google")
            } else {
                BLAnalytics.login(method: "google")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        #else
        errorMessage = "Google Sign-In is not available. Add the GoogleSignIn-iOS package to enable this feature."
        #endif
    }

    // MARK: - Set Username & Referral (for social sign-in users)

    func completeSocialRegistration(username: String, referralCode: String) async {
        guard let uid = currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        let trimmedUsername = username.lowercased()
        let trimmedReferral = referralCode.trimmingCharacters(in: .whitespaces).uppercased()

        if needsUsername && ProfanityFilter.containsProfanity(trimmedUsername) {
            errorMessage = "That username is not allowed."
            isLoading = false
            return
        }

        do {
            // Check username uniqueness if changing/setting it
            if needsUsername {
                let snapshot = try await db.collection("users")
                    .whereField("username", isEqualTo: trimmedUsername)
                    .getDocuments()

                if !snapshot.documents.isEmpty {
                    errorMessage = "That username is already taken."
                    isLoading = false
                    return
                }
            }

            // Validate referral code if needed (now that we are authenticated)
            if needsReferralCode {
                let isReferralValid = await validateReferralCode(trimmedReferral)
                if !isReferralValid {
                    errorMessage = "Invalid referral code."
                    isLoading = false
                    return
                }
            }

            var data: [String: Any] = [:]
            
            if needsUsername {
                data["username"] = trimmedUsername
                self.username = trimmedUsername
            }

            if needsReferralCode {
                let newUserReferral = generateReferralCode()
                data["referralCode"] = newUserReferral
                data["referredBy"] = trimmedReferral
                self.referralCode = newUserReferral
            }

            try await db.collection("users").document(uid).updateData(data)
            self.needsUsername = false
            self.needsReferralCode = false

            // Check if onboarding is still needed
            let doc = try await db.collection("users").document(uid).getDocument()
            let onboardingComplete = doc.data()?["onboardingComplete"] as? Bool ?? false
            self.needsOnboarding = !onboardingComplete
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Set Username (legacy fallback, redirected to completeSocialRegistration if referral needed)

    func setUsername(_ username: String) async {
        if needsReferralCode {
            // This shouldn't be called directly if referral is needed, but we handle it just in case
            // by not doing anything or showing an error.
            errorMessage = "Referral code required."
            return
        }
        await completeSocialRegistration(username: username, referralCode: "")
    }

    // MARK: - Change Username

    func updateUsername(_ newUsername: String) async -> Bool {
        guard let uid = currentUser?.uid else { return false }
        isLoading = true
        errorMessage = nil

        let trimmed = newUsername.lowercased()

        if ProfanityFilter.containsProfanity(trimmed) {
            errorMessage = "That username is not allowed."
            isLoading = false
            return false
        }

        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isEqualTo: trimmed)
                .getDocuments()

            // Make sure the only match (if any) is the current user
            let otherUsers = snapshot.documents.filter { $0.documentID != uid }
            if !otherUsers.isEmpty {
                errorMessage = "That username is already taken."
                isLoading = false
                return false
            }

            try await db.collection("users").document(uid).updateData([
                "username": trimmed
            ])
            self.username = trimmed

            // Propagate username to all denormalized copies
            await propagateUsername(uid: uid, newUsername: trimmed)

            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Username Propagation

    /// Updates the denormalized username on all listings, ISO posts, services, and conversations owned by this user.
    private func propagateUsername(uid: String, newUsername: String) async {
        // Listings: sellerUsername
        do {
            let listings = try await db.collection("listings")
                .whereField("sellerUID", isEqualTo: uid)
                .getDocuments()
            for doc in listings.documents {
                try await doc.reference.updateData(["sellerUsername": newUsername])
            }
        } catch { }

        // Service Listings: sellerUsername
        do {
            let services = try await db.collection("serviceListings")
                .whereField("sellerUID", isEqualTo: uid)
                .getDocuments()
            for doc in services.documents {
                try await doc.reference.updateData(["sellerUsername": newUsername])
            }
        } catch { }

        // ISO Posts: posterUsername
        do {
            let posts = try await db.collection("isoPosts")
                .whereField("posterUID", isEqualTo: uid)
                .getDocuments()
            for doc in posts.documents {
                try await doc.reference.updateData(["posterUsername": newUsername])
            }
        } catch { }

        // Conversations: participantUsernames map
        do {
            let conversations = try await db.collection("conversations")
                .whereField("participants", arrayContains: uid)
                .getDocuments()
            for doc in conversations.documents {
                try await doc.reference.updateData(["participantUsernames.\(uid)": newUsername])
            }
        } catch { }
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

    func updateGenres(_ genres: [String]) async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData(["genres": genres])
            self.genres = genres
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateNeighborhood(_ neighborhood: String?) async {
        guard let uid = currentUser?.uid else { return }
        do {
            if let neighborhood, !neighborhood.isEmpty {
                try await db.collection("users").document(uid).updateData(["neighborhood": neighborhood])
            } else {
                try await db.collection("users").document(uid).updateData(["neighborhood": FieldValue.delete()])
            }
            self.neighborhood = neighborhood
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMessagingPrivacy(_ value: String) async {
        guard let uid = currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData(["allowMessagesFrom": value])
            self.allowMessagesFrom = value
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

    private func randomNonceString(length: Int = 32) -> String? {
        guard length > 0 else { return nil }
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            return nil
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Guest Mode

    func enterGuestMode() {
        isGuestMode = true
    }

    func exitGuestMode() {
        isGuestMode = false
    }

    // MARK: - Sign Out

    func signOut() {
        BLAnalytics.signOut()
        isGuestMode = false
        do {
            try Auth.auth().signOut()
            needsUsername = false
            needsOnboarding = false
            onboardingStep = 0
            RateLimiter.shared.reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete Account

    /// Calls the `deleteUserAccount` Cloud Function to delete all user data
    /// (Firestore docs, Storage files, and Auth record) with admin privileges.
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw NSError(domain: "backline", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user signed in."])
        }

        BLAnalytics.deleteAccount()

        // Get the user's ID token for authentication
        let token = try await user.getIDToken()

        // Call the deleteUserAccount Cloud Function (v2 callable)
        let url = URL(string: "https://us-central1-backline-7e769.cloudfunctions.net/deleteUserAccount")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": [:]])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "backline", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error message from the response
            var message = "Failed to delete account (status \(httpResponse.statusCode))."
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                message = errorMessage
            }
            throw NSError(domain: "backline", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        // The Cloud Function already deleted the Auth record server-side,
        // so sign out locally to clear the session.
        try Auth.auth().signOut()

        // Clear local state
        await MainActor.run {
            self.currentUser = nil
            needsUsername = false
            needsOnboarding = false
            onboardingStep = 0
        }
    }
}
