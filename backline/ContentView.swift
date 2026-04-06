//
//  ContentView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @State private var isCheckingAuth = true

    var body: some View {
        Group {
            if isCheckingAuth {
                // Loading screen
                VStack {
                    Spacer()
                    Text("backline")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }
            } else if authManager.isAuthenticated && authManager.isEmailVerified {
                MainTabView()
            } else if authManager.isAuthenticated && !authManager.isEmailVerified {
                EmailVerificationView()
            } else {
                LoginView()
            }
        }
        .task {
            // Give Firebase a moment to restore auth state
            try? await Task.sleep(for: .seconds(1))
            isCheckingAuth = false
        }
    }
}
