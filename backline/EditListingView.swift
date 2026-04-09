//
//  EditListingView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI

struct EditListingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(ListingManager.self) private var listingManager

    let listing: Listing

    // MARK: - Form State

    @State private var title: String
    @State private var description: String
    @State private var priceText: String
    @State private var rentPriceText: String
    @State private var category: ListingCategory
    @State private var condition: ListingCondition
    @State private var location: String
    @State private var forSale: Bool
    @State private var forRent: Bool
    @State private var forTrade: Bool

    init(listing: Listing) {
        self.listing = listing
        _title = State(initialValue: listing.title)
        _description = State(initialValue: listing.description)
        _priceText = State(initialValue: listing.price.map { String(format: "%.0f", $0) } ?? "")
        _rentPriceText = State(initialValue: listing.rentPrice ?? "")
        _category = State(initialValue: listing.category)
        _condition = State(initialValue: listing.condition)
        _location = State(initialValue: listing.location)
        _forSale = State(initialValue: listing.listingTypes.contains(.sell))
        _forRent = State(initialValue: listing.listingTypes.contains(.rent))
        _forTrade = State(initialValue: listing.listingTypes.contains(.trade))
    }

    // MARK: - Validation

    private var selectedTypes: [ListingType] {
        var types: [ListingType] = []
        if forSale { types.append(.sell) }
        if forRent { types.append(.rent) }
        if forTrade { types.append(.trade) }
        return types
    }

    private var formIsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
        && !location.trimmingCharacters(in: .whitespaces).isEmpty
        && !selectedTypes.isEmpty
        && (!forSale || (Double(priceText) ?? -1) > 0)
        && (!forRent || !rentPriceText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        TextField("Title", text: $title)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        TextField("Description", text: $description, axis: .vertical)
                            .lineLimit(3...8)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())

                        // Listing type toggles
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Listing Type")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack(spacing: 10) {
                                listingTypeToggle("Sell", isOn: $forSale)
                                listingTypeToggle("Rent", isOn: $forRent)
                                listingTypeToggle("Trade", isOn: $forTrade)
                            }
                        }

                        if forSale {
                            HStack {
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("Sale Price", text: $priceText)
                                    .keyboardType(.decimalPad)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(Rectangle())
                        }

                        if forRent {
                            TextField("Rent Price (e.g. $20/hr, $50/day)", text: $rentPriceText)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(Rectangle())
                        }

                        HStack {
                            Text("Category")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Category", selection: $category) {
                                ForEach(ListingCategory.allCases, id: \.self) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                        HStack {
                            Text("Condition")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("Condition", selection: $condition) {
                                ForEach(ListingCondition.allCases, id: \.self) { cond in
                                    Text(cond.rawValue).tag(cond)
                                }
                            }
                            .labelsHidden()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())

                        TextField("Location (City, State)", text: $location)
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
            .navigationTitle("Edit Listing")
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

    // MARK: - Listing Type Toggle

    private func listingTypeToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn.wrappedValue ? ThemeColor.blue : Color(.systemGray6))
                .foregroundStyle(isOn.wrappedValue ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Save

    private func saveChanges() async {
        let price = forSale ? Double(priceText) : nil
        let rentPrice = forRent ? rentPriceText.trimmingCharacters(in: .whitespaces) : nil

        await listingManager.updateListing(
            id: listing.id,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            price: price,
            rentPrice: rentPrice,
            listingTypes: selectedTypes,
            category: category,
            condition: condition,
            location: location.trimmingCharacters(in: .whitespaces)
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
