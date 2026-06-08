//
//  EditProfileView.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import SwiftUI

struct EditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    // MARK: - Form State

    @State private var displayNameText = ""
    @State private var usernameText = ""
    @State private var usernameError: String?
    @State private var isUpdatingUsername = false
    @State private var bioText = ""
    @State private var instagramHandle = ""
    @State private var musicProjects: [MusicProject] = []
    @State private var genres: [String] = []
    @State private var newGenre = ""
    @State private var roles: [String] = []
    @State private var selectedNeighborhood = ""
    @State private var isSaving = false

    @State private var featuredProjects: [SpotifyTrack] = []

    private var isUsernameValid: Bool {
        let u = usernameText.trimmingCharacters(in: .whitespaces)
        return !u.isEmpty && u.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil
    }

    private var usernameChanged: Bool {
        usernameText.lowercased() != (authManager.username ?? "")
    }

    // Add project sheet
    @State private var showAddProject = false
    @State private var showSpotifySearch = false
    @State private var newProjectTitle = ""
    @State private var newProjectURL = ""
    @State private var newProjectPlatform: MusicPlatform = .spotify

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    displayNameFormSection
                    usernameFormSection
                    bioFormSection
                    rolesFormSection
                    neighborhoodFormSection
                    genresFormSection
                    musicSection
                    instagramFormSection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !networkMonitor.isConnected)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .alert("Content Warning", isPresented: .init(
                get: { profanityWarning != nil },
                set: { if !$0 { profanityWarning = nil } }
            )) {
                Button("OK") { profanityWarning = nil }
            } message: {
                Text(profanityWarning ?? "")
            }
            .onAppear {
                displayNameText = authManager.displayName ?? ""
                usernameText = authManager.username ?? ""
                bioText = authManager.bio ?? ""
                instagramHandle = authManager.instagramHandle ?? ""
                musicProjects = authManager.musicProjects
                featuredProjects = authManager.featuredProjects
                genres = authManager.genres
                roles = authManager.roles
                selectedNeighborhood = authManager.neighborhood ?? ""
            }
            .sheet(isPresented: $showAddProject) {
                addProjectSheet
            }
            .sheet(isPresented: $showSpotifySearch) {
                SpotifySearchView { track in
                    let totalCount = featuredProjects.count + musicProjects.count
                    guard totalCount < 10,
                          !featuredProjects.contains(where: { $0.id == track.id })
                    else { return }
                    featuredProjects.append(track)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .tracking(0.8)
    }

    // MARK: - Display Name

    private var displayNameFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Display Name")
            TextField("Your name", text: $displayNameText)
                .textInputAutocapitalization(.words)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Username

    private var usernameFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Username")
            HStack(spacing: 6) {
                Text("@")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("username", text: $usernameText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, design: .monospaced))

                if usernameChanged && isUsernameValid {
                    Button {
                        Task { await changeUsername() }
                    } label: {
                        if isUpdatingUsername {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Update")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(ThemeColor.cyan)
                        }
                    }
                    .disabled(isUpdatingUsername)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))

            if let error = usernameError {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
            } else if !usernameText.isEmpty && !isUsernameValid {
                Text("Letters, numbers, and underscores only.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.red)
            } else if usernameChanged && isUsernameValid {
                Text("Tap Update to save your new username.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func changeUsername() async {
        usernameError = nil
        isUpdatingUsername = true

        let trimmed = usernameText.trimmingCharacters(in: .whitespaces)

        if ProfanityFilter.containsProfanity(trimmed) {
            usernameError = "That username is not allowed."
            isUpdatingUsername = false
            return
        }

        let success = await authManager.updateUsername(trimmed)
        if !success {
            usernameError = authManager.errorMessage
        } else {
            usernameError = nil
        }
        isUpdatingUsername = false
    }

    // MARK: - Bio

    private var bioFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Bio")
            TextField("Tell us about yourself", text: $bioText, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06))
                .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Roles / Skills

    private static let roleCategories: [(name: String, roles: [String])] = [
        ("Instruments", [
            "Guitar", "Bass", "Drums", "Percussion", "Vocals", "Keyboardist", "Synth",
            "Saxophone", "Flute", "Trumpet", "Violin", "Harp", "Banjo",
            "Upright Bass", "Cello", "Mandolin", "Accordion", "Piano",
            "Clarinet", "Oboe", "Trombone", "Brass", "Ukulele"
        ]),

        ("Production", [
            "Producing", "Beat Maker", "DJ", "Vinyl DJ", "Rapper", "Electronic Artist",
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
            "Graphic Design", "Videography", "Photography", "Social Media",
            "Music Video Director", "Lighting", "Lighting Operator",
            "Motion Graphics", "Animation", "3D Design",
            "Cover Art", "Visual Branding", "Set Design", "Stylist"
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
        ])
    ]

    @State private var expandedCategories: Set<String> = []

    private var neighborhoodFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Neighborhood")
            NeighborhoodPickerView(selectedNeighborhood: $selectedNeighborhood)
        }
    }

    private var rolesFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Skills")
            VStack(spacing: 0) {
            ForEach(Self.roleCategories, id: \.name) { category in
                let selectedCount = category.roles.filter { roles.contains($0) }.count
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
                                let isSelected = roles.contains(role)
                                Button {
                                    if isSelected {
                                        roles.removeAll { $0 == role }
                                    } else {
                                        roles.append(role)
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
                                                .stroke(isSelected ? ThemeColor.yellow : Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .onAppear {
            // Auto-expand categories that have selected roles
            for category in Self.roleCategories {
                if category.roles.contains(where: { roles.contains($0) }) {
                    expandedCategories.insert(category.name)
                }
            }
        }
    }

    // MARK: - Music (Combined)

    private var totalMusicCount: Int {
        featuredProjects.count + musicProjects.count
    }

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Portfolio")

            VStack(spacing: 0) {
                if featuredProjects.isEmpty && musicProjects.isEmpty {
                    Text("Add your portfolio: links to tracks, art, or videos.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }

                // Spotify items
                ForEach(featuredProjects) { project in
                    HStack(spacing: 10) {
                        if let urlString = project.albumImageURL, let url = URL(string: urlString) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color(.systemGray5))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Rectangle())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                            Text(project.artistName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            featuredProjects.removeAll { $0.id == project.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                // Manual link items
                ForEach(musicProjects) { project in
                    HStack(spacing: 10) {
                        if let thumb = project.thumbnailURL, let url = URL(string: thumb) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color(.systemGray5))
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Rectangle())
                        } else {
                            Image(systemName: project.platform.iconName)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Rectangle())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                            Text(project.platform.rawValue)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Spacer()

                        Button {
                            musicProjects.removeAll { $0.id == project.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

                // Add buttons
                if totalMusicCount < 10 {
                    Divider().background(.white.opacity(0.08))

                    Button {
                        showSpotifySearch = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                            Text("Search Spotify")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundStyle(ThemeColor.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }

                    Button {
                        newProjectTitle = ""
                        newProjectURL = ""
                        newProjectPlatform = .other
                        fetchedThumbnailURL = nil
                        isFetchingThumbnail = false
                        showAddProject = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .font(.system(size: 12))
                            Text("Add a Link")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .foregroundStyle(ThemeColor.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(Color.white.opacity(0.06))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Genres

    private var genresFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Genres")
            HStack(spacing: 8) {
                TextField("Add a genre (e.g. slowcore)", text: $newGenre)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, design: .monospaced))
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
                        .font(.system(size: 16))
                        .foregroundStyle(ThemeColor.cyan)
                }
                .disabled(newGenre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))

            if !genres.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(genres, id: \.self) { genre in
                        HStack(spacing: 4) {
                            Text("#\(genre)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                            Button {
                                if let idx = genres.firstIndex(of: genre) {
                                    genres.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ThemeColor.cyan.opacity(0.15))
                        .foregroundStyle(ThemeColor.cyan)
                        .clipShape(Rectangle())
                    }
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

    // MARK: - Instagram

    private var instagramFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Instagram")
            HStack(spacing: 6) {
                Text("@")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("username", text: $instagramHandle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
    }

    // MARK: - Add Link Sheet

    @State private var fetchedThumbnailURL: String?
    @State private var isFetchingThumbnail = false

    private var addProjectSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $newProjectTitle)

                    TextField("URL", text: $newProjectURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: newProjectURL) { _, newValue in
                            newProjectPlatform = MusicPlatform.detect(from: newValue)
                            fetchThumbnail(from: newValue)
                        }

                    HStack {
                        Text("Platform")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(newProjectPlatform.rawValue)
                    }
                }

                if isFetchingThumbnail {
                    Section("Thumbnail") {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching thumbnail…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let thumb = fetchedThumbnailURL, let url = URL(string: thumb) {
                    Section("Thumbnail") {
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color(.systemGray5))
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Rectangle())

                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddProject = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let project = MusicProject(
                            id: UUID().uuidString,
                            title: newProjectTitle.trimmingCharacters(in: .whitespaces),
                            url: newProjectURL.trimmingCharacters(in: .whitespaces),
                            platform: newProjectPlatform,
                            thumbnailURL: fetchedThumbnailURL
                        )
                        musicProjects.append(project)
                        showAddProject = false
                    }
                    .disabled(
                        newProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        || newProjectURL.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func fetchThumbnail(from urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              trimmed.lowercased().hasPrefix("http") else {
            fetchedThumbnailURL = nil
            return
        }

        isFetchingThumbnail = true
        fetchedThumbnailURL = nil

        Task {
            let result = await OGImageFetcher.fetchOGImage(from: trimmed)
            await MainActor.run {
                // Only update if the URL hasn't changed while we were fetching
                if newProjectURL.trimmingCharacters(in: .whitespaces) == trimmed {
                    fetchedThumbnailURL = result
                    isFetchingThumbnail = false
                }
            }
        }
    }

    // MARK: - Save

    @State private var profanityWarning: String?

    private func save() async {
        profanityWarning = nil

        let fieldsToCheck = [displayNameText, bioText, instagramHandle] + genres
        if fieldsToCheck.contains(where: { ProfanityFilter.containsProfanity($0) }) {
            profanityWarning = "Your profile contains inappropriate language. Please revise and try again."
            return
        }

        isSaving = true
        await authManager.updateRoles(roles)
        await authManager.updateNeighborhood(selectedNeighborhood.isEmpty ? nil : selectedNeighborhood)
        await authManager.updateProfile(
            bio: bioText,
            displayName: displayNameText,
            instagramHandle: instagramHandle,
            musicProjects: musicProjects,
            genres: genres,
            featuredProjects: featuredProjects
        )
        isSaving = false
        BLAnalytics.editProfile()
        dismiss()
    }
}
