//
//  GuestPromptView.swift
//  backline
//

import SwiftUI

/// A reusable sheet shown when a guest user tries to access an account-only feature.
/// Offers to sign in or dismiss.
struct GuestPromptView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            Text("SIGN IN REQUIRED")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(1)

            Text("Create an account or sign in to message, post, connect, and more.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                authManager.exitGuestMode()
                dismiss()
            } label: {
                Text("Sign In / Sign Up")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("Continue Browsing")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
    }
}
