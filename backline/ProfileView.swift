//
//  ProfileView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct ProfileView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEditingBio = false
    @State private var bioText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                // Profile photo
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
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data),
                           let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                            await authManager.uploadProfilePhoto(imageData: jpegData)
                        }
                    }
                }

                // Username
                if let username = authManager.username {
                    Text("@\(username)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                // Bio
                if let bio = authManager.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    Text("Add a bio")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Button("Edit Profile") {
                    bioText = authManager.bio ?? ""
                    isEditingBio = true
                }
                .font(.subheadline)
                .fontWeight(.medium)

                Spacer()

                Button("Sign Out") {
                    authManager.signOut()
                }
                .fontWeight(.semibold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(Rectangle())
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $isEditingBio) {
                NavigationStack {
                    Form {
                        Section("Bio") {
                            TextField("Tell us about yourself", text: $bioText, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isEditingBio = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    await authManager.updateBio(bioText)
                                    isEditingBio = false
                                }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}
