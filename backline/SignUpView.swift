//
//  SignUpView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct SignUpView: View {

    @Environment(AuthenticationManager.self) private var authManager

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var isUsernameValid: Bool {
        !username.isEmpty && username.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil
    }

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var formIsValid: Bool {
        isUsernameValid && !email.isEmpty && passwordsMatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 60)

                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Username", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
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

                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords do not match.")
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
                        await authManager.signUp(email: email, password: password, username: username)
                    }
                } label: {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign Up")
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Rectangle())
                }
                .disabled(authManager.isLoading || !formIsValid)
                .padding(.horizontal)
            }
        }
    }
}
