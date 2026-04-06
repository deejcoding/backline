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

    // MARK: - Form State

    @State private var bioText = ""
    @State private var instagramHandle = ""
    @State private var musicProjects: [MusicProject] = []
    @State private var genres: [String] = []
    @State private var newGenre = ""
    @State private var isSaving = false

    // Add project sheet
    @State private var showAddProject = false
    @State private var newProjectTitle = ""
    @State private var newProjectURL = ""
    @State private var newProjectPlatform: MusicPlatform = .spotify

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    bioFormSection
                    genresFormSection
                    instagramFormSection
                    musicProjectsFormSection
                }
                .padding(.vertical)
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
                    .disabled(isSaving)
                }
            }
            .onAppear {
                bioText = authManager.bio ?? ""
                instagramHandle = authManager.instagramHandle ?? ""
                musicProjects = authManager.musicProjects
                genres = authManager.genres
            }
            .sheet(isPresented: $showAddProject) {
                addProjectSheet
            }
        }
    }

    // MARK: - Bio

    private var bioFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)

            TextField("Tell us about yourself", text: $bioText, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(Rectangle())
                .padding(.horizontal)
        }
    }

    // MARK: - Genres

    private var genresFormSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genres")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)

            // Input
            HStack {
                TextField("Add a genre (e.g. slowcore)", text: $newGenre)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { addGenre() }

                Button {
                    addGenre()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(newGenre.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(Rectangle())
            .padding(.horizontal)

            // Tags
            if !genres.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(genres, id: \.self) { genre in
                        HStack(spacing: 4) {
                            Text("#\(genre)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                genres.removeAll { $0 == genre }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)
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
            Text("Instagram")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)

            HStack {
                Text("@")
                    .foregroundStyle(.secondary)
                TextField("username", text: $instagramHandle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(Rectangle())
            .padding(.horizontal)
        }
    }

    // MARK: - Music Projects

    private var musicProjectsFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Music Projects")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    newProjectTitle = ""
                    newProjectURL = ""
                    newProjectPlatform = .spotify
                    showAddProject = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal)

            if musicProjects.isEmpty {
                Text("Add links to your music on Spotify, Apple Music, or YouTube.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            } else {
                ForEach(musicProjects) { project in
                    HStack {
                        Image(systemName: project.platform.iconName)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(project.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(project.platform.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            musicProjects.removeAll { $0.id == project.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Rectangle())
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Add Project Sheet

    private var addProjectSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Project Title", text: $newProjectTitle)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Rectangle())

                TextField("URL", text: $newProjectURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(Rectangle())

                HStack {
                    Text("Platform")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Platform", selection: $newProjectPlatform) {
                        ForEach(MusicPlatform.allCases, id: \.self) { platform in
                            Text(platform.rawValue).tag(platform)
                        }
                    }
                    .labelsHidden()
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(Rectangle())

                Spacer()
            }
            .padding()
            .navigationTitle("Add Music Project")
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
                            platform: newProjectPlatform
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

    // MARK: - Save

    private func save() async {
        isSaving = true
        await authManager.updateProfile(
            bio: bioText,
            instagramHandle: instagramHandle,
            musicProjects: musicProjects,
            genres: genres
        )
        isSaving = false
        dismiss()
    }
}
