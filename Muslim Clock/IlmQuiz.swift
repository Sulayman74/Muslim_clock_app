//
//  IlmQuiz.swift
//  Muslim Clock — module ʿIlm, révision hebdomadaire (quiz)
//
//  Modèles du quiz : contenu bundlé (`ilm_quiz.json`, partagé avec Android) et
//  progression persistée (UserDefaults, pattern `IlmStorage`).
//  Méthode des Trois Fondements : question → réponse → preuve (dalil).
//

import Foundation
import os

// MARK: - Contenu (bundlé, immuable)

/// Domaine de science d'un thème de révision.
nonisolated enum QuizDomain: String, Codable, Sendable, CaseIterable {
    case aqidah
    case fiqh
    case hadith
}

/// Famille de question (méthode des Trois Fondements).
nonisolated enum QuizQuestionKind: String, Codable, Sendable {
    /// Une notion : « Qu'est-ce que la Hanîfiyya ? »
    case masala
    /// La preuve d'une notion : les choix sont de vrais textes, un seul est la preuve.
    case dalil
    /// Un cas pratique, souvent vrai/faux.
    case application
}

nonisolated enum QuizQuestionFormat: String, Codable, Sendable {
    case mcq
    case trueFalse
}

/// Thème de révision : un regroupement de questions rattaché à un parcours ʿIlm.
nonisolated struct QuizTopic: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let domain: QuizDomain
    let titleFr: String
    let titleAr: String
    /// Parcours `IlmTrack` d'origine (pont vers les leçons).
    let trackId: String?
}

nonisolated struct QuizChoice: Codable, Equatable, Sendable {
    let fr: String
    let ar: String
}

/// Preuve citée : verset (`"40:60"`) ou hadith (`"Tirmidhî 3371"` + degré).
nonisolated struct QuizDalil: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case quran
        case hadith
    }
    let kind: Kind
    let ref: String
    let grading: String?
}

nonisolated struct QuizQuestion: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let topicId: String
    /// Leçon `IlmLesson` liée — pont avec la révision Leitner (une erreur la fait revenir).
    let lessonId: String?
    let kind: QuizQuestionKind
    let format: QuizQuestionFormat
    let difficulty: Int
    let promptFr: String
    let promptAr: String
    let choices: [QuizChoice]
    let correctIndex: Int
    let explanationFr: String
    let explanationAr: String?
    let dalil: [QuizDalil]
    let scholarRef: String?
}

/// Fichier `ilm_quiz.json`. Le décodage des questions est tolérant : une question
/// illisible (champ inconnu d'une version future du schéma) est ignorée et loggée,
/// jamais la totalité du fichier.
nonisolated struct QuizContent: Decodable, Equatable, Sendable {
    let version: Int
    let topics: [QuizTopic]
    let questions: [QuizQuestion]

    init(version: Int, topics: [QuizTopic], questions: [QuizQuestion]) {
        self.version = version
        self.topics = topics
        self.questions = questions
    }

    private enum CodingKeys: String, CodingKey { case version, topics, questions }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        topics = try container.decode([LossyQuizItem<QuizTopic>].self, forKey: .topics).compactMap(\.value)
        questions = try container.decode([LossyQuizItem<QuizQuestion>].self, forKey: .questions).compactMap(\.value)
    }
}

/// Décode un élément ou `nil` (erreur loggée) — empêche une entrée invalide de
/// faire échouer tout le tableau.
private nonisolated struct LossyQuizItem<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        do {
            value = try Wrapped(from: decoder)
        } catch {
            Logger(subsystem: "com.kappsi.muslimclock", category: "IlmQuiz")
                .error("Entrée de quiz ignorée : \(error.localizedDescription)")
            value = nil
        }
    }
}

// MARK: - Progression (UserDefaults)

nonisolated struct QuizAnswerRecord: Codable, Equatable, Sendable {
    /// Dernière réponse donnée à cette question.
    var correct: Bool
    var date: Date
    /// Nombre total de réponses (utile pour prioriser l'inédit).
    var attempts: Int

    init(correct: Bool, date: Date, attempts: Int = 1) {
        self.correct = correct
        self.date = date
        self.attempts = attempts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        correct = try container.decode(Bool.self, forKey: .correct)
        date = try container.decode(Date.self, forKey: .date)
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 1
    }
}

nonisolated struct WeeklySessionResult: Codable, Equatable, Sendable {
    let score: Int
    let total: Int
    let date: Date

    /// Seuil de validation d'une semaine (streak) : 70 %.
    static let passRatio = 0.7

    var isPassed: Bool {
        total > 0 && Double(score) / Double(total) >= Self.passRatio
    }
}

/// Progression du quiz, tous thèmes confondus. Bornée par le contenu (une entrée
/// par question) et par le temps (une entrée par semaine).
nonisolated struct QuizProgress: Codable, Equatable, Sendable {
    var answers: [String: QuizAnswerRecord] = [:]
    /// Résultat de la session hebdo, par clé de semaine ISO (`"2026-W42"`).
    var weeklySessions: [String: WeeklySessionResult] = [:]
    /// Questions retenues pour la semaine, figées au premier affichage : la session
    /// reste identique toute la semaine même si la progression évolue entre-temps.
    var plannedWeeks: [String: [String]] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answers = try container.decodeIfPresent([String: QuizAnswerRecord].self, forKey: .answers) ?? [:]
        weeklySessions = try container.decodeIfPresent([String: WeeklySessionResult].self, forKey: .weeklySessions) ?? [:]
        plannedWeeks = try container.decodeIfPresent([String: [String]].self, forKey: .plannedWeeks) ?? [:]
    }

    mutating func recordAnswer(questionID: String, correct: Bool, on date: Date = .now) {
        let previous = answers[questionID]?.attempts ?? 0
        answers[questionID] = QuizAnswerRecord(correct: correct, date: date, attempts: previous + 1)
    }

    /// Garde les plans des 8 dernières semaines au plus (la taille reste bornée).
    mutating func storePlan(_ questionIDs: [String], for weekKey: String) {
        plannedWeeks[weekKey] = questionIDs
        let keep = plannedWeeks.keys.sorted().suffix(Self.retainedPlannedWeeks)
        plannedWeeks = plannedWeeks.filter { keep.contains($0.key) }
    }

    private static let retainedPlannedWeeks = 8
}

// MARK: - Semaine ISO

/// Clé de semaine ISO-8601 (lundi, semaine 1 = celle du premier jeudi) : `"2026-W42"`.
///
/// Indépendante des réglages régionaux de l'appareil (premier jour de la semaine),
/// contrairement à `Calendar.current`.
nonisolated enum QuizWeek {
    static var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    static func key(for date: Date) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return String(format: "%04d-W%02d", year, week)
    }

    /// Numéro de semaine ISO (1…53), base de la rotation des thèmes.
    static func number(for date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    /// Semaines ISO consécutives validées (≥ 70 %). Si la semaine en cours est déjà
    /// validée, elle compte ; sinon on part de la semaine dernière (pas de pression
    /// en début de semaine — même choix bienveillant que `IlmMath.weekStreak`).
    static func streak(sessions: [String: WeeklySessionResult], now: Date = .now) -> Int {
        let cal = calendar
        var cursor = now
        if sessions[key(for: now)]?.isPassed != true {
            guard let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now) else { return 0 }
            cursor = lastWeek
        }
        var streak = 0
        while sessions[key(for: cursor)]?.isPassed == true {
            streak += 1
            guard let previous = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}

// MARK: - Persistance

enum IlmQuizStorage {
    static let progressKey = "ilm_quiz_progress"

    static func loadProgress() -> QuizProgress {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else { return QuizProgress() }
        do {
            return try JSONDecoder().decode(QuizProgress.self, from: data)
        } catch {
            Logger(subsystem: "com.kappsi.muslimclock", category: "IlmQuiz")
                .error("ilm_quiz_progress illisible, progression réinitialisée : \(error.localizedDescription)")
            return QuizProgress()
        }
    }

    static func save(_ progress: QuizProgress) {
        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: progressKey)
        } catch {
            Logger(subsystem: "com.kappsi.muslimclock", category: "IlmQuiz")
                .error("Sauvegarde ilm_quiz_progress impossible : \(error.localizedDescription)")
        }
    }
}
