//
//  ContentView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ConnectionsManager.self) private var connectionsManager
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                // Loading screen
                ZStack {
                    Color.black.ignoresSafeArea()

                    /* Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120) */
                }
            } else if authManager.isAuthenticated && (authManager.needsUsername || authManager.needsReferralCode) {
                UsernamePromptView()
            } else if authManager.isAuthenticated && authManager.needsOnboarding {
                OnboardingView()
            } else if authManager.isAuthenticated || authManager.isGuestMode {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            // Give Firebase a moment to restore auth state
            try? await Task.sleep(for: .seconds(1))
            isCheckingAuth = false
            // Start listeners if already signed in
            if let uid = authManager.currentUser?.uid {
                messagesManager.listenToConversations(forUID: uid)
                connectionsManager.listenToConnections(forUID: uid)
                connectionsManager.listenToIncomingRequests(forUID: uid)
                connectionsManager.listenToOutgoingRequests(forUID: uid)
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth, let uid = authManager.currentUser?.uid {
                messagesManager.listenToConversations(forUID: uid)
                connectionsManager.listenToConnections(forUID: uid)
                connectionsManager.listenToIncomingRequests(forUID: uid)
                connectionsManager.listenToOutgoingRequests(forUID: uid)
            }
        }
    }
}
