//
//  backlineApp.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import UserNotifications
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Primary Theme Colors (Broadcast Signals palette)

enum ThemeColor {
    // V3 Broadcast Signals — exact hex values
    static let red    = Color(hex: 0xFF3B30)
    static let green  = Color(hex: 0x30D158)
    static let cyan   = Color(hex: 0x32D8E0)
    static let yellow = Color(hex: 0xFFD60A)

    // Keep "blue" as an alias for cyan (backward compat)
    static let blue = cyan

    static let all: [Color] = [cyan, red, yellow, green]

    /// Returns a color cycling through the four primaries by index.
    static func cycle(_ index: Int) -> Color {
        all[index % all.count]
    }

    // Shared border / divider opacity
    static let hairline = Color.white.opacity(0.10)
    static let subtleBorder = Color.white.opacity(0.14)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8)  & 0xFF) / 255.0,
            blue:  Double(hex         & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Safe Logging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    var authManager: AuthenticationManager!
    var listingManager: ListingManager!
    var messagesManager: MessagesManager!
    var connectionsManager: ConnectionsManager!
    var deepLinkRouter: DeepLinkRouter!
    var networkMonitor: NetworkMonitor!

    override init() {
        super.init()
        blPrint("🧩 AppDelegate INIT")
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        authManager = AuthenticationManager()
        listingManager = ListingManager()
        messagesManager = MessagesManager()
        connectionsManager = ConnectionsManager()
        deepLinkRouter = DeepLinkRouter()
        networkMonitor = NetworkMonitor()

        // Push notifications
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationPermission(application)

        return true
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission(_ application: UIApplication) {

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in

            blPrint("🔔 Permission granted:", granted)
            if let error = error {
                blPrint("Permission error:", error)
            }

            DispatchQueue.main.async {
                blPrint("📲 Registering for remote notifications (ALWAYS)")
                application.registerForRemoteNotifications()
            }
        }
    }

    

    // MARK: - APNs Token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        blPrint("📱 APNs Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown)
        
        Messaging.messaging().token { token, error in
                if let error = error {
                    blPrint("FCM error after APNs: \(error)")
                } else {
                    blPrint("🔥 FCM TOKEN (after APNs): \(token ?? "nil")")
                }
            }
    }
    
    
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        blPrint("❌ APNs FAILED:", error)
    }

    // MARK: - FCM Token

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        blPrint("Firebase registration token: \(String(describing: fcmToken))")
        
        guard let token = fcmToken else {
            blPrint("⚠️ Received nil FCM token")
            return
        }
        
        // This is where you actually see it in the console!
        blPrint("🔥 FCM TOKEN RECEIVED: \(token)")
        
        authManager?.updateFCMToken(token)
        
        // Optional: If you need to send it to your server, do it here
        let dataDict: [String: String] = ["token": token]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }

    // MARK: - Foreground Notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Notification Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String,
           type == "message",
           let conversationId = userInfo["conversationId"] as? String {
            deepLinkRouter.pendingDeepLink = .chat(conversationId: conversationId)
        }
        completionHandler()
    }
}

@main
struct backlineApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(delegate.authManager!)
                .environment(delegate.listingManager!)
                .environment(delegate.messagesManager!)
                .environment(delegate.connectionsManager!)
                .environment(delegate.deepLinkRouter!)
                .environment(delegate.networkMonitor!)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                    delegate.deepLinkRouter.handle(url)
                }
        }
    }
}
