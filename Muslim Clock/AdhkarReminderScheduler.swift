//
//  AdhkarReminderScheduler.swift
//  Muslim Clock — rappels Adhkar post-prière
//
//  Programme les notifs locales :
//  - après Fajr  → rappel "Adhkar du matin"
//  - après Asr   → rappel "Adhkar du soir"
//
//  Préfixe ID : "adhkar_reminder_" — distinct des notifs prière ("prayer_*"),
//  Quran ("quran_reading_*") et lunes ("newmoon_*") pour nettoyage ciblé.
//
//  Pour éviter le double-tap avec un rappel Coran sur la même prière,
//  l'offset Adhkar par défaut (5 min) est plus court que l'offset Coran (10 min),
//  ce qui sépare naturellement les deux notifications de ~5 minutes.
//

import Foundation
import UserNotifications

enum AdhkarReminderScheduler {

    /// Préfixe d'identifiant pour toutes les notifs émises par ce scheduler.
    /// Garanti distinct de `quran_reading_`, `prayer_`, `newmoon_` pour cleanup ciblé.
    static let identifierPrefix = "adhkar_reminder_"

    /// Programme les rappels Adhkar pour Fajr et/ou Asr selon les toggles.
    ///
    /// Trigger = `adhan + (iqamahDelay[prière] + reminderOffset) × 60`.
    ///
    /// - Parameters:
    ///   - prayers: Liste des prières du jour (au moins Fajr et Asr attendus).
    ///   - morningEnabled: Active la notif post-Fajr.
    ///   - eveningEnabled: Active la notif post-Asr.
    ///   - iqamahDelaysMinutes: Délai iqamah par prière (clé = nom FR). Manquant ⇒ 0.
    ///   - reminderOffsetMinutes: Marge entre la fin de la prière (iqamah) et le rappel.
    static func schedule(
        prayers: [ScheduledPrayer],
        morningEnabled: Bool,
        eveningEnabled: Bool,
        iqamahDelaysMinutes: [String: Int] = [:],
        reminderOffsetMinutes: Int = 5
    ) {
        Task {
            await Self.scheduleAsync(
                prayers: prayers,
                morningEnabled: morningEnabled,
                eveningEnabled: eveningEnabled,
                iqamahDelaysMinutes: iqamahDelaysMinutes,
                reminderOffsetMinutes: reminderOffsetMinutes
            )
        }
    }

    private static func scheduleAsync(
        prayers: [ScheduledPrayer],
        morningEnabled: Bool,
        eveningEnabled: Bool,
        iqamahDelaysMinutes: [String: Int],
        reminderOffsetMinutes: Int
    ) async {
        let center = UNUserNotificationCenter.current()

        // 1. Nettoyage sélectif — uniquement les notifs Adhkar existantes.
        let requests = await center.pendingNotificationRequests()
        let idsToRemove = requests
            .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        guard morningEnabled || eveningEnabled else { return }

        let now = Date()
        for prayer in prayers where prayer.date > now {
            let isMorning = prayer.name == "Fajr" && morningEnabled
            let isEvening = prayer.name == "Asr" && eveningEnabled
            guard isMorning || isEvening else { continue }

            let iqamah = iqamahDelaysMinutes[prayer.name] ?? 0
            let offsetSeconds = TimeInterval((iqamah + reminderOffsetMinutes) * 60)
            await Self.schedule(
                prayer: prayer,
                timing: isMorning ? .morning : .evening,
                offsetSeconds: offsetSeconds,
                center: center
            )
        }
    }

    /// Annule toutes les notifs Adhkar (sans toucher aux autres modules).
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

    private enum Timing: String {
        case morning, evening

        var title: String {
            switch self {
            case .morning: return String(localized: "🌅 Adhkar du matin")
            case .evening: return String(localized: "🌙 Adhkar du soir")
            }
        }

        var body: String {
            switch self {
            case .morning: return String(localized: "Renouvèle ta journée par les invocations du matin.")
            case .evening: return String(localized: "Adoucis ta soirée par les invocations du soir.")
            }
        }

        /// Cible deep-link consommée par MainView pour ouvrir la sheet Adhkar.
        var deepLinkTarget: String {
            switch self {
            case .morning: return "adhkar_morning"
            case .evening: return "adhkar_evening"
            }
        }
    }

    private static func schedule(
        prayer: ScheduledPrayer,
        timing: Timing,
        offsetSeconds: TimeInterval,
        center: UNUserNotificationCenter
    ) async {
        let triggerDate = prayer.date.addingTimeInterval(offsetSeconds)
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let content = UNMutableNotificationContent()
        content.title = timing.title
        content.body = timing.body
        content.sound = .default
        content.userInfo = [
            "module": "adhkar_reminder",
            "timing": timing.rawValue,
            "deepLinkTarget": timing.deepLinkTarget,
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let dayKey = Self.dayKeyFormatter.string(from: prayer.date)
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)\(timing.rawValue)_\(dayKey)",
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            print("⚠️ [AdhkarScheduler] \(timing.rawValue): \(error.localizedDescription)")
        }
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
