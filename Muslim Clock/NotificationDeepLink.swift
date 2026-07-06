//
//  NotificationDeepLink.swift
//  Muslim Clock — route persistante posée au tap d'une notification locale.
//
//  Pourquoi : le post NotificationCenter émis dans AppDelegate.didReceive est
//  perdu si l'app démarre à froid (les .onReceive de MainView ne sont pas
//  encore montés). On persiste donc la route dans UserDefaults, consommée par
//  MainView à l'activation — même pattern que `controlDeepLinkTarget`.
//

import Foundation

/// Route de deep link posée par `AppDelegate.didReceive` et consommée par `MainView`.
enum NotificationDeepLink: String {
    case adhan
    case quranTracker = "quran_tracker"
    case adhkarMorning = "adhkar_morning"
    case adhkarEvening = "adhkar_evening"

    // MARK: - Clés UserDefaults (standard — tout est in-app, pas besoin d'App Group)

    static let routeKey = "pending_notification_route"
    static let timestampKey = "pending_notification_timestamp"
    static let adhanNameKey = "pending_adhan_prayer_name"
    static let adhanTimeKey = "pending_adhan_prayer_time"

    /// Fenêtre de validité d'une route pendante (ne pas rejouer un vieux tap).
    static let maxAgeSeconds: TimeInterval = 30
    /// Fenêtre pendant laquelle un tap sur une notif de prière affiche encore
    /// l'overlay Adhan (au-delà, la prière est passée depuis trop longtemps).
    static let adhanReplayWindow: TimeInterval = 30 * 60

    // MARK: - Écriture (AppDelegate)

    static func store(_ route: NotificationDeepLink) {
        let defaults = UserDefaults.standard
        defaults.set(route.rawValue, forKey: routeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: timestampKey)
    }

    static func storeAdhan(prayerName: String, prayerTime: Date) {
        let defaults = UserDefaults.standard
        defaults.set(prayerName, forKey: adhanNameKey)
        defaults.set(prayerTime.timeIntervalSince1970, forKey: adhanTimeKey)
        store(.adhan)
    }

    // MARK: - Lecture (MainView)

    /// Lit puis efface la route pendante. `nil` si absente ou périmée (> 30 s).
    static func consume() -> NotificationDeepLink? {
        let defaults = UserDefaults.standard
        defer { clear() }
        guard let raw = defaults.string(forKey: routeKey),
              let route = NotificationDeepLink(rawValue: raw) else { return nil }
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: timestampKey)
        return age <= maxAgeSeconds ? route : nil
    }

    /// Efface la route pendante sans la lire (appelé par les handlers live de
    /// MainView pour éviter un double déclenchement au prochain passage à .active).
    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: routeKey)
        defaults.removeObject(forKey: timestampKey)
    }
}
