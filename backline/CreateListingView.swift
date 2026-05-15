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
    @Environment(NetworkMonitor.self) private var networkMonitor

    // MARK: - Form State

    @State private var title = ""
    @State private var description = ""
    @State private var priceText = ""
    @State private var rentPriceText = ""
    @State private var category: ListingCategory = .guitars
    @State private var condition: ListingCondition = .good
    @State private var location = ""
    @State private var borough: Borough?
    @State private var forSale = true
    @State private var forRent = false

    // MARK: - Photo State

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var contactInfoWarning: String?
    @State private var isDetectingLocation = false
    @State private var locationError: String?

    // MARK: - Validation

    private var selectedTypes: [ListingType] {
        var types: [ListingType] = []
        if forSale { types.append(.sell) }
        if forRent { types.append(.rent) }

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
            Form {
                // Photos
                Section {
                    photosSection
                }

                // Details
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                // Listing type
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

                // Category & Condition
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

                // Warnings & Submit
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
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(formIsValid && !listingManager.isLoading && networkMonitor.isConnected ? Color.white : Color.gray)
                    .foregroundStyle(formIsValid && !listingManager.isLoading && networkMonitor.isConnected ? .black : .white)
                    .disabled(!formIsValid || listingManager.isLoading || !networkMonitor.isConnected)
                }
            }
            .navigationTitle("List an Item")
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
                        Text("\(loadedImages.count)/10")
                            .font(.caption2)
                    }
                    .foregroundStyle(ThemeColor.cyan)
                    .frame(width: 80, height: 80)
                    .background(Color(.systemGray5))
                }

                ForEach(loadedImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: loadedImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipped()

                        Button {
                            loadedImages.remove(at: index)
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 10, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                if loadedImages.count < 10 {
                    loadedImages.append(image)
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
        loadedImages = images
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

    // MARK: - Submit

    private func submitListing() async {
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

        guard let uid = authManager.currentUser?.uid,
              let username = authManager.username else { return }

        let price = forSale ? Double(priceText) : nil
        let rentPrice = forRent ? rentPriceText.trimmingCharacters(in: .whitespaces) : nil

        var fullLocation = location.trimmingCharacters(in: .whitespaces)
        if let borough {
            fullLocation += ", \(borough.rawValue)"
        }

        await listingManager.createListing(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            price: price,
            rentPrice: rentPrice,
            listingTypes: selectedTypes,
            category: category,
            condition: condition,
            location: fullLocation,
            borough: borough,
            images: loadedImages,
            sellerUID: uid,
            sellerUsername: username
        )

        if listingManager.errorMessage == nil {
            dismiss()
        }
    }
}
