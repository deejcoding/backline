//
//  Analytics.swift
//  backline
//
//  Lightweight wrapper around Firebase Analytics.
//
import FirebaseAnalytics
import FirebaseFirestore

enum BLAnalytics {

    private static let db = Firestore.firestore()

    static func log(_ event: String, _ params: [String: Any]? = nil) {
        // 1. Log to standard Firebase Analytics
        Analytics.logEvent(event, parameters: params)

        // 2. Increment counters in Firestore for Admin Dashboard
        incrementFirestoreStats(event: event)
    }

    private static func incrementFirestoreStats(event: String) {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10) // YYYY-MM-DD

        // Sanitize event name for Firestore field (no periods/slashes)
        let safeEvent = event.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "/", with: "_")

        // Update daily activity
        db.collection("stats").document("daily_activity").collection("days").document(String(today)).setData([
            safeEvent: FieldValue.increment(Int64(1)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], merge: true)

        // Update global counters for specific events
        let globalTrackedEvents = [
            "send_message": "totalMessagesSent",
            "view_listing": "totalListingViews",
            "view_profile": "totalProfileViews",
            "search": "totalSearches",
            "start_conversation": "totalConversationsStarted"
        ]

        if let field = globalTrackedEvents[event] {
            db.collection("stats").document("global").setData([
                field: FieldValue.increment(Int64(1)),
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    // MARK: - Auth

    static func signUp(method: String) {
        log(AnalyticsEventSignUp, [AnalyticsParameterMethod: method])
    }

    static func login(method: String) {
        log(AnalyticsEventLogin, [AnalyticsParameterMethod: method])
    }

    static func signOut() {
        log("sign_out")
    }

    static func deleteAccount() {
        log("delete_account")
    }

    // MARK: - Content Creation
    static func createListing(category: String) {
        log("create_listing", ["category": category])
    }

    static func createServiceListing(category: String) {
        log("create_service_listing", ["category": category])
    }

    static func createISOPost(category: String, role: String) {
        log("create_iso_post", ["category": category, "role_needed": role])
    }

    static func createShowFlyer() {
        log("create_show_flyer")
    }

    static func viewShowFlyer(flyerId: String) {
        log("view_show_flyer", ["flyer_id": flyerId])
    }

    // MARK: - Messaging
    static func sendMessage() {
        log("send_message")
    }

    static func startConversation() {
        log("start_conversation")
    }

    // MARK: - Connections
    static func sendConnectionRequest() {
        log("send_connection_request")
    }

    static func acceptConnectionRequest() {
        log("accept_connection_request")
    }

    static func rejectConnectionRequest() {
        log("reject_connection_request")
    }

    // MARK: - Engagement
    static func viewProfile(uid: String) {
        log("view_profile", ["viewed_uid": uid])
    }

    static func viewListing(listingId: String) {
        log("view_listing", ["listing_id": listingId])
    }

    static func viewISOPost(postId: String) {
        log("view_iso_post", ["post_id": postId])
    }

    static func viewServiceListing(serviceId: String) {
        log("view_service_listing", ["service_id": serviceId])
    }

    static func switchTab(_ tab: String) {
        log("switch_tab", ["tab": tab])
    }

    static func search(query: String) {
        log(AnalyticsEventSearch, [AnalyticsParameterSearchTerm: query])
    }

    // MARK: - Content Updates
    static func editListing(listingId: String) {
        log("edit_listing", ["listing_id": listingId])
    }

    static func editServiceListing(serviceId: String) {
        log("edit_service_listing", ["service_id": serviceId])
    }

    static func editISOPost(postId: String) {
        log("edit_iso_post", ["post_id": postId])
    }

    static func editShowFlyer(flyerId: String) {
        log("edit_show_flyer", ["flyer_id": flyerId])
    }

    // MARK: - Profile
    static func editProfile() {
        log("edit_profile")
    }

    static func updateMessagingPrivacy(setting: String) {
        log("update_messaging_privacy", ["setting": setting])
    }

    // MARK: - Connections (additional)
    static func withdrawConnectionRequest() {
        log("withdraw_connection_request")
    }

    static func removeConnection() {
        log("remove_connection")
    }

    static func unblockUser() {
        log("unblock_user")
    }

    // MARK: - Search (per-feed)
    static func searchListings(query: String) {
        log("search_listings", [AnalyticsParameterSearchTerm: query])
    }

    static func searchServices(query: String) {
        log("search_services", [AnalyticsParameterSearchTerm: query])
    }

    static func searchISOPosts(query: String) {
        log("search_iso_posts", [AnalyticsParameterSearchTerm: query])
    }

    static func searchArtists(query: String) {
        log("search_artists", [AnalyticsParameterSearchTerm: query])
    }

    static func searchShowFlyers(query: String) {
        log("search_show_flyers", [AnalyticsParameterSearchTerm: query])
    }

    // MARK: - Onboarding
    static func onboardingStep(_ step: Int) {
        log("onboarding_step", ["step": step])
    }

    static func onboardingComplete() {
        log("onboarding_complete")
    }

    // MARK: - Screen Views
    static func viewConversations() {
        log("view_conversations")
    }

    static func viewConnectionRequests() {
        log("view_connection_requests")
    }

    static func viewConnectionsList() {
        log("view_connections_list")
    }

    // MARK: - Moderation
    static func submitReport(contentType: String) {
        log("submit_report", ["content_type": contentType])
    }

    static func blockUser() {
        log("block_user")
    }

    // MARK: - Misc
    static func forgotPassword() {
        log("forgot_password")
    }

    static func shareContent(contentType: String, contentId: String) {
        log("share_content", ["content_type": contentType, "content_id": contentId])
    }
}
