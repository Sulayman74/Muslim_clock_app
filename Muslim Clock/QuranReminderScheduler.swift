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
    /// - Politique de timing : trigger date = `adhan + (iqamahDelay[prière] + reminderOffset) × 60`
    ///   pour laisser le temps de prier avant le rappel de lecture.
    ///
    /// - Parameters:
    ///   - prayers: Liste des prières à utiliser pour les rappels (heure + nom).
    ///   - plan: Plan courant.
    ///   - pagesPerPrayer: Pages à lire à chaque prière.
    ///   - iqamahDelaysMinutes: Délai iqamah par prière (clé = nom FR : "Fajr", "Dhuhr"…). Manquant ⇒ 0.
    ///   - reminderOffsetMinutes: Marge entre la fin de la prière (iqamah ou adhan) et le rappel.
    static func schedule(
        prayers: [ScheduledPrayer],
        plan: QuranPlan,
        pagesPerPrayer: Int,
        iqamahDelaysMinutes: [String: Int] = [:],
        reminderOffsetMinutes: Int = 10
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
                // Jumu'ah partage le délai iqamah de Dhuhr (même prière de midi).
                let iqamahKey = (prayer.name == "Jumu'ah") ? "Dhuhr" : prayer.name
                let iqamah = iqamahDelaysMinutes[iqamahKey] ?? 0
                let offsetSeconds = TimeInterval((iqamah + reminderOffsetMinutes) * 60)
                Self.schedule(
                    prayer: prayer,
                    pagesPerPrayer: pagesPerPrayer,
                    offsetSeconds: offsetSeconds,
                    center: center
                )
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
        offsetSeconds: TimeInterval,
        center: UNUserNotificationCenter
    ) {
        // Offset post-prière configurable (iqamah + délai de rappel).
        let triggerDate = prayer.date.addingTimeInterval(offsetSeconds)
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
