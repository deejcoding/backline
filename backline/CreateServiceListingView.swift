//
//  CreateServiceListingView.swift
//  backline
//
//  Created by Khadija Aslam on 3/17/26.
//

import SwiftUI
import FirebaseAuth

struct CreateServiceListingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    // MARK: - Form State

    @State private var title = ""
    @State private var category: ServiceCategory = .giggingMusician
    @State private var description = ""
    @State private var portfolioURL = ""
    @State private var rate = ""
    @State private var contactInfoWarning: String?

    // MARK: - Validation

    private var formIsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
        && !rate.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Service Title", text: $title)

                    Picker("Category", selection: $category) {
                        ForEach(ServiceCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section {
                    TextField("Description & Experience", text: $description, axis: .vertical)
                        .lineLimit(4...10)

                    TextField("Portfolio Link (optional)", text: $portfolioURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Rate (e.g. $50/hr, $200/session)", text: $rate)
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
                        Task { await submitService() }
                    } label: {
                        Group {
                            if listingManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Post Service")
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
            .navigationTitle("List Your Services")
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

    private func submitService() async {
        contactInfoWarning = nil

        let fieldsToCheck = [title, description, rate]
        if fieldsToCheck.contains(where: { ContactInfoFilter.containsContactInfo($0) }) {
            contactInfoWarning = "Please don't include phone numbers or email addresses. Use in-app messaging instead."
            return
        }
        if fieldsToCheck.contains(where: { ProfanityFilter.containsProfanity($0) }) {
            contactInfoWarning = "Your listing contains inappropriate language. Please revise and try again."
            return
        }

        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        let trimmedPortfolio = portfolioURL.trimmingCharacters(in: .whitespaces)

        await listingManager.createServiceListing(
            title: title.trimmingCharacters(in: .whitespaces),
            category: category,
            description: description.trimmingCharacters(in: .whitespaces),
            portfolioURL: trimmedPortfolio.isEmpty ? nil : trimmedPortfolio,
            rate: rate.trimmingCharacters(in: .whitespaces),
            sellerUID: uid,
            sellerUsername: username
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
