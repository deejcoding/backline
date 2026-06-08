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
    @State private var confirmedAge = false
    @State private var agreedToTerms = false

    var canSubmit: Bool {
        !emailOrUsername.isEmpty && !password.isEmpty && confirmedAge && agreedToTerms
    }

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

                // Legal links
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        confirmedAge.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: confirmedAge ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16))
                                .foregroundStyle(confirmedAge ? ThemeColor.cyan : .white.opacity(0.4))
                            Text("I confirm that I am 18 years or older")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(alignment: .top, spacing: 8) {
                        Button {
                            agreedToTerms.toggle()
                        } label: {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .font(.system(size: 16))
                                .foregroundStyle(agreedToTerms ? ThemeColor.cyan : .white.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("I agree to the")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .onTapGesture { agreedToTerms.toggle() }
                            HStack(spacing: 4) {
                                Link("Terms of Service & EULA", destination: URL(string: "https://backlinenyc.com/terms.html")!)
                                Text("and")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .onTapGesture { agreedToTerms.toggle() }
                                Link("Privacy Policy", destination: URL(string: "https://backlinenyc.com/privacy.html")!)
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .tint(.white.opacity(0.9))
                            .underline()
                        }
                    }
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
                .disabled(authManager.isLoading || !canSubmit)
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

                if !confirmedAge || !agreedToTerms {
                    Text("Check both boxes above to enable Apple / Google sign in")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

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
                .disabled(!confirmedAge || !agreedToTerms)
                .opacity(confirmedAge && agreedToTerms ? 1.0 : 0.5)

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
                .disabled(authManager.isLoading || !confirmedAge || !agreedToTerms)
                .opacity(confirmedAge && agreedToTerms ? 1.0 : 0.5)
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
