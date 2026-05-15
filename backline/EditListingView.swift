//
//  EditListingView.swift
//  backline
//
//  Created by Khadija Aslam on 4/6/26.
//

import SwiftUI
import PhotosUI

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
    @State private var borough: Borough?
    @State private var forSale: Bool
    @State private var forRent: Bool
    @State private var contactInfoWarning: String?
    @State private var isDetectingLocation = false
    @State private var locationError: String?

    // MARK: - Photo State

    @State private var existingPhotoURLs: [String]
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    init(listing: Listing) {
        self.listing = listing
        _title = State(initialValue: listing.title)
        _description = State(initialValue: listing.description)
        _priceText = State(initialValue: listing.price.map { String(format: "%.0f", $0) } ?? "")
        _rentPriceText = State(initialValue: listing.rentPrice ?? "")
        _category = State(initialValue: listing.category)
        _condition = State(initialValue: listing.condition)
        // If borough is stored, show just the neighborhood part in the text field
        if let boro = listing.borough {
            _borough = State(initialValue: boro)
            let suffix = ", \(boro.rawValue)"
            if listing.location.hasSuffix(suffix) {
                _location = State(initialValue: String(listing.location.dropLast(suffix.count)))
            } else {
                _location = State(initialValue: listing.location)
            }
        } else {
            _location = State(initialValue: listing.location)
            _borough = State(initialValue: nil)
        }
        _forSale = State(initialValue: listing.listingTypes.contains(.sell))
        _forRent = State(initialValue: listing.listingTypes.contains(.rent))
        _existingPhotoURLs = State(initialValue: listing.photoURLs)
    }

    // MARK: - Validation

    private var selectedTypes: [ListingType] {
        var types: [ListingType] = []
        if forSale { types.append(.sell) }
        if forRent { types.append(.rent) }

        return types
    }

    private var totalPhotoCount: Int {
        existingPhotoURLs.count + newImages.count
    }

    private var formIsValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !description.trimmingCharacters(in: .whitespaces).isEmpty
        && !location.trimmingCharacters(in: .whitespaces).isEmpty
        && totalPhotoCount > 0
        && !selectedTypes.isEmpty
        && (!forSale || (Double(priceText) ?? -1) > 0)
        && (!forRent || !rentPriceText.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Photos
                Section {
                    photosSection
                }

                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Listing Type") {
                    HStack(spacing: 10) {
                        listingTypeToggle("Sell", isOn: $forSale)
                        listingTypeToggle("Rent", isOn: $forRent)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .listRowBackground(Color.clear)

                    if forSale {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("Sale Price", text: $priceText)
                                .keyboardType(.decimalPad)
                        }
                    }

                    if forRent {
                        TextField("Rent Price (e.g. $20/hr, $50/day)", text: $rentPriceText)
                    }
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ListingCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    Picker("Condition", selection: $condition) {
                        ForEach(ListingCondition.allCases, id: \.self) { cond in
                            Text(cond.rawValue).tag(cond)
                        }
                    }

                    TextField("Neighborhood", text: $location)

                    Picker("Borough", selection: $borough) {
                        Text("Select Borough").tag(Borough?.none)
                        ForEach(Borough.allCases, id: \.self) { b in
                            Text(b.rawValue).tag(Borough?.some(b))
                        }
                    }

                    Button {
                        Task { await detectNeighborhood() }
                    } label: {
                        HStack(spacing: 6) {
                            if isDetectingLocation {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(ThemeColor.cyan)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                            }
                            Text("USE MY LOCATION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                        }
                        .foregroundStyle(ThemeColor.cyan)
                    }
                    .disabled(isDetectingLocation)

                    if let locationError {
                        Text(locationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
                    .listRowBackground(formIsValid && !listingManager.isLoading ? Color.white : Color.gray)
                    .foregroundStyle(formIsValid && !listingManager.isLoading ? .black : .white)
                    .disabled(!formIsValid || listingManager.isLoading)
                }
            }
            .navigationTitle("Edit Listing")
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
            .onChange(of: selectedPhotos) { _, newItems in
                Task { await loadImages(from: newItems) }
            }
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add button
                if totalPhotoCount < 10 {
                    Menu {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }

                        Button {
                            showPhotoPicker = true
                        } label: {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.title2)
                            Text("\(totalPhotoCount)/10")
                                .font(.caption2)
                        }
                        .foregroundStyle(ThemeColor.cyan)
                        .frame(width: 80, height: 80)
                        .background(Color(.systemGray5))
                    }
                }

                // Existing photos (from URLs)
                ForEach(existingPhotoURLs.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: existingPhotoURLs[index])) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color(.systemGray4)
                        }
                        .frame(width: 80, height: 80)
                        .clipped()

                        Button {
                            existingPhotoURLs.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .padding(2)
                    }
                }

                // New photos (from picker/camera)
                ForEach(newImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: newImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()

                        Button {
                            newImages.remove(at: index)
                            if index < selectedPhotos.count {
                                selectedPhotos.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .padding(2)
                    }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 10 - existingPhotoURLs.count, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                if totalPhotoCount < 10 {
                    newImages.append(image)
                }
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
        newImages = images
    }

    // MARK: - Listing Type Toggle

    private func listingTypeToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(0.3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn.wrappedValue ? Color.white : Color.clear)
                .foregroundStyle(isOn.wrappedValue ? Color.black : .white.opacity(0.7))
                .overlay(
                    Rectangle()
                        .stroke(isOn.wrappedValue ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
                )
        }
    }

    // MARK: - Location Detection

    private func detectNeighborhood() async {
        isDetectingLocation = true
        locationError = nil
        do {
            let coord = try await LocationHelper.requestCurrentLocation()
            let neighborhood = try await NeighborhoodService.detectNeighborhood(lat: coord.latitude, lng: coord.longitude)
            let parts = neighborhood.components(separatedBy: ", ")
            location = parts.first ?? neighborhood
            if let boroName = parts.last {
                borough = Borough(rawValue: boroName)
            }
        } catch {
            locationError = error.localizedDescription
        }
        isDetectingLocation = false
    }

    // MARK: - Save

    private func saveChanges() async {
        contactInfoWarning = nil

        let fieldsToCheck = [title, description, location, rentPriceText]
        if fieldsToCheck.contains(where: { ContactInfoFilter.containsContactInfo($0) }) {
            contactInfoWarning = "Please don't include phone numbers or email addresses. Use in-app messaging instead."
            return
        }
        if fieldsToCheck.contains(where: { ProfanityFilter.containsProfanity($0) }) {
            contactInfoWarning = "Your listing contains inappropriate language. Please revise and try again."
            return
        }

        let price = forSale ? Double(priceText) : nil
        let rentPrice = forRent ? rentPriceText.trimmingCharacters(in: .whitespaces) : nil

        var fullLocation = location.trimmingCharacters(in: .whitespaces)
        if let borough {
            fullLocation += ", \(borough.rawValue)"
        }

        await listingManager.updateListing(
            id: listing.id,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            price: price,
            rentPrice: rentPrice,
            listingTypes: selectedTypes,
            category: category,
            condition: condition,
            location: fullLocation,
            borough: borough,
            existingPhotoURLs: existingPhotoURLs,
            newImages: newImages
        )

        if listingManager.errorMessage == nil {
            BLAnalytics.editListing(listingId: listing.id)
            dismiss()
        }
    }
}
