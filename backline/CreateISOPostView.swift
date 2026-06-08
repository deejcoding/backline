//
//  CreateISOPostView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI
import FirebaseAuth

struct CreateISOPostView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(NetworkMonitor.self) private var networkMonitor

    // MARK: - Form State

    @State private var category: ISOCategory = .gig
    @State private var roleNeeded = ""
    @State private var location = ""
    @State private var timeframeOption: TimeframeOption = .none
    @State private var timeframe = Date()

    private enum TimeframeOption: String, CaseIterable {
        case none = "No Date"
        case specificDate = "Specific Date"
        case ongoing = "Ongoing"
    }
    @State private var budget = ""
    @State private var description = ""
    @State private var contactInfoWarning: String?

    // MARK: - Validation

    private var formIsValid: Bool {
        !roleNeeded.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ISOCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    TextField("Role Needed (e.g. Drummer, Sound Engineer)", text: $roleNeeded)

                    TextField("Location (optional)", text: $location)

                    Picker("Timeframe", selection: $timeframeOption) {
                        ForEach(TimeframeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    if timeframeOption == .specificDate {
                        DatePicker("When", selection: $timeframe, in: Date()..., displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Compensation (e.g. $200, 15%, etc.)", text: $budget)

                    TextField("Description — what are you looking for?", text: $description, axis: .vertical)
                        .lineLimit(4...10)
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
                        Task { await submitPost() }
                    } label: {
                        Group {
                            if listingManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Post Open Role")
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
            .navigationTitle("Post Open Role")
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

    private func submitPost() async {
        contactInfoWarning = nil

        let fieldsToCheck = [roleNeeded, location, budget, description]
        if fieldsToCheck.contains(where: { ContactInfoFilter.containsContactInfo($0) }) {
            contactInfoWarning = "Please don't include phone numbers or email addresses. Use in-app messaging instead."
            return
        }
        if fieldsToCheck.contains(where: { ProfanityFilter.containsProfanity($0) }) {
            contactInfoWarning = "Your post contains inappropriate language. Please revise and try again."
            return
        }

        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        let trimmedBudget = budget.trimmingCharacters(in: .whitespaces)

        await listingManager.createISOPost(
            category: category,
            roleNeeded: roleNeeded.trimmingCharacters(in: .whitespaces),
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            timeframe: timeframeOption == .specificDate ? timeframe : nil,
            isOngoing: timeframeOption == .ongoing,
            budget: trimmedBudget.isEmpty ? nil : trimmedBudget,
            description: description.trimmingCharacters(in: .whitespaces),
            posterUID: uid,
            posterUsername: username
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
