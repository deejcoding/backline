//
//  LoginView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {

    @Environment(AuthenticationManager.self) private var authManager

    @State private var emailOrUsername = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPasswordAlert = false
    @State private var forgotPasswordEmail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer()
                    .frame(height: 60)

                Text("Backline")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    TextField("Email or username", text: $emailOrUsername)
                        .font(.system(size: 12, design: .monospaced))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .overlay(
                            Rectangle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )

                    SecureField("Password", text: $password)
                        .font(.system(size: 12, design: .monospaced))
                        .textContentType(.password)
                        .padding(10)
                        .overlay(
                            Rectangle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await authManager.signIn(emailOrUsername: emailOrUsername, password: password)
                    }
                } label: {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(Rectangle())
                }
                .disabled(authManager.isLoading || emailOrUsername.isEmpty || password.isEmpty)
                .padding(.horizontal)

                Button("Forgot Password?") {
                    forgotPasswordEmail = emailOrUsername.contains("@") ? emailOrUsername : ""
                    showForgotPasswordAlert = true
                }
                .font(.footnote)

                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color(.systemGray3))
                    Text("or")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color(.systemGray3))
                }
                .padding(.horizontal)

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = authManager.prepareAppleSignInNonce()
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            await authManager.signInWithApple(authorization: authorization)
                        }
                    case .failure(let error):
                        if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                            authManager.errorMessage = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 40)
                .padding(.horizontal)

                // Sign in with Google
                Button {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 12))
                        Text("Sign in with Google")
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .disabled(authManager.isLoading)
                .padding(.horizontal)

                Spacer()
                    .frame(height: 40)

                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign up with email") {
                        showSignUp = true
                    }
                    .fontWeight(.medium)
                }
                .font(.caption)

                Button {
                    authManager.enterGuestMode()
                } label: {
                    Text("Browse as Guest")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom)
            }
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .alert("Reset Password", isPresented: $showForgotPasswordAlert) {
            TextField("Email", text: $forgotPasswordEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Send Reset Email") {
                Task {
                    await authManager.resetPassword(email: forgotPasswordEmail)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your email address and we'll send you a link to reset your password.")
        }
    }
}
