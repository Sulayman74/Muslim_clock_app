//
//  IlmViewModel.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Pilote l'état plan + progression pour les Views (pattern QuranPlanViewModel).
//  Les Views ne touchent jamais UserDefaults ni le loader — tout passe par ici.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class IlmViewModel {

    /// Plan courant. `nil` si l'utilisateur n'a pas encore créé son programme.
    var plan: IlmPlan?

    /// Progression globale (tous parcours).
    var progress: IlmProgress

    /// Snapshot du parcours actif (recalculé via `refresh()` après chaque mutation).
    var summary: IlmProgressSummary?

    /// Cartes dues aujourd'hui (tous parcours), triées des plus en retard d'abord.
    var reviewQueue: [IlmReviewCard] = []

    init() {
        self.plan = IlmStorage.loadPlan()
        self.progress = IlmStorage.loadProgress()
        refresh()
    }

    // MARK: - Accès contenu

    var tracks: [IlmTrack] { IlmContentLoader.shared.tracks }

    var activeTrack: IlmTrack? {
        guard let plan else { return nil }
        return IlmContentLoader.shared.track(id: plan.trackID)
    }

    /// Prochaine leçon à étudier dans le parcours actif — `nil` si terminé ou sans plan.
    var nextLesson: IlmLesson? {
        guard let track = activeTrack, let index = summary?.nextLessonIndex else { return nil }
        return track.lessons[index]
    }

    /// Nombre de leçons acquises d'un parcours donné (pour la liste des parcours).
    func completedCount(in track: IlmTrack) -> Int {
        IlmMath.completedCount(in: track, progress: progress)
    }

    func isCompleted(_ lessonID: String) -> Bool {
        progress.isCompleted(lessonID)
    }

    // MARK: - Mutations plan

    /// Sauvegarde un nouveau plan (création ou modification) et re-programme le rappel.
    func savePlan(_ newPlan: IlmPlan) {
        IlmStorage.save(newPlan)
        self.plan = newPlan
        refresh()
        rescheduleReminder()
    }

    /// Efface le plan courant. La progression est conservée (aucune leçon perdue).
    func clearPlan() {
        IlmStorage.clearPlan()
        self.plan = nil
        self.summary = nil
        IlmReminderScheduler.cancelAll()
    }

    // MARK: - Mutations progression

    /// Marque une leçon comme acquise (validation explicite uniquement).
    func completeLesson(_ lessonID: String) {
        progress.complete(lessonID)
        IlmStorage.save(progress)
        refresh()
        rescheduleReminder()
    }

    /// Décoche une leçon (erreur de tap) — sans friction ni message.
    func uncompleteLesson(_ lessonID: String) {
        progress.uncomplete(lessonID)
        IlmStorage.save(progress)
        refresh()
        rescheduleReminder()
    }

    /// Applique le résultat d'une flash card (transition Leitner) et re-persiste.
    func gradeCard(_ lessonID: String, outcome: IlmReviewOutcome) {
        progress.gradeReview(lessonID, outcome: outcome)
        IlmStorage.save(progress)
        refresh()
    }

    // MARK: - Recalcul

    /// Recalcule le snapshot du parcours actif et la file de révision.
    /// O(n) avec n ≤ ~70 (contenu figé).
    func refresh(now: Date = .now) {
        // La file de révision vit indépendamment du plan actif : on continue de
        // réviser un parcours terminé même après avoir changé de programme.
        reviewQueue = IlmMath.reviewQueue(tracks: tracks, progress: progress, now: now)

        guard let plan, let track = activeTrack else {
            summary = nil
            return
        }
        summary = IlmMath.summary(track: track, plan: plan, progress: progress, now: now)
    }

    /// Met à jour le corps du rappel quotidien avec le titre de la prochaine leçon.
    func rescheduleReminder() {
        IlmReminderScheduler.schedule(plan: plan, nextLessonTitle: nextLesson?.title)
    }
}
