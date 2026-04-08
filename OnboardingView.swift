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
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            if locationDenied {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Sorry, backline is not available in your area yet. Stay tuned for updates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        onYes()
                    } label: {
                        Text("Yes")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Rectangle())
                    }

                    Button {
                        onNo()
                    } label: {
                        Text("No")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(Rectangle())
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
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 20)

                    Text("What do you do?")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Select all that apply.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 10) {
                        ForEach(Self.allRoles, id: \.self) { role in
                            Button {
                                if selectedRoles.contains(role) {
                                    selectedRoles.remove(role)
                                } else {
                                    selectedRoles.insert(role)
                                }
                            } label: {
                                Text(role)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(selectedRoles.contains(role) ? Color.accentColor : Color(.systemGray5))
                                    .foregroundStyle(selectedRoles.contains(role) ? .white : .primary)
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
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Rectangle())
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

            VStack(spacing: 24) {
                Text("Add a Profile Picture")
                    .font(.title)
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
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(Color.accentColor)
                            Text("Tap to choose a photo")
                                .font(.subheadline)
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
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
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

            VStack(spacing: 24) {
                Text("Write a Short Bio")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Tell other musicians a bit about yourself.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $bioText)
                    .frame(height: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}
