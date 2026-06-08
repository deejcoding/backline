//
//  SignUpView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct SignUpView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var referralCode = ""
    @State private var showReferralInfo = false
    @State private var confirmedAge = false
    @State private var agreedToTerms = false

    var isUsernameValid: Bool {
        !username.isEmpty && username.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil
    }

    var isUsernameProfane: Bool {
        !username.isEmpty && ProfanityFilter.containsProfanity(username)
    }

    var isReferralValid: Bool {
        !referralCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var hasMinLength: Bool { password.count >= 8 }
    var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasLowercase: Bool { password.range(of: "[a-z]", options: .regularExpression) != nil }
    var hasNumber: Bool { password.range(of: "[0-9]", options: .regularExpression) != nil }

    var passwordIsStrong: Bool {
        hasMinLength && hasUppercase && hasLowercase && hasNumber
    }

    var formIsValid: Bool {
        isUsernameValid && !isUsernameProfane && !email.isEmpty && passwordIsStrong && passwordsMatch && isReferralValid && confirmedAge && agreedToTerms
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                Text("Create Account")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .font(.system(size: 12, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .overlay(
                            Rectangle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )

                    TextField("Email", text: $email)
                        .font(.system(size: 12, design: .monospaced))
                        .textContentType(.emailAddress)
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
                        .textContentType(.newPassword)
                        .padding(10)
                        .overlay(
                            Rectangle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )

                    SecureField("Confirm Password", text: $confirmPassword)
                        .font(.system(size: 12, design: .monospaced))
                        .textContentType(.newPassword)
                        .padding(10)
                        .overlay(
                            Rectangle()
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        )

                    HStack(spacing: 0) {
                        TextField("Referral Code", text: $referralCode)
                            .font(.system(size: 12, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .padding(10)

                        Button {
                            showReferralInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.trailing, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .overlay(
                        Rectangle()
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal)

                if !password.isEmpty && !passwordIsStrong {
                    VStack(alignment: .leading, spacing: 4) {
                        passwordReq("At least 8 characters", met: hasMinLength)
                        passwordReq("One uppercase letter", met: hasUppercase)
                        passwordReq("One lowercase letter", met: hasLowercase)
                        passwordReq("One number", met: hasNumber)
                    }
                    .padding(.horizontal)
                }

                if !username.isEmpty && !isUsernameValid {
                    Text("Username can only contain letters, numbers, and underscores.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if isUsernameProfane {
                    Text("That username is not allowed.")
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
                        await authManager.signUp(email: email, password: password, username: username, referralCode: referralCode)
                    }
                } label: {
                    Group {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Sign Up")
                        }
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(Rectangle())
                }
                .disabled(authManager.isLoading || !formIsValid)
                .padding(.horizontal)

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
            }
        }
        .alert("Referral Code", isPresented: $showReferralInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need a referral code from an existing Backline NYC member to create an account.")
        }
    }

    private func passwordReq(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark" : "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(met ? ThemeColor.green : .white.opacity(0.3))
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(met ? .white.opacity(0.7) : .white.opacity(0.3))
        }
    }
}
