//
//  EditServiceListingView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI

struct EditServiceListingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ListingManager.self) private var listingManager

    let service: ServiceListing

    // MARK: - Form State

    @State private var title: String
    @State private var category: ServiceCategory
    @State private var description: String
    @State private var portfolioURL: String
    @State private var rate: String

    init(service: ServiceListing) {
        self.service = service
        _title = State(initialValue: service.title)
        _category = State(initialValue: service.category)
        _description = State(initialValue: service.description)
        _portfolioURL = State(initialValue: service.portfolioURL ?? "")
        _rate = State(initialValue: service.rate)
    }

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
            .navigationTitle("Edit Service")
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
        let trimmedPortfolio = portfolioURL.trimmingCharacters(in: .whitespaces)

        await listingManager.updateServiceListing(
            id: service.id,
            title: title.trimmingCharacters(in: .whitespaces),
            category: category,
            description: description.trimmingCharacters(in: .whitespaces),
            portfolioURL: trimmedPortfolio.isEmpty ? nil : trimmedPortfolio,
            rate: rate.trimmingCharacters(in: .whitespaces)
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
