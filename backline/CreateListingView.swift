//
//  CreateListingView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct CreateListingView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(ListingManager.self) private var listingManager

    // MARK: - Form State

    @State private var title = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var rentPriceText = ""
    @State private var category: ListingCategory = .guitars
    @State private var condition: ListingCondition = .good
    @State private var location = ""
    @State private var forSale = true
    @State private var forRent = false
    @State private var forTrade = false

    // MARK: - Photo State

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []

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
        && !loadedImages.isEmpty
        && !selectedTypes.isEmpty
        && (!forSale || (Double(priceText) ?? -1) > 0)
        && (!forRent || !rentPriceText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Photos
                    photosSection

                    // Fields
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

                        // Sale price (shown when Sell is toggled)
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

                        // Rent price (shown when Rent is toggled)
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

                    // Submit
                    Button {
                        Task { await submitListing() }
                    } label: {
                        Group {
                            if listingManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Post Listing")
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
            .navigationTitle("List an Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task { await loadImages(from: newItems) }
            }
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.title2)
                            Text("\(loadedImages.count)/10")
                                .font(.caption2)
                        }
                        .foregroundStyle(ThemeColor.blue)
                        .frame(width: 80, height: 80)
                        .background(Color(.systemGray6))
                        .clipShape(Rectangle())
                    }

                    ForEach(loadedImages.indices, id: \.self) { index in
                        Image(uiImage: loadedImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Rectangle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Image Loading

    private func loadImages(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                images.append(uiImage)
            }
        }
        loadedImages = images
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

    // MARK: - Submit

    private func submitListing() async {
        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        let price = forSale ? Double(priceText) : nil
        let rentPrice = forRent ? rentPriceText.trimmingCharacters(in: .whitespaces) : nil

        await listingManager.createListing(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            price: price,
            rentPrice: rentPrice,
            listingTypes: selectedTypes,
            category: category,
            condition: condition,
            location: location.trimmingCharacters(in: .whitespaces),
            images: loadedImages,
            sellerUID: uid,
            sellerUsername: username
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
