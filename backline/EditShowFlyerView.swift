//
//  EditShowFlyerView.swift
//  backline
//

import SwiftUI

struct EditShowFlyerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ListingManager.self) private var listingManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    let flyer: ShowFlyer

    @State private var title: String
    @State private var venue: String
    @State private var includeDate: Bool
    @State private var eventDate: Date
    @State private var ticketURL: String
    @State private var contactInfoWarning: String?

    init(flyer: ShowFlyer) {
        self.flyer = flyer
        _title = State(initialValue: flyer.title)
        _venue = State(initialValue: flyer.venue ?? "")
        _includeDate = State(initialValue: flyer.eventDate != nil)
        _eventDate = State(initialValue: flyer.eventDate ?? Date())
        _ticketURL = State(initialValue: flyer.ticketURL ?? "")
    }

    private var formIsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Show current flyer image (read-only)
                    if let url = URL(string: flyer.imageURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(maxHeight: 200)
                        .clipped()
                    }
                }

                Section {
                    TextField("Performers", text: $title)

                    TextField("Venue (optional)", text: $venue)

                    Toggle("Include Event Date", isOn: $includeDate)
                    if includeDate {
                        DatePicker("Event Date & Time", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                    }

                    TextField("Ticket URL (optional)", text: $ticketURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
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
                        Task { await saveChanges() }
                    } label: {
                        Group {
                            if listingManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
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
            .navigationTitle("Edit Flyer")
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

    private func saveChanges() async {
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

        let trimmedVenue = venue.trimmingCharacters(in: .whitespaces)

        await listingManager.updateShowFlyer(
            id: flyer.id,
            title: title.trimmingCharacters(in: .whitespaces),
            venue: trimmedVenue.isEmpty ? nil : trimmedVenue,
            eventDate: includeDate ? eventDate : nil,
            ticketURL: ticketURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ticketURL.trimmingCharacters(in: .whitespaces)
        )

        if listingManager.errorMessage == nil {
            BLAnalytics.editShowFlyer(flyerId: flyer.id)
            dismiss()
        }
    }
}
