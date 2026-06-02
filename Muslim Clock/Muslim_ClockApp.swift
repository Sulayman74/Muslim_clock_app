//
//  Muslim_ClockApp.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//

import SwiftUI
import UserNotifications

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. CRÉATION DU DELEGATE POUR GÉRER LES NOTIFICATIONS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Affiche la notif même quand l'app est au foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let userInfo = notification.request.content.userInfo
        if let prayerName = userInfo["prayerName"] as? String,
           let timestamp = userInfo["prayerTime"] as? TimeInterval {
            let prayerTime = Date(timeIntervalSince1970: timestamp)
            NotificationCenter.default.post(
                name: NSNotification.Name("AdhanTriggered"),
                object: nil,
                userInfo: ["prayerName": prayerName, "prayerTime": prayerTime]
            )
        }

        completionHandler([.banner, .sound, .list])
    }

    // Appelée quand l'utilisateur CLIQUE sur la notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        if let prayerName = userInfo["prayerName"] as? String,
           let timestamp = userInfo["prayerTime"] as? TimeInterval {
            let prayerTime = Date(timeIntervalSince1970: timestamp)
            NotificationCenter.default.post(
                name: NSNotification.Name("AdhanTriggered"),
                object: nil,
                userInfo: [
                    "prayerName": prayerName,
                    "prayerTime": prayerTime
                ]
            )
        }

        completionHandler()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2. TON APP PRINCIPALE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@main
struct Muslim_ClockApp: App {
    // On connecte notre AppDelegate au cycle de vie de SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("appLanguage") private var appLanguage = "system"
    
    init() {
        NotificationManager.shared.requestPermission()
        SharedLocationManager.shared.requestPermissionAndStart()
        _ = WatchSessionManager.shared // Démarre la session WatchConnectivity
    }
    
    private var currentLocale: Locale {
        if appLanguage == "system" {
            return .current
        }
        return Locale(identifier: appLanguage)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.locale, currentLocale)
                .preferredColorScheme(.dark)   // App 100% dark — textes blancs toujours lisibles
        }
    }
}
