//
//  IlmMath.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Fonctions pures de calcul de progression. Pas d'état, pas de SwiftUI,
//  testable en isolation (pattern QuranPlanMath).
//
//  Complexité : tout est O(1) (lookups dictionnaire) ou O(n) avec n = nombre de
//  leçons du contenu bundlé (≤ ~70, constante de compilation) → constant de fait.
//

import Foundation

/// Snapshot de progression d'un parcours pour un plan donné (non persisté).
struct IlmProgressSummary: Equatable {
    let totalLessons: Int
    let completedLessons: Int
    /// 0…1 sur le parcours actif.
    let percentComplete: Double
    /// Index (0-based) de la première leçon non acquise — `nil` si parcours terminé.
    let nextLessonIndex: Int?
    /// Leçons attendues à date selon le rythme (plafonné au total).
    let expectedLessons: Int
    /// Acquises − attendues (positif = avance, négatif = à rattraper).
    let balance: Int
    /// Date de fin estimée au rythme choisi — `nil` si parcours terminé.
    let estimatedEndDate: Date?
    /// Semaines consécutives (jusqu'à la semaine dernière incluse) avec objectif atteint.
    let weekStreak: Int
}

/// Une carte de révision : leçon due + parcours d'origine (pour l'affichage).
struct IlmReviewCard: Identifiable, Equatable {
    let trackID: String
    let trackTitle: String
    let lesson: IlmLesson
    var id: String { lesson.id }
}

enum IlmMath {

    /// Calcule le snapshot de progression d'un parcours.
    ///
    /// - Parameters:
    ///   - track: Parcours actif (contenu bundlé).
    ///   - plan: Plan courant (rythme + date de début).
    ///   - progress: Progression globale (dates d'acquisition par leçon).
    ///   - now: Date courante (injectable pour tests, notamment DST).
    static func summary(
        track: IlmTrack,
        plan: IlmPlan,
        progress: IlmProgress,
        now: Date = .now
    ) -> IlmProgressSummary {
        let total = track.lessons.count
        let completed = completedCount(in: track, progress: progress)
        let percent = total > 0 ? min(1.0, Double(completed) / Double(total)) : 0
        let nextIndex = nextLessonIndex(in: track, progress: progress)

        // Attendu : rythme hebdo ramené au jour, × jours écoulés (inclusifs), plafonné.
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: plan.startDate)
        let today = cal.startOfDay(for: now)
        let daysElapsed = max(1, (cal.dateComponents([.day], from: startDay, to: today).day ?? 0) + 1)
        let perWeek = max(1, plan.lessonsPerWeek)
        let expected = min(total, Int(ceil(Double(daysElapsed) * Double(perWeek) / 7.0)))
        let balance = completed - expected

        // Fin estimée : leçons restantes au rythme choisi.
        let remaining = total - completed
        let estimatedEnd: Date?
        if remaining > 0 {
            let daysNeeded = Int(ceil(Double(remaining) * 7.0 / Double(perWeek)))
            estimatedEnd = cal.date(byAdding: .day, value: daysNeeded, to: today)
        } else {
            estimatedEnd = nil
        }

        let streak = weekStreak(
            completionDates: completionDates(in: track, progress: progress),
            lessonsPerWeekGoal: perWeek,
            now: now
        )

        return IlmProgressSummary(
            totalLessons: total,
            completedLessons: completed,
            percentComplete: percent,
            nextLessonIndex: nextIndex,
            expectedLessons: expected,
            balance: balance,
            estimatedEndDate: estimatedEnd,
            weekStreak: streak
        )
    }

    /// Nombre de leçons acquises dans un parcours.
    static func completedCount(in track: IlmTrack, progress: IlmProgress) -> Int {
        track.lessons.reduce(0) { $0 + (progress.isCompleted($1.id) ? 1 : 0) }
    }

    /// Index (0-based) de la première leçon non acquise, dans l'ordre canonique.
    /// `nil` si toutes les leçons sont acquises.
    static func nextLessonIndex(in track: IlmTrack, progress: IlmProgress) -> Int? {
        track.lessons.firstIndex { !progress.isCompleted($0.id) }
    }

    /// Dates d'acquisition des leçons d'un parcours (pour le streak).
    static func completionDates(in track: IlmTrack, progress: IlmProgress) -> [Date] {
        track.lessons.compactMap { progress.completedAt[$0.id] }
    }

    // MARK: - File de révision (flash cards)

    /// Cartes dues aujourd'hui, tous parcours confondus (y compris les parcours
    /// terminés — c'est là que la révision a le plus de valeur), triées des plus
    /// en retard aux plus récentes. O(n) avec n ≤ ~70.
    static func reviewQueue(
        tracks: [IlmTrack],
        progress: IlmProgress,
        now: Date = .now
    ) -> [IlmReviewCard] {
        tracks
            .flatMap { track in
                track.lessons.compactMap { lesson -> IlmReviewCard? in
                    guard progress.isDue(lesson.id, now: now) else { return nil }
                    return IlmReviewCard(trackID: track.id, trackTitle: track.title, lesson: lesson)
                }
            }
            .sorted {
                (progress.nextReviewAt[$0.lesson.id] ?? now) < (progress.nextReviewAt[$1.lesson.id] ?? now)
            }
    }

    // MARK: - Streak hebdomadaire

    /// Streak = semaines calendaires consécutives, en remontant depuis la **semaine
    /// dernière** (la semaine en cours ne compte pas — même choix bienveillant que le
    /// streak Khatma : pas de pression en début de période).
    ///
    /// Une semaine est validée si le nombre de leçons acquises pendant cette semaine
    /// atteint l'objectif `lessonsPerWeekGoal`.
    static func weekStreak(
        completionDates: [Date],
        lessonsPerWeekGoal: Int,
        now: Date = .now
    ) -> Int {
        let cal = Calendar.current
        guard let currentWeek = cal.dateInterval(of: .weekOfYear, for: now),
              let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start) else {
            return 0
        }

        // Regroupe les acquisitions par début de semaine calendaire.
        var countByWeekStart: [Date: Int] = [:]
        for date in completionDates {
            guard let week = cal.dateInterval(of: .weekOfYear, for: date) else { continue }
            countByWeekStart[week.start, default: 0] += 1
        }

        var streak = 0
        var cursor = lastWeekStart
        while let count = countByWeekStart[cursor], count >= lessonsPerWeekGoal {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
