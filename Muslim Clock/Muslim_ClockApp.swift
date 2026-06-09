//
//  Muslim_ClockApp.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//

import SwiftUI
import SwiftData
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

        // Notif prière → AdhanOverlay
        if let prayerName = userInfo["prayerName"] as? String,
           let timestamp = userInfo["prayerTime"] as? TimeInterval,
           userInfo["module"] as? String != "quran_reading" {
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

        // Notif rappel Quran → ouvre la sheet QuranTrackerView
        if userInfo["module"] as? String == "quran_reading" {
            // Flag persistant pour le cas où la card n'est pas encore montée
            UserDefaults.standard.set(true, forKey: "pendingOpenQuranTracker")
            // Notification live pour MainView (switch tab) et QuranKhatmaCard (open sheet)
            NotificationCenter.default.post(name: .quranReadingTapped, object: nil)
        }

        // Notif rappel Adhkar (matin/soir) → ouvre la sheet AdhkarView au bon timing
        if userInfo["module"] as? String == "adhkar_reminder",
           let timing = userInfo["timing"] as? String {
            NotificationCenter.default.post(
                name: .adhkarReminderTapped,
                object: nil,
                userInfo: ["timing": timing]
            )
        }

        completionHandler()
    }
}

// MARK: - Notification names

extension Notification.Name {
    /// Émise quand l'utilisateur tape une notif de rappel Quran. MainView switche
    /// vers la tab Rappel ; QuranKhatmaCard ouvre la sheet Tracker.
    static let quranReadingTapped = Notification.Name("QuranReadingTapped")

    /// Émise quand l'utilisateur tape une notif de rappel Adhkar (matin ou soir).
    /// `userInfo["timing"]` contient "morning" ou "evening". MainView ouvre la sheet
    /// `AdhkarView` avec ce timing forcé (au lieu de l'auto-détection).
    static let adhkarReminderTapped = Notification.Name("AdhkarReminderTapped")
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 2. TON APP PRINCIPALE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@main
struct Muslim_ClockApp: App {
    // On connecte notre AppDelegate au cycle de vie de SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("appLanguage") private var appLanguage = "system"
    @Environment(\.scenePhase) private var scenePhase

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
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        // Rattrape les transitions Live Activity ratées pendant la suspension
                        // (bascule isPrayerTime=true et close après linger 5 min).
                        // Le démarrage de nouvelles activities reste piloté par PrayerTimesViewModel.
                        SalatLiveActivityManager.shared.syncActiveActivitiesState()
                    }
                }
        }
        // SwiftData : conteneur du journal de lecture du Quran.
        .modelContainer(for: ReadingEntry.self)
    }
}
