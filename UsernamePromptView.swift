//
//  UsernamePromptView.swift
//  backline
//
//  Created by Khadija Aslam on 4/7/26.
//

import SwiftUI

struct UsernamePromptView: View {

    @Environment(AuthenticationManager.self) private var authManager

    @State private var username = ""

    var isUsernameValid: Bool {
        !username.isEmpty && username.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 60)

                Text("Choose a Username")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pick a unique username for your Backline profile.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())
                }
                .padding(.horizontal)

                if !username.isEmpty && !isUsernameValid {
                    Text("Username can only contain letters, numbers, and underscores.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await authManager.setUsername(username)
                    }
                } label: {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Rectangle())
                }
                .disabled(authManager.isLoading || !isUsernameValid)
                .padding(.horizontal)

                Button("Sign Out") {
                    authManager.signOut()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
