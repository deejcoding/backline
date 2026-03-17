//
//  LoginView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct LoginView: View {

    @Environment(AuthenticationManager.self) private var authManager

    @State private var email = ""
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
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())
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
                        await authManager.signIn(email: email, password: password)
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
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Rectangle())
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal)

                Button("Forgot Password?") {
                    forgotPasswordEmail = email
                    showForgotPasswordAlert = true
                }
                .font(.footnote)

                Spacer()
                    .frame(height: 40)

                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign Up") {
                        showSignUp = true
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
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
