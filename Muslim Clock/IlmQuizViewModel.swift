//
//  IlmQuizViewModel.swift
//  Muslim Clock — module ʿIlm, révision hebdomadaire
//
//  Pilote la session de la semaine, les sessions par thème et la maîtrise.
//  Pont Leitner : une erreur sur une question liée à une leçon ACQUISE fait
//  revenir cette leçon en révision (boîte 1). Une bonne réponse ne touche pas
//  à Leitner : la flash card reste souveraine pour la mémorisation du matn.
//

import Foundation
import SwiftUI

/// Maîtrise d'un thème : part des questions dont la DERNIÈRE réponse est juste.
struct QuizTopicMastery: Equatable {
    let total: Int
    let answered: Int
    let correct: Int

    var ratio: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

@MainActor
@Observable
final class IlmQuizViewModel {

    private(set) var progress: QuizProgress
    let ilm: IlmViewModel

    /// Taille de la session hebdo (5 / 10 / 20).
    var sessionSize: Int {
        didSet {
            UserDefaults.standard.set(sessionSize, forKey: Self.sessionSizeKey)
            rescheduleReminder()
        }
    }

    static let sessionSizeKey = "ilm_quiz_session_size"

    init(ilm: IlmViewModel) {
        self.ilm = ilm
        self.progress = IlmQuizStorage.loadProgress()
        let stored = UserDefaults.standard.integer(forKey: Self.sessionSizeKey)
        self.sessionSize = WeeklyReviewPlanner.sizePresets.contains(stored) ? stored : WeeklyReviewPlanner.defaultSize
    }

    // MARK: - Contenu

    var isAvailable: Bool { QuizContentLoader.shared.isAvailable }
    var topics: [QuizTopic] { QuizContentLoader.shared.topics }

    func topics(in domain: QuizDomain) -> [QuizTopic] {
        topics.filter { $0.domain == domain }
    }

    // MARK: - Semaine

    var currentWeekKey: String { QuizWeek.key(for: .now) }

    /// Résultat de la session de la semaine en cours, `nil` si pas encore faite.
    var thisWeekResult: WeeklySessionResult? { progress.weeklySessions[currentWeekKey] }

    var weekStreak: Int { QuizWeek.streak(sessions: progress.weeklySessions) }

    var estimatedMinutes: Int { IlmWeeklyReminderScheduler.estimatedMinutes(questionCount: sessionSize) }

    /// Questions de la semaine, figées au premier appel (persistées) : la session
    /// reste la même toute la semaine. Recomposée si la taille a changé.
    func weeklyQuestions(now: Date = .now) -> [QuizQuestion] {
        let weekKey = QuizWeek.key(for: now)
        let loader = QuizContentLoader.shared
        if let ids = progress.plannedWeeks[weekKey], ids.count == min(sessionSize, loader.questions.count) {
            let planned = ids.compactMap(loader.question(id:))
            if planned.count == ids.count { return planned }
        }
        let dueLessons = Set(ilm.progress.nextReviewAt.compactMap { $0.value <= now ? $0.key : nil })
        let built = WeeklyReviewPlanner.build(
            questions: loader.questions,
            topics: loader.topics,
            progress: progress,
            dueLessonIDs: dueLessons,
            weekKey: weekKey,
            weekNumber: QuizWeek.number(for: now),
            size: sessionSize,
            now: now
        )
        progress.storePlan(built.map(\.id), for: weekKey)
        IlmQuizStorage.save(progress)
        return built
    }

    /// Session libre sur un thème : questions non maîtrisées d'abord, puis le reste.
    func topicQuestions(topicID: String, limit: Int = WeeklyReviewPlanner.defaultSize) -> [QuizQuestion] {
        let all = QuizContentLoader.shared.questions(inTopic: topicID).shuffled()
        let notMastered = all.filter { progress.answers[$0.id]?.correct != true }
        let mastered = all.filter { progress.answers[$0.id]?.correct == true }
        return Array((notMastered + mastered).prefix(limit))
    }

    func mastery(topicID: String) -> QuizTopicMastery {
        let questions = QuizContentLoader.shared.questions(inTopic: topicID)
        let records = questions.compactMap { progress.answers[$0.id] }
        return QuizTopicMastery(
            total: questions.count,
            answered: records.count,
            correct: records.filter(\.correct).count
        )
    }

    /// Titre du thème d'une question (écran de fin, liste des erreurs).
    func topicTitle(for question: QuizQuestion) -> String {
        QuizContentLoader.shared.topic(id: question.topicId)?.titleFr ?? ""
    }

    // MARK: - Réponses

    /// Enregistre la réponse et applique le pont Leitner.
    /// - Returns: `true` si la réponse est juste.
    @discardableResult
    func answer(_ question: QuizQuestion, choiceIndex: Int) -> Bool {
        let correct = choiceIndex == question.correctIndex
        progress.recordAnswer(questionID: question.id, correct: correct)
        IlmQuizStorage.save(progress)
        if !correct, let lessonID = question.lessonId, ilm.isCompleted(lessonID) {
            ilm.gradeCard(lessonID, outcome: .forgot)
        }
        return correct
    }

    /// Clôt la session hebdo : enregistre le score de la semaine (le meilleur si refaite).
    func finishWeeklySession(score: Int, total: Int, now: Date = .now) {
        let weekKey = QuizWeek.key(for: now)
        let result = WeeklySessionResult(score: score, total: total, date: now)
        if let previous = progress.weeklySessions[weekKey], previous.score >= score {
            return
        }
        progress.weeklySessions[weekKey] = result
        IlmQuizStorage.save(progress)
        rescheduleReminder()
    }

    /// Recharge depuis le disque (une autre instance a pu écrire entre-temps).
    func refresh() {
        progress = IlmQuizStorage.loadProgress()
    }

    func rescheduleReminder() {
        guard isAvailable else { return }
        IlmWeeklyReminderScheduler.schedule(currentWeekDone: thisWeekResult != nil, questionCount: sessionSize)
    }
}
