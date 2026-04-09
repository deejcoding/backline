//
//  EmailVerificationView.swift
//  backline
//
//  Created by Khadija Aslam on 4/3/26.
//

import SwiftUI

struct EmailVerificationView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @State private var isChecking = false
    @State private var showResendConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 56))
                .foregroundStyle(ThemeColor.blue)

            Text("Verify Your Email")
                .font(.title2)
                .fontWeight(.bold)

            Text("We sent a verification link to your email. Tap the link, then come back and press the button below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Check verification button
            Button {
                Task {
                    isChecking = true
                    await authManager.reloadUser()
                    isChecking = false
                }
            } label: {
                Group {
                    if isChecking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("I've Verified My Email")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(ThemeColor.blue)
                .foregroundStyle(.white)
                .clipShape(Rectangle())
            }
            .disabled(isChecking)
            .padding(.horizontal)

            // Resend
            Button("Resend Verification Email") {
                Task {
                    await authManager.sendVerificationEmail()
                    showResendConfirmation = true
                }
            }
            .font(.subheadline)

            Spacer()

            // Sign out option
            Button("Sign Out") {
                authManager.signOut()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .alert("Email Sent", isPresented: $showResendConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("A new verification email has been sent. Check your inbox.")
        }
    }
}
