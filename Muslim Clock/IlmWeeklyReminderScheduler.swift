//
//  IlmWeeklyReminderScheduler.swift
//  Muslim Clock — module ʿIlm, révision hebdomadaire
//
//  Rappel de la révision de la semaine. Préfixe "ilm_weekly_" — DISTINCT de
//  "ilm_reminder_" : `IlmReminderScheduler` purge tout son préfixe à chaque
//  reprogrammation et effacerait ce rappel.
//
//  Triggers non répétitifs (2 au plus : cette semaine si la session n'est pas
//  faite, puis la suivante) plutôt qu'un trigger hebdo répétitif : on ne
//  rappelle jamais une révision déjà faite.
//

import Foundation
import UserNotifications

enum IlmWeeklyReminderScheduler {

    static let identifierPrefix = "ilm_weekly_"
    /// Valeur de `userInfo["module"]`, routée par `AppDelegate.didReceive`.
    static let module = "ilm_weekly_quiz"

    // MARK: Réglages (UserDefaults, lus aussi par la carte et les Réglages)

    static let enabledKey = "ilm_weekly_reminder_enabled"
    static let weekdayKey = "ilm_weekly_reminder_weekday"
    static let hourKey = "ilm_weekly_reminder_hour"

    /// Vendredi (calendrier grégorien : dimanche = 1).
    static let defaultWeekday = 6
    static let defaultHour = 18

    /// (Re)programme les rappels. Idempotent : purge ciblée puis ajout.
    ///
    /// - Parameters:
    ///   - currentWeekDone: la session de la semaine en cours est terminée → pas de
    ///     rappel cette semaine, seulement la suivante.
    ///   - questionCount: taille de session affichée dans le texte.
    static func schedule(currentWeekDone: Bool, questionCount: Int, now: Date = .now) {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        let weekday = defaults.object(forKey: weekdayKey) as? Int ?? defaultWeekday
        let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour

        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            )
            guard enabled else { return }

            for fireDate in fireDates(weekday: weekday, hour: hour, currentWeekDone: currentWeekDone, now: now) {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "🎓 Révision de la semaine")
                content.body = String(
                    format: String(localized: "%lld questions, environ %lld min — la science s'entretient."),
                    questionCount,
                    estimatedMinutes(questionCount: questionCount)
                )
                content.sound = .default
                content.threadIdentifier = "ilm_program"
                content.userInfo = ["module": module]

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let request = UNNotificationRequest(
                    identifier: identifierPrefix + QuizWeek.key(for: fireDate),
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                )
                do {
                    try await center.add(request)
                } catch {
                    print("⚠️ [IlmWeeklyScheduler] rappel hebdo: \(error.localizedDescription)")
                }
            }
        }
    }

    static func cancelAll() {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            )
        }
    }

    /// Prochaines occurrences du créneau : celle de la semaine ISO en cours (si
    /// future et session non faite) et celle de la semaine suivante.
    nonisolated static func fireDates(weekday: Int, hour: Int, currentWeekDone: Bool, now: Date) -> [Date] {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = weekday
        comps.hour = hour
        comps.minute = 0
        guard let first = cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) else { return [] }
        var dates: [Date] = []
        let firstIsThisWeek = QuizWeek.key(for: first) == QuizWeek.key(for: now)
        if !(firstIsThisWeek && currentWeekDone) { dates.append(first) }
        if let second = cal.nextDate(after: first, matching: comps, matchingPolicy: .nextTime) {
            dates.append(second)
        }
        return Array(dates.prefix(2))
    }

    /// ~35 s par question (lecture, réponse, explication), arrondi à la minute supérieure.
    nonisolated static func estimatedMinutes(questionCount: Int) -> Int {
        max(1, Int((Double(questionCount) * 35 / 60).rounded(.up)))
    }
}
