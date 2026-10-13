//
//  QuizSession.swift
//  Muslim Clock — module ʿIlm, révision hebdomadaire
//
//  État d'une session de quiz (pur, sans persistance) : question courante,
//  choix verrouillé après réponse, score, erreurs. La vue ne fait que l'afficher.
//

import Foundation

nonisolated struct QuizSession: Equatable, Sendable {

    enum Mode: Equatable, Sendable {
        /// Révision de la semaine : le score est enregistré à la fin.
        case weekly
        /// Entraînement libre sur un thème : rien n'est enregistré côté semaine.
        case topic(String)
    }

    let mode: Mode
    let questions: [QuizQuestion]
    private(set) var index = 0
    /// Choix de l'utilisateur pour la question courante — `nil` tant qu'il n'a pas répondu.
    private(set) var selectedChoice: Int?
    private(set) var score = 0
    private(set) var mistakes: [QuizQuestion] = []
    private(set) var isFinished = false

    init(mode: Mode, questions: [QuizQuestion]) {
        self.mode = mode
        self.questions = questions
        self.isFinished = questions.isEmpty
    }

    var current: QuizQuestion? {
        guard !isFinished, questions.indices.contains(index) else { return nil }
        return questions[index]
    }

    var isAnswered: Bool { selectedChoice != nil }
    var isLastQuestion: Bool { index >= questions.count - 1 }
    var total: Int { questions.count }

    var lastAnswerCorrect: Bool? {
        guard let selectedChoice, let current else { return nil }
        return selectedChoice == current.correctIndex
    }

    /// Verrouille le choix. Sans effet si la question a déjà reçu une réponse.
    /// - Returns: la question répondue et la justesse, ou `nil` si ignoré.
    @discardableResult
    mutating func select(_ choice: Int) -> (question: QuizQuestion, correct: Bool)? {
        guard let question = current, selectedChoice == nil, question.choices.indices.contains(choice) else {
            return nil
        }
        selectedChoice = choice
        let correct = choice == question.correctIndex
        if correct { score += 1 } else { mistakes.append(question) }
        return (question, correct)
    }

    /// Passe à la question suivante (ou termine). Sans effet tant que la question n'est pas répondue.
    mutating func advance() {
        guard isAnswered else { return }
        if isLastQuestion {
            isFinished = true
        } else {
            index += 1
            selectedChoice = nil
        }
    }
}
