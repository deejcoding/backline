//
//  ContentView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct ContentView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @State private var showLogin = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else if showLogin {
                LoginView()
            } else {
                welcomeView
            }
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("myLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .clipShape(Rectangle())

            Text("Welcome to Backline.")
                .font(.title)
                .fontWeight(.semibold)

            Button {
                showLogin = true
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Rectangle())
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

