//
//  QuranPlanMath.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Fonctions pures de calcul du plan. Pas d'état, pas de SwiftUI, testable en isolation.
//

import Foundation

/// Agrégat de calculs dérivés d'un plan + entries journalisées.
struct QuranPlanProgress: Equatable {
    /// Pages totales du plan (endPage - startPage + 1).
    let totalPages: Int
    /// Jours totaux planifiés.
    let totalDays: Int
    /// Pages/jour à viser (arrondi up).
    let pagesPerDay: Int
    /// Pages/prière à viser (arrondi up sur le sous-ensemble de prières sélectionné).
    let pagesPerPrayer: Int
    /// Pages déjà lues (réel — somme des `pagesRead` jusqu'à aujourd'hui inclus).
    let pagesReadActual: Int
    /// Pages attendues à date selon le rythme théorique (`daysElapsed × pagesPerDay`).
    let pagesReadTheoretical: Int
    /// Différence (positif = avance, négatif = retard).
    let balance: Int
    /// Pourcentage d'avancement réel sur le plan total (0…1).
    let percentComplete: Double
    /// Pages restantes (≥ 0).
    let pagesRemaining: Int
    /// Jours restants jusqu'à la fin du plan (≥ 0).
    let daysRemaining: Int
    /// Date de fin théorique (calculée selon `goalType`).
    let endDate: Date
}

enum QuranPlanMath {

    // MARK: - Date helpers

    /// Renvoie la date de fin théorique du plan selon son `goalType`.
    static func endDate(of plan: QuranPlan) -> Date {
        let cal = Calendar.current
        switch plan.goalType {
        case .byDuration:
            let days = max(1, Int(plan.goalValue))
            return cal.date(byAdding: .day, value: days, to: plan.startDate) ?? plan.startDate
        case .byPages:
            // Si l'objectif est en pages, on déduit la durée via les pages/jour
            // par défaut (20 pages/jour ≈ 1 juz). Convention conservatrice.
            let totalPages = max(1, Int(plan.goalValue))
            let assumedPagesPerDay = 20
            let days = Int(ceil(Double(totalPages) / Double(assumedPagesPerDay)))
            return cal.date(byAdding: .day, value: days, to: plan.startDate) ?? plan.startDate
        case .byDate:
            return Date(timeIntervalSince1970: plan.goalValue)
        }
    }

    /// Nombre de jours **inclusifs** entre `start` et `end` (≥ 1).
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        let comps = cal.dateComponents([.day], from: s, to: e)
        return max(1, (comps.day ?? 0) + 1)
    }

    // MARK: - Progress

    /// Calcule l'agrégat de progression d'un plan à un instant donné.
    ///
    /// - Parameters:
    ///   - plan: Plan en cours.
    ///   - entries: Toutes les entrées de journal (filtrage interne pour `>= startDate`).
    ///   - now: Date courante (injectable pour tests).
    /// - Returns: Snapshot de progression.
    static func progress(
        for plan: QuranPlan,
        entries: [ReadingEntry],
        now: Date = .now
    ) -> QuranPlanProgress {
        let end = endDate(of: plan)
        let totalPages = max(1, plan.endPage - plan.startPage + 1)
        let totalDays = daysBetween(plan.startDate, end)
        let pagesPerDay = Int(ceil(Double(totalPages) / Double(totalDays)))
        let prayerCount = max(1, plan.prayersToUse.count)
        let pagesPerPrayer = Int(ceil(Double(pagesPerDay) / Double(prayerCount)))

        // Réel : somme des pages lues depuis le début du plan jusqu'à aujourd'hui (inclus).
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: plan.startDate)
        let today = cal.startOfDay(for: now)
        let pagesReadActual = entries
            .filter { $0.date >= startDay && $0.date <= today }
            .reduce(0) { $0 + $1.pagesRead }

        // Théorique : jours écoulés × pagesPerDay (plafonné par totalPages).
        let daysElapsed = daysBetween(startDay, today)
        let pagesReadTheoretical = min(totalPages, daysElapsed * pagesPerDay)

        let balance = pagesReadActual - pagesReadTheoretical
        let percent = min(1.0, Double(pagesReadActual) / Double(totalPages))
        let pagesRemaining = max(0, totalPages - pagesReadActual)
        let daysRemaining = max(0, daysBetween(today, end) - 1)

        return QuranPlanProgress(
            totalPages: totalPages,
            totalDays: totalDays,
            pagesPerDay: pagesPerDay,
            pagesPerPrayer: pagesPerPrayer,
            pagesReadActual: pagesReadActual,
            pagesReadTheoretical: pagesReadTheoretical,
            balance: balance,
            percentComplete: percent,
            pagesRemaining: pagesRemaining,
            daysRemaining: daysRemaining,
            endDate: end
        )
    }

    // MARK: - Streak

    /// Streak = nombre de jours consécutifs (jusqu'à hier inclus) avec `pagesRead ≥ goal`.
    /// On ne compte pas aujourd'hui pour éviter de mettre la pression à l'utilisateur en
    /// début de journée — c'est un choix UX bienveillant (cf. AUDIT §6).
    static func streak(
        entries: [ReadingEntry],
        pagesPerDayGoal: Int,
        now: Date = .now
    ) -> Int {
        let cal = Calendar.current
        let yesterday = cal.startOfDay(for: cal.date(byAdding: .day, value: -1, to: now) ?? now)
        let dict = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
            .mapValues { $0.reduce(0) { $0 + $1.pagesRead } }

        var streak = 0
        var cursor = yesterday
        while let pages = dict[cursor], pages >= pagesPerDayGoal {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
