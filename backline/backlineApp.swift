//
//  backlineApp.swift
//  backline
//
//  Created by Khadija Aslam on 3/16/26.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    var authManager: AuthenticationManager!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        authManager = AuthenticationManager()

        return true
    }
}

@main
struct backlineApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(delegate.authManager!)
        }
    }
}
