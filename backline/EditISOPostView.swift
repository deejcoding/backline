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
    @State private var timeframe: Date
    @State private var budget: String
    @State private var description: String

    init(post: ISOPost) {
        self.post = post
        _category = State(initialValue: post.category)
        _roleNeeded = State(initialValue: post.roleNeeded)
        _location = State(initialValue: post.location)
        _timeframe = State(initialValue: post.timeframe)
        _budget = State(initialValue: post.budget)
        _description = State(initialValue: post.description)
    }

    // MARK: - Validation

    private var formIsValid: Bool {
        !roleNeeded.trimmingCharacters(in: .whitespaces).isEmpty
        && !location.trimmingCharacters(in: .whitespaces).isEmpty
        && !budget.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        HStack {
                            Text("Category")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Category", selection: $category) {
                                ForEach(ISOCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                        TextField("Role Needed (e.g. Drummer, Sound Engineer)", text: $roleNeeded)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Location (e.g. Austin, TX)", text: $location)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        DatePicker("When", selection: $timeframe, displayedComponents: .date)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Budget (e.g. $200, Negotiable)", text: $budget)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Description", text: $description, axis: .vertical)
                            .lineLimit(4...10)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())
                    }
                    .padding(.horizontal)

                    // Error
                    if let errorMessage = listingManager.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Save
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
                        .padding()
                        .background(formIsValid && !listingManager.isLoading ? ThemeColor.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                    }
                    .disabled(!formIsValid || listingManager.isLoading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit ISO Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Save

    private func saveChanges() async {
        await listingManager.updateISOPost(
            id: post.id,
            category: category,
            roleNeeded: roleNeeded.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            timeframe: timeframe,
            budget: budget.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces)
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
