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
            Form {
                displayNameFormSection
                usernameFormSection
                bioFormSection
                rolesFormSection
                genresFormSection
                musicSection
                instagramFormSection
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

    // MARK: - Display Name

    private var displayNameFormSection: some View {
        Section("Display Name") {
            TextField("Your name", text: $displayNameText)
                .textInputAutocapitalization(.words)
        }
    }

    // MARK: - Username

    private var usernameFormSection: some View {
        Section("Username") {
            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("username", text: $usernameText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if usernameChanged && isUsernameValid {
                    Button {
                        Task { await changeUsername() }
                    } label: {
                        if isUpdatingUsername {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Update")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(ThemeColor.blue)
                        }
                    }
                    .disabled(isUpdatingUsername)
                }
            }

            if let error = usernameError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !usernameText.isEmpty && !isUsernameValid {
                Text("Username can only contain letters, numbers, and underscores.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if usernameChanged && isUsernameValid {
                Text("Tap Update to save your new username.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        Section("Bio") {
            TextField("Tell us about yourself", text: $bioText, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Roles / Skills

    private static let allRoles = [
        "Guitar", "Vocals", "Keyboardist", "Synth", "Woodwinds",
        "Strings", "Brass", "Bass", "Drums", "Producing",
        "Rapper", "DJ", "Live Sound Engineering", "Mixing Engineer",
        "Mastering Engineer", "Recording Engineer", "Graphic Design",
        "Videography", "Managing", "Photography", "PR", "Lessons",
        "Vocal Arrangement", "Beat Maker", "Social Media", "Songwriting"
    ]

    private var rolesFormSection: some View {
        Section("Skills") {
            FlowLayout(spacing: 8) {
                ForEach(Self.allRoles, id: \.self) { role in
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
        }
    }

    // MARK: - Music (Combined)

    private var totalMusicCount: Int {
        featuredProjects.count + musicProjects.count
    }

    private var musicSection: some View {
        Section("Portfolio") {
            if featuredProjects.isEmpty && musicProjects.isEmpty {
                Text("Add your portfolio: links to tracks, art, or videos.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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
                        .frame(width: 44, height: 44)
                        .clipShape(Rectangle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(project.artistName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        featuredProjects.removeAll { $0.id == project.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
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
                        .frame(width: 44, height: 44)
                        .clipShape(Rectangle())
                    } else {
                        Image(systemName: project.platform.iconName)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray5))
                            .clipShape(Rectangle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(project.platform.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        musicProjects.removeAll { $0.id == project.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Add buttons
            if totalMusicCount < 10 {
                Button {
                    showSpotifySearch = true
                } label: {
                    Label("Search Spotify", systemImage: "music.note")
                }

                Button {
                    newProjectTitle = ""
                    newProjectURL = ""
                    newProjectPlatform = .other
                    fetchedThumbnailURL = nil
                    isFetchingThumbnail = false
                    showAddProject = true
                } label: {
                    Label("Add a Link", systemImage: "link")
                }
            }
        }
    }

    // MARK: - Genres

    private var genresFormSection: some View {
        Section("Genres") {
            HStack {
                TextField("Add a genre (e.g. slowcore)", text: $newGenre)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { addGenre() }

                Button {
                    addGenre()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(ThemeColor.blue)
                }
                .disabled(newGenre.trimmingCharacters(in: .whitespaces).isEmpty)
            }

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
                        .background(Color.cyan.opacity(0.15))
                        .foregroundStyle(Color.cyan)
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
        Section("Instagram") {
            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("username", text: $instagramHandle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
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
