//
//  MarketplaceView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth

    enum MarketplaceSegment: String, CaseIterable {
        case goods = "Goods"
        case services = "Services"
    }

struct MarketplaceView: View {

    @Binding var navigationPath: NavigationPath

    @Environment(ListingManager.self) private var listingManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    @State private var searchText = ""
    @Binding var selectedSegment: MarketplaceSegment
    @State private var selectedCategory: ListingCategory?
    @State private var selectedServiceCategory: ServiceCategory?
    @State private var navigateToChat = false
    @State private var activeChatConversationId: String?
    @State private var activeChatConversation: Conversation?

    private var filteredListings: [Listing] {
        let blocked = Set(authManager.blockedUsers)
        var results = listingManager.listings.filter { !blocked.contains($0.sellerUID) }

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
            }
        }

        return results
    }

    private var filteredServices: [ServiceListing] {
        let blocked = Set(authManager.blockedUsers)
        var results = listingManager.serviceListings.filter { !blocked.contains($0.sellerUID) }

        if let category = selectedServiceCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.title.lowercased().contains(query)
                || $0.description.lowercased().contains(query)
                || $0.sellerUsername.lowercased().contains(query)
            }
        }

        return results
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Goods / Services toggle
                HStack(spacing: 0) {
                    segmentButton("Goods", segment: .goods)
                    segmentButton("Services", segment: .services)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }

                if selectedSegment == .goods {
                    goodsContent
                } else {
                    servicesContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("backline")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(-0.2)
                }

            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: selectedSegment == .goods ? "Search gear and instruments" : "Search services")
            .onSubmit(of: .search) {
                if selectedSegment == .goods {
                    BLAnalytics.searchListings(query: searchText)
                } else {
                    BLAnalytics.searchServices(query: searchText)
                }
            }
            .task {
                async let goods: () = listingManager.fetchListings()
                async let services: () = listingManager.fetchServiceListings()
                _ = await (goods, services)
                // Fetch profile photos for service listers
                let serviceUIDs = listingManager.serviceListings.map(\.sellerUID)
                await listingManager.fetchProfilePhotos(for: serviceUIDs)
            }

            .navigationDestination(isPresented: $navigateToChat) {
                if let convId = activeChatConversationId,
                   let conv = activeChatConversation {
                    ChatView(conversationId: convId, conversation: conv)
                }
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                PublicProfileView(uid: dest.uid, username: dest.username)
            }
            .navigationDestination(for: ISOPost.self) { post in
                ISOPostDetailView(post: post)
            }
            .navigationDestination(for: ServiceListing.self) { service in
                ServiceListingDetailView(service: service)
            }
        }
    }

    // MARK: - Goods Content

    private var goodsContent: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip("All", category: nil)
                    ForEach(ListingCategory.allCases, id: \.self) { cat in
                        categoryChip(cat.rawValue, category: cat)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredListings.isEmpty {
                Spacer()
                Image(systemName: "guitars")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No listings yet")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                Text("Listings you and others post will appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredListings) { listing in
                            NavigationLink {
                                ListingDetailView(listing: listing)
                            } label: {
                                listingCard(listing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await listingManager.fetchListings()
                }
            }
        }
    }

    // MARK: - Services Content

    private var servicesContent: some View {
        VStack(spacing: 0) {
            // Service category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    serviceCategoryChip("All", category: nil)
                    ForEach(ServiceCategory.allCases, id: \.self) { cat in
                        serviceCategoryChip(cat.rawValue, category: cat)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if filteredServices.isEmpty {
                Spacer()
                Image(systemName: "wrench.and.screwdriver")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No services yet")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                Text("Services posted by musicians will appear here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredServices) { service in
                            NavigationLink(value: service) {
                                serviceCard(service)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await listingManager.fetchServiceListings()
                }
            }
        }
    }

    // MARK: - Category Chip

    private func categoryChip(_ title: String, category: ListingCategory?) -> some View {
        BroadcastChip(
            title: title,
            isSelected: selectedCategory == category,
            action: { selectedCategory = category }
        )
    }

    // MARK: - Listing Card

    private func listingCard(_ listing: Listing) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square photo
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let firstURL = listing.photoURLs.first, let url = URL(string: firstURL) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray6))
                        }
                    } else {
                        Rectangle().fill(Color(.systemGray6))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(Color(.systemGray4))
                            }
                    }
                }
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .padding(.top, 8)

                HStack(spacing: 6) {
                    if let price = listing.price {
                        Text("$\(price, specifier: "%.0f")")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(ThemeColor.green)
                    }
                    if let rentPrice = listing.rentPrice, !rentPrice.isEmpty {
                        Text(rentPrice)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(ThemeColor.cyan)
                    }
                    Spacer()
                    Text(listing.condition.rawValue)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(0.4)
                }

                HStack(spacing: 5) {
                    Text("@\(listing.sellerUsername)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(listing.location)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Service Category Chip

    private func serviceCategoryChip(_ title: String, category: ServiceCategory?) -> some View {
        BroadcastChip(
            title: title,
            isSelected: selectedServiceCategory == category,
            action: { selectedServiceCategory = category }
        )
    }

    // MARK: - Service Card

    private func serviceCard(_ service: ServiceListing) -> some View {
        HStack(spacing: 10) {
            // Small profile photo
            if let urlString = listingManager.profilePhotos[service.sellerUID],
               let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(width: 36, height: 36)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(.systemGray3))
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(service.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(service.rate)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(ThemeColor.green)

                Text("@\(service.sellerUsername)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func segmentButton(_ title: String, segment: MarketplaceSegment) -> some View {
        Button {
            selectedSegment = segment
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: selectedSegment == segment ? .bold : .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(selectedSegment == segment ? .white : .white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                Rectangle()
                    .fill(selectedSegment == segment ? ThemeColor.cyan : .clear)
                    .frame(height: 2)
            }
        }
        .accessibilityLabel(title)
    }
}
