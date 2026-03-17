//
//  MainTabView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct MainTabView: View {

    @State private var selectedTab: Tab = .home
    @State private var showCreateListing = false

    enum Tab {
        case home
        case marketplace
        case gigs
        case profile
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .marketplace:
                    MarketplaceView()
                case .gigs:
                    GigsView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Custom tab bar
            HStack {
                tabButton("Home", tab: .home)
                tabButton("Marketplace", tab: .marketplace)

                // Center "+" button
                Button {
                    showCreateListing = true
                } label: {
                    Image(systemName: "plus")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }

                tabButton("Gigs", tab: .gigs)
                tabButton("Profile", tab: .profile)
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .fullScreenCover(isPresented: $showCreateListing) {
            CreateListingView()
        }
    }

    private func tabButton(_ title: String, tab: Tab) -> some View {
        Button {
            /* TODO: when button is pressed, opens a mini menu right above the plus with the options of "list an item" or "list your services". Each create listing is different. */
            selectedTab = tab
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(selectedTab == tab ? .bold : .regular)
                .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity)
        }
    }
}
