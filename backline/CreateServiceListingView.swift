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

    // MARK: - Form State

    @State private var title = ""
    @State private var category: ServiceCategory = .giggingMusician
    @State private var description = ""
    @State private var portfolioURL = ""
    @State private var rate = ""

    // MARK: - Validation

    private var formIsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
        && !rate.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        TextField("Service Title", text: $title)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        HStack {
                            Text("Category")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Category", selection: $category) {
                                ForEach(ServiceCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                        TextField("Description & Experience", text: $description, axis: .vertical)
                            .lineLimit(4...10)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Portfolio Link (optional)", text: $portfolioURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Rate (e.g. $50/hr, $200/session)", text: $rate)
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
            .navigationTitle("List Your Services")
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

    private func submitService() async {
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
