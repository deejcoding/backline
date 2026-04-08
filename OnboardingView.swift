//
//  OnboardingView.swift
//  backline
//
//  Created by Khadija Aslam on 4/7/26.
//

import SwiftUI
import PhotosUI

struct OnboardingView: View {

    @Environment(AuthenticationManager.self) private var authManager

    @State private var step = 0 // 0 = location, 1 = roles, 2 = photo, 3 = bio
    @State private var locationDenied = false

    var body: some View {
        Group {
            switch step {
            case 0:
                OnboardingLocationStep(
                    onYes: { step = 1 },
                    onNo: { locationDenied = true },
                    locationDenied: $locationDenied
                )
            case 1:
                OnboardingRolesStep(onContinue: { step = 2 })
            case 2:
                OnboardingPhotoStep(onContinue: { step = 3 })
            case 3:
                OnboardingBioStep(onComplete: {
                    Task { await authManager.completeOnboarding() }
                })
            default:
                ProgressView()
            }
        }
    }
}

// MARK: - Location Step (Mandatory)

private struct OnboardingLocationStep: View {

    let onYes: () -> Void
    let onNo: () -> Void
    @Binding var locationDenied: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Are you located in NYC?")
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if locationDenied {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sorry, backline is not available in your area yet. Stay tuned for updates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 10) {
                    Button {
                        onYes()
                    } label: {
                        Text("Yes")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        onNo()
                    } label: {
                        Text("No")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}

// MARK: - Roles Step (Optional)

private struct OnboardingRolesStep: View {

    @Environment(AuthenticationManager.self) private var authManager

    let onContinue: () -> Void

    static let allRoles = [
        "Guitar", "Vocals", "Keyboardist", "Synth", "Woodwinds",
        "Strings", "Brass", "Bass", "Drums", "Producing",
        "Rapper", "DJ", "Live Sound Engineering", "Mixing Engineer",
        "Mastering Engineer", "Recording Engineer", "Graphic Design"
    ]

    @State private var selectedRoles: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Do this later") {
                    onContinue()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 16)

                    Text("What do you do?")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Select all that apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(Self.allRoles, id: \.self) { role in
                            Button {
                                if selectedRoles.contains(role) {
                                    selectedRoles.remove(role)
                                } else {
                                    selectedRoles.insert(role)
                                }
                            } label: {
                                Text(role)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedRoles.contains(role) ? Color.accentColor : Color.accentColor.opacity(0.15))
                                    .foregroundStyle(selectedRoles.contains(role) ? .white : Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        Task {
                            await authManager.updateRoles(Array(selectedRoles))
                            onContinue()
                        }
                    } label: {
                        Text("Continue")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(selectedRoles.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Photo Step (Optional)

private struct OnboardingPhotoStep: View {

    @Environment(AuthenticationManager.self) private var authManager

    let onContinue: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Do this later") {
                    onContinue()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                Text("Add a Profile Picture")
                    .font(.title3)
                    .fontWeight(.bold)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    if let urlString = authManager.profilePhotoURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("Tap to choose a photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let newItem else { return }
                    isUploading = true
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data),
                           let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                            await authManager.uploadProfilePhoto(imageData: jpegData)
                        }
                        isUploading = false
                    }
                }

                if isUploading {
                    ProgressView("Uploading...")
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}

// MARK: - Bio Step (Optional)

private struct OnboardingBioStep: View {

    @Environment(AuthenticationManager.self) private var authManager

    let onComplete: () -> Void

    @State private var bioText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Do this later") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                Text("Write a Short Bio")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Tell other musicians a bit about yourself and your experience.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $bioText)
                    .font(.caption)
                    .frame(height: 100)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .padding(.horizontal)

                Button {
                    Task {
                        if !bioText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            await authManager.updateBio(bioText.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        onComplete()
                    }
                } label: {
                    Text("Finish")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}
