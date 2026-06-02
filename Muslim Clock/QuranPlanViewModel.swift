//
//  QuranPlanViewModel.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Pilote l'état du plan + journal pour les Views.
//  Singleton léger : 1 instance vit pendant la session, partage l'état entre les sheets.
//

import Foundation
import SwiftData
import SwiftUI

/// ViewModel du module Quran Reading.
///
/// - Charge le plan courant depuis UserDefaults (singleton via `QuranPlanStorage`).
/// - Calcule la progression à partir des `ReadingEntry` injectées par les Views (`@Query`).
/// - Expose des actions (`logPages`, `savePlan`, `clearPlan`) qui mutent l'état.
@MainActor
@Observable
final class QuranPlanViewModel {

    /// Plan courant. `nil` si l'utilisateur n'a pas encore créé son plan.
    var plan: QuranPlan?

    /// Snapshot calculé à la demande (recalculé via `refresh(entries:)`).
    var progress: QuranPlanProgress?

    /// Streak courant (jours consécutifs objectif atteint).
    var streak: Int = 0

    init() {
        self.plan = QuranPlanStorage.load()
    }

    // MARK: - Mutations plan

    /// Sauvegarde un nouveau plan (création ou modification).
    func savePlan(_ newPlan: QuranPlan) {
        QuranPlanStorage.save(newPlan)
        self.plan = newPlan
    }

    /// Efface le plan courant. Les entrées de journal sont conservées.
    func clearPlan() {
        QuranPlanStorage.clear()
        self.plan = nil
        self.progress = nil
        self.streak = 0
    }

    // MARK: - Recalcul progression

    /// Recalcule la progression et le streak à partir des entries fournies.
    /// À appeler dans la View qui possède le `@Query`.
    func refresh(entries: [ReadingEntry], now: Date = .now) {
        guard let plan else {
            self.progress = nil
            self.streak = 0
            return
        }
        let snap = QuranPlanMath.progress(for: plan, entries: entries, now: now)
        self.progress = snap
        self.streak = QuranPlanMath.streak(
            entries: entries,
            pagesPerDayGoal: snap.pagesPerDay,
            now: now
        )
    }

    // MARK: - Mutations journal

    /// Enregistre `pagesRead` pages lues aujourd'hui dans le `ModelContext`.
    /// Met à jour l'entrée du jour si elle existe, sinon en crée une nouvelle.
    ///
    /// - Parameters:
    ///   - pagesRead: Nombre de pages à ajouter au compteur du jour.
    ///   - context: `ModelContext` SwiftData (injecté depuis la View via `@Environment`).
    func logPages(_ pagesRead: Int, context: ModelContext) {
        guard pagesRead > 0, let plan else { return }
        let today = Calendar.current.startOfDay(for: .now)

        // Chercher l'entrée du jour
        let descriptor = FetchDescriptor<ReadingEntry>(
            predicate: #Predicate { $0.date == today }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.pagesRead += pagesRead
            existing.lastPageReached = min(604, existing.lastPageReached + pagesRead)
        } else {
            // Position de départ pour la première entrée du jour
            let startCursor = lastKnownCursor(context: context) ?? (plan.startPage - 1)
            let entry = ReadingEntry(
                date: today,
                pagesRead: pagesRead,
                lastPageReached: min(604, startCursor + pagesRead)
            )
            context.insert(entry)
        }
        try? context.save()
    }

    /// Renvoie la dernière `lastPageReached` connue (toute date confondue), ou `nil`.
    private func lastKnownCursor(context: ModelContext) -> Int? {
        let descriptor = FetchDescriptor<ReadingEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try? context.fetch(descriptor).first?.lastPageReached
    }
}
