//
//  EditISOPostView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI

struct EditISOPostView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ListingManager.self) private var listingManager

    let post: ISOPost

    // MARK: - Form State

    @State private var category: ISOCategory
    @State private var roleNeeded: String
    @State private var location: String
    @State private var timeframeOption: TimeframeOption
    @State private var timeframe: Date

    private enum TimeframeOption: String, CaseIterable {
        case none = "No Date"
        case specificDate = "Specific Date"
        case ongoing = "Ongoing"
    }
    @State private var budget: String
    @State private var description: String
    @State private var contactInfoWarning: String?

    init(post: ISOPost) {
        self.post = post
        _category = State(initialValue: post.category)
        _roleNeeded = State(initialValue: post.roleNeeded)
        _location = State(initialValue: post.location ?? "")
        if post.isOngoing == true {
            _timeframeOption = State(initialValue: .ongoing)
        } else if post.timeframe != nil {
            _timeframeOption = State(initialValue: .specificDate)
        } else {
            _timeframeOption = State(initialValue: .none)
        }
        _timeframe = State(initialValue: post.timeframe ?? Date())
        // Strip leading $ for editing
        let rawBudget = post.budget.hasPrefix("$") ? String(post.budget.dropFirst()) : post.budget
        _budget = State(initialValue: rawBudget)
        _description = State(initialValue: post.description)
    }

    // MARK: - Validation

    private var formIsValid: Bool {
        !roleNeeded.trimmingCharacters(in: .whitespaces).isEmpty
        && !budget.trimmingCharacters(in: .whitespaces).isEmpty
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
                        DatePicker("When", selection: $timeframe, displayedComponents: .date)
                    }
                }

                Section {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Budget (e.g. 200)", text: $budget)
                            .keyboardType(.numberPad)
                    }

                    TextField("Description", text: $description, axis: .vertical)
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
                    .listRowBackground(formIsValid && !listingManager.isLoading ? ThemeColor.blue : Color.gray)
                    .foregroundStyle(.white)
                    .disabled(!formIsValid || listingManager.isLoading)
                }
            }
            .navigationTitle("Edit Open Role")
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

    // MARK: - Save

    private func saveChanges() async {
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

        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        await listingManager.updateISOPost(
            id: post.id,
            category: category,
            roleNeeded: roleNeeded.trimmingCharacters(in: .whitespaces),
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            timeframe: timeframeOption == .specificDate ? timeframe : nil,
            isOngoing: timeframeOption == .ongoing,
            budget: "$\(budget.trimmingCharacters(in: .whitespaces))",
            description: description.trimmingCharacters(in: .whitespaces)
        )

        if listingManager.errorMessage == nil {
            BLAnalytics.editISOPost(postId: post.id)
            dismiss()
        }
    }
}
