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
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // On indique au système que cette classe gère les notifications
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // 🔥 FIX CRITIQUE : affiche la notif même quand l'app est au foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // On déclenche aussi l'overlay directement si l'app est ouverte
        let userInfo = notification.request.content.userInfo
        if let prayerName = userInfo["prayerName"] as? String,
           let timestamp = userInfo["prayerTime"] as? TimeInterval {
            let prayerTime = Date(timeIntervalSince1970: timestamp)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AdhanTriggered"),
                    object: nil,
                    userInfo: ["prayerName": prayerName, "prayerTime": prayerTime]
                )
            }
        }
        
        // Et on demande à iOS de montrer banner + son comme en background
        completionHandler([.banner, .sound, .list])
    }
    
    // 🔥 C'est CETTE fonction qui est appelée quand l'utilisateur CLIQUE sur la notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        // On vérifie si la notification contient nos données d'Adhan
        if let prayerName = userInfo["prayerName"] as? String,
           let timestamp = userInfo["prayerTime"] as? TimeInterval {
            
            let prayerTime = Date(timeIntervalSince1970: timestamp)
            
            // On prévient le MainView d'afficher l'Overlay immédiatement !
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AdhanTriggered"),
                    object: nil,
                    userInfo: [
                        "prayerName": prayerName,
                        "prayerTime": prayerTime
                    ]
                )
            }
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
