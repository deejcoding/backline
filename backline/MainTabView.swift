//
//  MainTabView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI

struct MainTabView: View {

    @State private var selectedTab: Tab = .home
    @State private var showCreateMenu = false
    @State private var showCreateListing = false
    @State private var showCreateService = false

    enum Tab {
        case home
        case marketplace
        case gigs
        case messages
        case profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
                    case .messages:
                        ConversationsView()
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
                        withAnimation(.easeOut(duration: 0.15)) {
                            showCreateMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }

                    tabButton("Gigs", tab: .gigs)
                    tabButton("Messages", tab: .messages)
                    tabButton("Profile", tab: .profile)
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }

            // Popup menu
            if showCreateMenu {
                // Dismiss backdrop
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showCreateMenu = false
                        }
                    }

                VStack(spacing: 0) {
                    Button {
                        showCreateMenu = false
                        showCreateListing = true
                    } label: {
                        Label("List an Item", systemImage: "tag")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }

                    Divider()

                    Button {
                        showCreateMenu = false
                        showCreateService = true
                    } label: {
                        Label("List Your Services", systemImage: "wrench.and.screwdriver")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                .frame(width: 220)
                .padding(.bottom, 70)
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $showCreateListing) {
            CreateListingView()
        }
        .fullScreenCover(isPresented: $showCreateService) {
            CreateServiceListingView()
        }
    }

    private func tabButton(_ title: String, tab: Tab) -> some View {
        Button {
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
