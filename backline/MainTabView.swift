//
//  MainTabView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth

struct MainTabView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager

    @State private var selectedTab = 0
    @State private var showCreateMenu = false
    @State private var showCreateListing = false
    @State private var showCreateService = false
    @State private var showCreateISO = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house", value: 0) {
                    HomeView()
                }
                Tab("Marketplace", systemImage: "guitars", value: 1) {
                    MarketplaceView()
                }
                Tab("Create", systemImage: "plus.circle.fill", value: 2) {
                    Color.clear
                }
                Tab("Services", systemImage: "person.2", value: 3) {
                    GigsView()
                }
                Tab("Messages", systemImage: "bubble.left.and.bubble.right", value: 4) {
                    ConversationsView()
                }
                .badge(messagesManager.unreadCount(forUID: authManager.currentUser?.uid ?? ""))
                Tab("Profile", systemImage: "person", value: 5) {
                    ProfileView()
                }
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 2 {
                    selectedTab = 1 // bounce back so Create tab doesn't stay selected
                    withAnimation(.easeOut(duration: 0.15)) {
                        showCreateMenu = true
                    }
                }
            }

            // Popup menu
            if showCreateMenu {
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
                        showCreateISO = true
                    } label: {
                        Label("Post ISO", systemImage: "megaphone")
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
        .fullScreenCover(isPresented: $showCreateISO) {
            CreateISOPostView()
        }
    }
}
