//
//  QuranReminderScheduler.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Programme les notifs locales post-prière pour rappeler la lecture du jour.
//  Préfixe ID : "quran_reading_*" — distinct des notifs prière ("prayer_*") et lunes
//  ("newmoon_*") pour permettre un nettoyage ciblé (cf. AUDIT §5).
//

import Foundation
import UserNotifications

/// Mini-représentation d'une prière pour le scheduling, découplée de PrayerTimesViewModel.
struct ScheduledPrayer {
    let name: String   // "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jumu'ah"
    let date: Date
}

enum QuranReminderScheduler {

    /// Préfixe d'identifiant pour toutes les notifs émises par ce scheduler.
    /// **À ne PAS modifier** : `NotificationManager.scheduleBatchNotifications` s'appuie
    /// dessus pour éviter d'écraser ces notifs lors du reschedule des prières.
    static let identifierPrefix = "quran_reading_"

    /// Programme les rappels post-prière pour les prières fournies.
    ///
    /// - Politique : un offset de 60 secondes APRÈS chaque prière (laisse le temps de
    ///   prier). Le scheduler nettoie d'abord toutes ses propres notifs avant de
    ///   reprogrammer — ne touche jamais aux notifs prière/lunes.
    ///
    /// - Parameters:
    ///   - prayers: Liste des prières à utiliser pour les rappels (heure + nom).
    ///     Seules celles correspondant à `plan.prayersToUse` ET dont la date est
    ///     dans le futur seront programmées.
    ///   - plan: Plan courant — fournit `pagesPerPrayer` indirectement via la math.
    ///   - pagesPerPrayer: Pages à lire à chaque prière (calculé par `QuranPlanMath`).
    static func schedule(
        prayers: [ScheduledPrayer],
        plan: QuranPlan,
        pagesPerPrayer: Int
    ) {
        let center = UNUserNotificationCenter.current()

        // 1. Nettoyage sélectif — uniquement les notifs Quran existantes.
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

            // 2. Programmation des nouveaux rappels (uniquement futurs + dans le plan).
            guard plan.notificationsEnabled else { return }
            let now = Date()
            for prayer in prayers
            where plan.prayersToUse.contains(prayer.name) && prayer.date > now {
                Self.schedule(prayer: prayer, pagesPerPrayer: pagesPerPrayer, center: center)
            }
        }
    }

    /// Annule toutes les notifs de lecture (sans toucher aux autres modules).
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Privé

    private static func schedule(
        prayer: ScheduledPrayer,
        pagesPerPrayer: Int,
        center: UNUserNotificationCenter
    ) {
        // Offset post-prière : 1 minute après l'heure de la prière.
        let triggerDate = prayer.date.addingTimeInterval(60)
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "📖 Lecture du Quran")
        content.body = String(
            format: String(localized: "Tes %lld pages après %@ — petit pas, grande constance."),
            pagesPerPrayer, prayer.name
        )
        content.sound = .default
        content.userInfo = [
            "module": "quran_reading",
            "prayerName": prayer.name,
            "pagesTarget": pagesPerPrayer,
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        // ID stable : <prefix>_<prayer>_<yyyy-MM-dd> — évite les doublons sur recall same-day.
        let dayKey = Self.dayKey(prayer.date)
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)\(prayer.name)_\(dayKey)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                print("⚠️ [QuranScheduler] \(prayer.name): \(error.localizedDescription)")
            }
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}
