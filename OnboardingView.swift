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

    @State private var step = 0 // 0 = location, 1 = roles, 2 = genres, 3 = photo, 4 = bio
    @State private var locationDenied = false

    var body: some View {
        Group {
            switch step {
            case 0:
                OnboardingLocationStep(
                    onYes: { BLAnalytics.onboardingStep(0); step = 1 },
                    onNo: { locationDenied = true },
                    locationDenied: $locationDenied
                )
            case 1:
                OnboardingRolesStep(onContinue: { BLAnalytics.onboardingStep(1); step = 2 })
            case 2:
                OnboardingGenresStep(onContinue: { BLAnalytics.onboardingStep(2); step = 3 })
            case 3:
                OnboardingPhotoStep(onContinue: { BLAnalytics.onboardingStep(3); step = 4 })
            case 4:
                OnboardingBioStep(onComplete: {
                    BLAnalytics.onboardingComplete()
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
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(Rectangle())
                    }

                    Button {
                        onNo()
                    } label: {
                        Text("No")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .overlay(
                                Rectangle()
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
        "Mastering Engineer", "Recording Engineer", "Graphic Design",
        "Videography", "Managing", "Photography","PR", "Lessons", "Vocal Arrangement", "Beat Maker", "Social Media", "Songwriting"
    ]

    @State private var selectedRoles: [String] = []

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

                    Text("Select all that apply. The first one you pick is shown as your main skill.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(Self.allRoles, id: \.self) { role in
                            let isSelected = selectedRoles.contains(role)
                            Button {
                                if isSelected {
                                    selectedRoles.removeAll { $0 == role }
                                } else {
                                    selectedRoles.append(role)
                                }
                            } label: {
                                Text(role)
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? ThemeColor.yellow : Color.clear)
                                    .foregroundStyle(isSelected ? .black : .white)
                                    .overlay(
                                        Rectangle()
                                            .stroke(isSelected ? Color.clear : .white.opacity(0.5), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        Task {
                            await authManager.updateRoles(selectedRoles)
                            onContinue()
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white)
                            .foregroundStyle(.black)
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

// MARK: - Genres Step (Optional)

private struct OnboardingGenresStep: View {

    @Environment(AuthenticationManager.self) private var authManager

    let onContinue: () -> Void

    @State private var genres: [String] = []
    @State private var newGenre = ""

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

                    Text("What genres are you into?")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Add genres you play or listen to.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Add a genre (e.g. slowcore)", text: $newGenre)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit { addGenre() }

                        Button {
                            addGenre()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(ThemeColor.cyan)
                        }
                        .disabled(newGenre.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)

                    if !genres.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(genres, id: \.self) { genre in
                                HStack(spacing: 4) {
                                    Text("#\(genre)")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    Button {
                                        genres.removeAll { $0 == genre }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(ThemeColor.cyan.opacity(0.15))
                                .foregroundStyle(ThemeColor.cyan)
                                .clipShape(Rectangle())
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button {
                        Task {
                            if !genres.isEmpty {
                                await authManager.updateGenres(genres)
                            }
                            onContinue()
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(Rectangle())
                    }
                    .disabled(genres.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func addGenre() {
        let trimmed = newGenre.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !trimmed.isEmpty, !genres.contains(trimmed) else { return }
        genres.append(trimmed)
        newGenre = ""
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
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Rectangle())
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
                    Task.detached(priority: .userInitiated) {
                        guard let data = try? await newItem.loadTransferable(type: Data.self),
                              let uiImage = UIImage(data: data) else {
                            await MainActor.run { isUploading = false }
                            return
                        }
                        // Downscale to a reasonable upload size
                        let maxDimension: CGFloat = 800
                        let downsized: UIImage = {
                            let size = uiImage.size
                            if max(size.width, size.height) <= maxDimension { return uiImage }
                            let ratio = maxDimension / max(size.width, size.height)
                            let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)
                            return uiImage.preparingThumbnail(of: targetSize) ?? uiImage
                        }()
                        if let jpegData = downsized.jpegData(compressionQuality: 0.8) {
                            await authManager.uploadProfilePhoto(imageData: jpegData)
                        }
                        await MainActor.run {
                            selectedPhoto = nil
                            isUploading = false
                        }
                    }
                }

                if isUploading {
                    ProgressView("Uploading...")
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white)
                        .foregroundStyle(.black)
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

            VStack(spacing: 20) {
                Text("Write a Short Bio")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("Tell other musicians a bit about yourself and your experience.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $bioText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(height: 100)
                    .padding(8)
                    .overlay(
                        Rectangle()
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
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(Rectangle())
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }
}
