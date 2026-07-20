//  MyJourneyApp.swift
//  MyJourney
//
//  Created by Bhumir Patel on 12/12/25.
//
import FirebaseAppCheck
import Firebase
import Kingfisher
import SwiftUI
import GoogleSignIn


@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        #if targetEnvironment(simulator)
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
        #else
            let providerFactory = YourSimpleAppCheckProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif

        let customCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,
            diskCapacity: 10 * 1024 * 1024,
            diskPath: "URLCache"
        )
        URLCache.shared = customCache

        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.error)


        // Configure Kingfisher Cache (Max 500MB disk space)
        ImageCache.default.diskStorage.config.sizeLimit = 500 * 1024 * 1024

        return true
    }
}

@main
struct JournPathApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
