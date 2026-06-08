//
//  MainTabView.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseAuth
import Combine
import UserNotifications

struct MainTabView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(MessagesManager.self) private var messagesManager
    @Environment(ListingManager.self) private var listingManager
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showCreateMenu = false
    @State private var showCreateListing = false
    @State private var showCreateService = false
    @State private var showCreateISO = false
    @State private var showCreateFlyer = false
    @State private var keyboardVisible = false
    @State private var showGuestPrompt = false

    // Navigation paths for each tab
    @State private var homePath = NavigationPath()
    @State private var gigsPath = NavigationPath()
    @State private var marketPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var gigsSelectedSegment = 0
    @State private var marketSelectedSegment: MarketplaceSegment = .goods

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Offline banner
                if !networkMonitor.isConnected {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 11))
                        Text("YOU'RE OFFLINE")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(0.5)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(ThemeColor.red.opacity(0.85))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Content area
                Group {
                switch selectedTab {
                case 0: HomeView(selectedTab: $selectedTab, navigationPath: $homePath, gigsSelectedSegment: $gigsSelectedSegment, marketSelectedSegment: $marketSelectedSegment)
                case 1: GigsView(navigationPath: $gigsPath, selectedSegment: $gigsSelectedSegment)
                case 3: MarketplaceView(navigationPath: $marketPath, selectedSegment: $marketSelectedSegment)
                case 4:
                    if authManager.isGuestMode {
                        guestProfilePlaceholder
                    } else {
                        ProfileView(navigationPath: $profilePath)
                    }
                default: Color.clear
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible {
                    customTabBar
                } else {
                    Color.clear.frame(height: 0)
                }
            }

            // Popup menu
            if showCreateMenu && !keyboardVisible {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showCreateMenu = false
                        }
                    }

                VStack(spacing: 0) {
                    createMenuItem(icon: "tag", label: "LIST ITEM") {
                        showCreateMenu = false
                        showCreateListing = true
                    }

                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

                    createMenuItem(icon: "megaphone", label: "POST OPEN ROLE") {
                        showCreateMenu = false
                        showCreateISO = true
                    }

                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

                    createMenuItem(icon: "wrench.and.screwdriver", label: "OFFER SERVICE") {
                        showCreateMenu = false
                        showCreateService = true
                    }

                    Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)

                    createMenuItem(icon: "photo.on.rectangle", label: "POST FLYER") {
                        showCreateMenu = false
                        showCreateFlyer = true
                    }
                }
                .background(Color(hex: 0x1A1A1A))
                .overlay(
                    Rectangle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .frame(width: 200)
                .padding(.bottom, 90)
                .transition(.scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onChange(of: selectedTab) { _, newTab in
            let tabNames = [0: "home", 1: "gigs", 3: "market", 4: "profile"]
            BLAnalytics.switchTab(tabNames[newTab] ?? "unknown")
        }
        .onChange(of: messagesManager.conversations) {
            let count = messagesManager.unreadCount(forUID: authManager.currentUser?.uid ?? "")
            UNUserNotificationCenter.current().setBadgeCount(count)
        }
        .onChange(of: deepLinkRouter.pendingDeepLink) { _, link in
            guard let link else { return }
            Task { await handleDeepLink(link) }
        }
        .task {
            // Handle deep link that arrived before this view appeared (cold launch)
            if let link = deepLinkRouter.pendingDeepLink {
                await handleDeepLink(link)
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
        .fullScreenCover(isPresented: $showCreateFlyer) {
            CreateShowFlyerView()
        }
        .sheet(isPresented: $showGuestPrompt) {
            GuestPromptView()
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)

            HStack(spacing: 0) {
                tabButton(icon: "house", label: "Home", tag: 0)
                tabButton(icon: "person.2", label: "Gigs", tag: 1)

                // Center post button — square with border
                Button {
                    if authManager.isGuestMode {
                        showGuestPrompt = true
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showCreateMenu = true
                        }
                    }
                } label: {
                    Text("＋")
                        .font(.system(size: 22, weight: .light))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Rectangle()
                                .stroke(.white, lineWidth: 1.5)
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .accessibilityLabel("Create new post")

                tabButton(icon: "guitars", label: "Market", tag: 3)
                tabButton(
                    icon: "person",
                    label: "Profile",
                    tag: 4,
                    badge: authManager.isGuestMode ? 0 : messagesManager.unreadCount(forUID: authManager.currentUser?.uid ?? "")
                )
            }
            .padding(.bottom, 22)
        }
        .background(Color(hex: 0x0A0A0A))
    }

    // MARK: - Guest Profile Placeholder

    private var guestProfilePlaceholder: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.3))

                Text("YOUR PROFILE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(1)

                Text("Sign in or create an account to set up your profile, message other musicians, and post listings.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    authManager.exitGuestMode()
                } label: {
                    Text("Sign In / Sign Up")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white)
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("backline")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(-0.2)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Deep Link Handler

    private func handleDeepLink(_ link: DeepLink) async {
        // Clear the pending link so it doesn't fire again
        deepLinkRouter.pendingDeepLink = nil

        switch link {
        case .listing(let id):
            if let listing = await listingManager.fetchListing(id: id) {
                selectedTab = 3
                marketPath = NavigationPath()
                marketPath.append(listing)
            }

        case .service(let id):
            if let service = await listingManager.fetchServiceListing(id: id) {
                selectedTab = 3
                marketPath = NavigationPath()
                marketPath.append(service)
            }

        case .iso(let id):
            if let post = await listingManager.fetchISOPost(id: id) {
                selectedTab = 1
                gigsPath = NavigationPath()
                gigsPath.append(post)
            }

        case .flyer(let id):
            if let flyer = await listingManager.fetchShowFlyer(id: id) {
                selectedTab = 1
                gigsPath = NavigationPath()
                gigsPath.append(flyer)
            }

        case .profile(let uid, let username):
            selectedTab = 0
            homePath = NavigationPath()
            homePath.append(ProfileDestination(uid: uid, username: username))

        case .chat(let conversationId):
            // Find the conversation from the loaded list
            if let conversation = messagesManager.conversations.first(where: { $0.id == conversationId }) {
                selectedTab = 4
                profilePath = NavigationPath()
                profilePath.append(ChatDestination(conversationId: conversationId, conversation: conversation))
            } else {
                // Conversations may not be loaded yet — wait briefly, then try again
                try? await Task.sleep(for: .seconds(1))
                if let conversation = messagesManager.conversations.first(where: { $0.id == conversationId }) {
                    selectedTab = 4
                    profilePath = NavigationPath()
                    profilePath.append(ChatDestination(conversationId: conversationId, conversation: conversation))
                }
            }
        }
    }

    // MARK: - Tab Button

    private func tabButton(icon: String, label: String, tag: Int, badge: Int = 0) -> some View {
        Button {
            if selectedTab == tag {
                // Tapping the already active tab — reset its stack
                switch tag {
                case 0: homePath = NavigationPath()
                case 1: gigsPath = NavigationPath()
                case 3: marketPath = NavigationPath()
                case 4: profilePath = NavigationPath()
                default: break
                }
            } else {
                previousTab = selectedTab
                selectedTab = tag
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                    Text(label)
                        .font(.system(size: 10))
                        .tracking(0.2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .opacity(selectedTab == tag ? 1.0 : 0.45)
                .overlay(alignment: .top) {
                    if selectedTab == tag {
                        Rectangle()
                            .fill(ThemeColor.cyan)
                            .frame(height: 2)
                            .padding(.horizontal, 20)
                    }
                }

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(ThemeColor.red)
                        .clipShape(Capsule())
                        .offset(x: -8, y: 2)
                }
            }
        }
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }

    // MARK: - Create Menu Item

    private func createMenuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .foregroundStyle(.white)
    }
}
