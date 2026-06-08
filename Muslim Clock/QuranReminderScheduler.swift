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
        // Wrap async dans un Task — la signature reste fire-and-forget pour les callers existants.
        Task {
            await Self.scheduleAsync(
                prayers: prayers,
                plan: plan,
                pagesPerPrayer: pagesPerPrayer,
                iqamahDelaysMinutes: iqamahDelaysMinutes,
                reminderOffsetMinutes: reminderOffsetMinutes
            )
        }
    }

    /// Variante async : séquence remove → add garantie linéaire (évite la race entre
    /// `getPendingNotificationRequests` callback et `add(request:)` callback).
    private static func scheduleAsync(
        prayers: [ScheduledPrayer],
        plan: QuranPlan,
        pagesPerPrayer: Int,
        iqamahDelaysMinutes: [String: Int],
        reminderOffsetMinutes: Int
    ) async {
        let center = UNUserNotificationCenter.current()

        // 1. Nettoyage sélectif — uniquement les notifs Quran existantes.
        let requests = await center.pendingNotificationRequests()
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
            await Self.schedule(
                prayer: prayer,
                pagesPerPrayer: pagesPerPrayer,
                offsetSeconds: offsetSeconds,
                center: center
            )
        }
    }

    /// Annule toutes les notifs de lecture (sans toucher aux autres modules).
    static func cancelAll() {
        Task {
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
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
    ) async {
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
        do {
            try await center.add(request)
        } catch {
            print("⚠️ [QuranScheduler] \(prayer.name): \(error.localizedDescription)")
        }
    }

    /// DateFormatter réutilisable pour les clés de notification (évite la recréation à chaque appel).
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayKey(_ date: Date) -> String {
        Self.dayKeyFormatter.string(from: date)
    }
}
