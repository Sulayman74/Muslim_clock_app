//
//  IlmReminderScheduler.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Rappel quotidien d'étude. UNE seule notif pendante (trigger calendaire répétitif)
//  — budget notifications minimal (limite iOS 64, déjà consommée par prières +
//  quran_reading_). Préfixe ID : "ilm_reminder_" — distinct des autres modules.
//

import Foundation
import UserNotifications

enum IlmReminderScheduler {

    /// Préfixe d'identifiant pour toutes les notifs émises par ce scheduler.
    /// Distinct de "prayer_*", "newmoon_*" et "quran_reading_*" → coexistence garantie.
    static let identifierPrefix = "ilm_reminder_"

    /// (Re)programme le rappel quotidien selon le plan. Idempotent : remove ciblé puis add.
    /// No-op (nettoyage seul) si `plan` est nil ou rappel désactivé.
    static func schedule(plan: IlmPlan?, nextLessonTitle: String?) {
        Task {
            let center = UNUserNotificationCenter.current()

            // 1. Nettoyage sélectif — uniquement nos notifs.
            let pending = await center.pendingNotificationRequests()
            let idsToRemove = pending
                .filter { $0.identifier.hasPrefix(Self.identifierPrefix) }
                .map { $0.identifier }
            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

            // 2. Re-add si actif.
            guard let plan, plan.reminderEnabled else { return }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "📚 Leçon du jour")
            if let nextLessonTitle {
                content.body = String(
                    format: String(localized: "%@ — quelques minutes suffisent, la constance fait le reste."),
                    nextLessonTitle
                )
            } else {
                content.body = String(localized: "Un peu de science aujourd'hui — quelques minutes suffisent.")
            }
            content.sound = .default
            content.userInfo = ["module": "ilm_program"]

            // Trigger calendaire répétitif (heure locale) : gère DST nativement,
            // 1 seule notif pendante au total.
            var comps = DateComponents()
            comps.hour = plan.reminderHour
            comps.minute = plan.reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(Self.identifierPrefix)daily",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                print("⚠️ [IlmScheduler] rappel quotidien: \(error.localizedDescription)")
            }
        }
    }

    /// Annule le rappel (sans toucher aux autres modules).
    static func cancelAll() {
        schedule(plan: nil, nextLessonTitle: nil)
    }
}
