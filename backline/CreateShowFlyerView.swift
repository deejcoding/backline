//
//  CreateShowFlyerView.swift
//  backline
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct CreateShowFlyerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    // MARK: - Form State

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var title = ""
    @State private var venue = ""
    @State private var includeDate = false
    @State private var eventDate = Date()
    @State private var contactInfoWarning: String?
    @State private var ticketURLString: String = "" // optional
    @State private var lookingForSupport = false

    // MARK: - Validation

    private var formIsValid: Bool {
        selectedImage != nil
        && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipped()
                        } else {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 14))
                                Text("Select Flyer Image")
                                    .font(.system(size: 14))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                let maxDimension: CGFloat = 1200
                                let size = uiImage.size
                                if max(size.width, size.height) > maxDimension {
                                    let ratio = maxDimension / max(size.width, size.height)
                                    let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)
                                    selectedImage = uiImage.preparingThumbnail(of: targetSize) ?? uiImage
                                } else {
                                    selectedImage = uiImage
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField("Performers", text: $title)

                    TextField("Venue", text: $venue)

                    Toggle("Include Event Date", isOn: $includeDate)
                    if includeDate {
                        DatePicker("Event Date & Time", selection: $eventDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    TextField("Ticket URL (optional)", text: $ticketURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    Toggle("Looking for Support", isOn: $lookingForSupport)
                }

                Section {
                    if let warning = contactInfoWarning {
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let errorMessage = listingManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await submitFlyer() }
                    } label: {
                        Group {
                            if listingManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Post Flyer")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(formIsValid && !listingManager.isLoading && networkMonitor.isConnected ? Color.white : Color.gray)
                    .foregroundStyle(formIsValid && !listingManager.isLoading && networkMonitor.isConnected ? .black : .white)
                    .disabled(!formIsValid || listingManager.isLoading || !networkMonitor.isConnected)
                }
            }
            .navigationTitle("Post Flyer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
    }

    // MARK: - Submit

    private func submitFlyer() async {
        contactInfoWarning = nil

        let fieldsToCheck = [title, venue]
        if fieldsToCheck.contains(where: { ContactInfoFilter.containsContactInfo($0) }) {
            contactInfoWarning = "Please don't include phone numbers or email addresses. Use in-app messaging instead."
            return
        }
        if fieldsToCheck.contains(where: { ProfanityFilter.containsProfanity($0) }) {
            contactInfoWarning = "Your post contains inappropriate language. Please revise and try again."
            return
        }

        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username,
              let image = selectedImage else { return }

        let trimmedVenue = venue.trimmingCharacters(in: .whitespaces)

        await listingManager.createShowFlyer(
            title: title.trimmingCharacters(in: .whitespaces),
            venue: trimmedVenue.isEmpty ? nil : trimmedVenue,
            eventDate: includeDate ? eventDate : nil,
            ticketURL: ticketURLString.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ticketURLString.trimmingCharacters(in: .whitespaces),
            lookingForSupport: lookingForSupport,
            image: image,
            posterUID: uid,
            posterUsername: username
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
