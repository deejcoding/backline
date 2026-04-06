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

    // MARK: - Form State

    @State private var category: ISOCategory = .gig
    @State private var roleNeeded = ""
    @State private var location = ""
    @State private var timeframe = Date()
    @State private var budget = ""
    @State private var description = ""

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

                        DatePicker("When", selection: $timeframe, in: Date()..., displayedComponents: .date)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Budget (e.g. $200, Negotiable)", text: $budget)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Description — what are you looking for?", text: $description, axis: .vertical)
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

                    // Submit
                    Button {
                        Task { await submitPost() }
                    } label: {
                        Group {
                            if listingManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Post ISO")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(formIsValid && !listingManager.isLoading ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(Rectangle())
                    }
                    .disabled(!formIsValid || listingManager.isLoading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Post ISO")
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

    // MARK: - Submit

    private func submitPost() async {
        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        await listingManager.createISOPost(
            category: category,
            roleNeeded: roleNeeded.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            timeframe: timeframe,
            budget: budget.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            posterUID: uid,
            posterUsername: username
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
