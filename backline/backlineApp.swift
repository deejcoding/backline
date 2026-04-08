//
//  backlineApp.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseCore
import UserNotifications
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var authManager: AuthenticationManager!
    var listingManager: ListingManager!
    var messagesManager: MessagesManager!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        authManager = AuthenticationManager()
        listingManager = ListingManager()
        messagesManager = MessagesManager()

        // Push notifications
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission(application)

        return true
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - URL Handling (Google Sign-In)

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }

    // MARK: - APNs Token
    // Once you add FirebaseMessaging to your target's frameworks, uncomment the
    // Messaging lines below to enable FCM token registration.

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - Foreground Notifications

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
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
                .preferredColorScheme(.dark)
        }
    }
}
