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
    @State private var referralCode = ""

    var isUsernameValid: Bool {
        !username.isEmpty && username.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil
    }

    var isUsernameProfane: Bool {
        !username.isEmpty && ProfanityFilter.containsProfanity(username)
    }

    var isReferralValid: Bool {
        !referralCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 60)

                Text("Welcome to Backline")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pick a unique username and enter your referral code to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    if authManager.needsUsername {
                        TextField("Username", text: $username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())
                    }

                    if authManager.needsReferralCode {
                        TextField("Referral Code", text: $referralCode)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    if let existingUsername = authManager.username {
                        username = existingUsername
                    }
                }

                if authManager.needsUsername && !username.isEmpty && !isUsernameValid {
                    Text("Username can only contain letters, numbers, and underscores.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if authManager.needsUsername && isUsernameProfane {
                    Text("That username is not allowed.")
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
                        await authManager.completeSocialRegistration(
                            username: authManager.needsUsername ? username : (authManager.username ?? ""),
                            referralCode: referralCode
                        )
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
                    .background(ThemeColor.blue)
                    .foregroundStyle(.white)
                    .clipShape(Rectangle())
                }
                .disabled(authManager.isLoading || 
                          (authManager.needsUsername && (!isUsernameValid || isUsernameProfane)) || 
                          (authManager.needsReferralCode && !isReferralValid))
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
