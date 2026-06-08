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

    @State private var step = 0 // 0 = location, 1 = roles, 2 = neighborhood, 3 = genres, 4 = photo, 5 = bio
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
                OnboardingNeighborhoodStep(onContinue: { BLAnalytics.onboardingStep(2); step = 3 })
            case 3:
                OnboardingGenresStep(onContinue: { BLAnalytics.onboardingStep(3); step = 4 })
            case 4:
                OnboardingPhotoStep(onContinue: { BLAnalytics.onboardingStep(4); step = 5 })
            case 5:
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

// MARK: - Neighborhood Step (Optional)

private struct OnboardingNeighborhoodStep: View {

    @Environment(AuthenticationManager.self) private var authManager

    let onContinue: () -> Void

    @State private var selectedNeighborhood = ""

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

                    Text("What neighborhood are you in?")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("This helps other musicians find people near them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    NeighborhoodPickerView(selectedNeighborhood: $selectedNeighborhood)
                        .padding(.horizontal)

                    Button {
                        Task {
                            if !selectedNeighborhood.isEmpty {
                                await authManager.updateNeighborhood(selectedNeighborhood)
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
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Roles Step (Optional)

private struct OnboardingRolesStep: View {

    @Environment(AuthenticationManager.self) private var authManager

    let onContinue: () -> Void

    static let roleCategories: [(name: String, roles: [String])] = [
        ("Instruments", [
                "Guitar", "Bass", "Drums", "Percussion", "Vocals", "Keyboardist", "Synth",
                "Saxophone", "Flute", "Trumpet", "Violin", "Harp", "Banjo",
                "Upright Bass", "Cello", "Mandolin", "Accordion", "Piano",
                "Clarinet", "Oboe", "Trombone", "Brass", "Ukulele"
            ]),

            ("Production", [
                "Producing", "Beat Maker", "DJ", "Rapper", "Electronic Artist",
                "Noise Artist", "Experimental Musician",
                "Songwriting", "Lyricist", "Composer", "Topliner",
                "Vocal Arrangement", "Vocal Producer"
            ]),

            ("Engineering", [
                "Live Sound Engineering", "Front of House Engineer",
                "Monitor Engineer", "Mixing Engineer",
                "Mastering Engineer", "Recording Engineer",
                "Audio Technician", "Sound Designer", "Audio Editor",
                "MIDI Programmer"
            ]),

            ("Visual & Media", [
                "Graphic Design", "Videography", "Photography",
                "Music Video Director", "Lighting", "Lighting Operator",
                "Motion Graphics", "Animation", "3D Design",
                "Cover Art", "Visual Branding", "Set Design"
            ]),

            ("Business & Management", [
                "Managing", "Artist Management", "Tour Managing",
                "Booking", "Show Booker", "Booking Agent", "Talent Buyer",
                "Promoter", "Venue Manager", "Venue Owner",
                "Publicist", "PR", "A&R",
                "Music Attorney", "Label Owner",
                "Music Publishing", "Distribution",
                "DIY Organizer"
            ]),

            ("Services & Education", [
                "Lessons", "Music Teacher", "Vocal Coach",
                "Rehearsal Space", "Studio Rental",
                "Instrument Repair", "Amp Repair",
                "Choir Director", "Conductor",
                "Session Work"
            ]),
    ]

    @State private var selectedRoles: [String] = []
    @State private var expandedCategories: Set<String> = []

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

                    VStack(spacing: 0) {
                        ForEach(Self.roleCategories, id: \.name) { category in
                            let selectedCount = category.roles.filter { selectedRoles.contains($0) }.count
                            VStack(spacing: 0) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedCategories.contains(category.name) {
                                            expandedCategories.remove(category.name)
                                        } else {
                                            expandedCategories.insert(category.name)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white.opacity(0.4))
                                            .rotationEffect(.degrees(expandedCategories.contains(category.name) ? 90 : 0))
                                        Text(category.name)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if selectedCount > 0 {
                                            Text("\(selectedCount)")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.black)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(ThemeColor.yellow)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)

                                if expandedCategories.contains(category.name) {
                                    FlowLayout(spacing: 8) {
                                        ForEach(category.roles, id: \.self) { role in
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
                                    .padding(.bottom, 8)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
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
                            .onChange(of: newGenre) { _, newValue in
                                if newValue.contains(",") {
                                    let parts = newValue.split(separator: ",", omittingEmptySubsequences: true)
                                    for part in parts {
                                        let trimmed = part.trimmingCharacters(in: .whitespaces)
                                            .lowercased()
                                            .replacingOccurrences(of: "#", with: "")
                                            .replacingOccurrences(of: " ", with: "")
                                        if !trimmed.isEmpty, !genres.contains(trimmed) {
                                            genres.append(trimmed)
                                        }
                                    }
                                    newGenre = ""
                                }
                            }

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
