//
//  QuizContentLoader.swift
//  Muslim Clock — module ʿIlm, révision hebdomadaire
//
//  Charge ilm_quiz.json depuis le bundle (une lecture, cache mémoire — pattern
//  IlmContentLoader). Contenu religieux rédigé hors ligne et relu : jamais de
//  génération à l'exécution, jamais de remote.
//

import Foundation
import os

final class QuizContentLoader {

    static let shared = QuizContentLoader()

    let topics: [QuizTopic]
    let questions: [QuizQuestion]

    private let questionByID: [String: QuizQuestion]
    private let topicByID: [String: QuizTopic]

    var isAvailable: Bool { !questions.isEmpty }

    func question(id: String) -> QuizQuestion? { questionByID[id] }
    func topic(id: String) -> QuizTopic? { topicByID[id] }

    func questions(inTopic topicID: String) -> [QuizQuestion] {
        questions.filter { $0.topicId == topicID }
    }

    private init() {
        let logger = Logger(subsystem: "com.kappsi.muslimclock", category: "IlmQuiz")
        var content = QuizContent(version: 1, topics: [], questions: [])

        if let url = Bundle.main.url(forResource: "ilm_quiz", withExtension: "json") {
            do {
                content = try JSONDecoder().decode(QuizContent.self, from: Data(contentsOf: url))
            } catch {
                logger.error("Décodage ilm_quiz.json impossible : \(error.localizedDescription)")
            }
        } else {
            logger.error("ilm_quiz.json absent du bundle")
        }

        // Une question en double ou rattachée à un thème inconnu est écartée (jamais de crash).
        let knownTopics = Set(content.topics.map(\.id))
        var seen = Set<String>()
        let kept = content.questions.filter { knownTopics.contains($0.topicId) && seen.insert($0.id).inserted }

        topics = content.topics
        questions = kept
        topicByID = Dictionary(content.topics.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        questionByID = Dictionary(uniqueKeysWithValues: kept.map { ($0.id, $0) })

        #if DEBUG
        let issues = QuizContentValidator.issues(
            in: content,
            lessonIDs: Set(IlmContentLoader.shared.tracks.flatMap { $0.lessons.map(\.id) }),
            trackIDs: Set(IlmContentLoader.shared.tracks.map(\.id))
        )
        for issue in issues { logger.error("ilm_quiz.json : \(issue)") }
        assert(issues.isEmpty, "ilm_quiz.json invalide — voir les logs IlmQuiz")
        #endif
    }
}

/// Règles de conformité éditoriale du quiz (plan §3.2), vérifiées en DEBUG au
/// chargement et par `QuizContentValidationTests` sur le JSON réel.
nonisolated enum QuizContentValidator {

    /// Liste lisible des violations ; vide si le contenu est conforme.
    ///
    /// - Parameters:
    ///   - lessonIDs: ids de leçons `ilm_tracks.json` (un `lessonId` doit y exister).
    ///   - trackIDs: ids de parcours (un `trackId` de thème doit y exister).
    static func issues(in content: QuizContent, lessonIDs: Set<String>, trackIDs: Set<String>) -> [String] {
        var issues: [String] = []

        let topicIDs = content.topics.map(\.id)
        for duplicate in duplicates(topicIDs) { issues.append("thème en double : \(duplicate)") }
        for topic in content.topics {
            if let trackId = topic.trackId, !trackIDs.contains(trackId) {
                issues.append("\(topic.id) : parcours inconnu \(trackId)")
            }
        }

        for duplicate in duplicates(content.questions.map(\.id)) { issues.append("question en double : \(duplicate)") }
        let knownTopics = Set(topicIDs)

        for q in content.questions {
            if !knownTopics.contains(q.topicId) { issues.append("\(q.id) : thème inconnu \(q.topicId)") }
            if let lessonId = q.lessonId, !lessonIDs.contains(lessonId) {
                issues.append("\(q.id) : leçon inconnue \(lessonId)")
            }
            switch q.format {
            case .mcq where q.choices.count < 3:
                issues.append("\(q.id) : QCM avec moins de 3 choix")
            case .trueFalse where q.choices.count != 2:
                issues.append("\(q.id) : vrai/faux sans exactement 2 choix")
            default:
                break
            }
            if !q.choices.indices.contains(q.correctIndex) {
                issues.append("\(q.id) : correctIndex hors limites")
            }
            if Set(q.choices.map(\.fr)).count != q.choices.count {
                issues.append("\(q.id) : choix en double")
            }
            if q.dalil.isEmpty { issues.append("\(q.id) : aucune preuve (dalil)") }
            for d in q.dalil where d.kind == .quran && !isValidQuranRef(d.ref) {
                issues.append("\(q.id) : référence coranique invalide « \(d.ref) »")
            }
            for d in q.dalil where d.kind == .hadith && d.ref.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("\(q.id) : référence de hadith vide")
            }
            if q.promptFr.isEmpty || q.promptAr.isEmpty || q.explanationFr.isEmpty {
                issues.append("\(q.id) : texte manquant")
            }
            if !(1...3).contains(q.difficulty) { issues.append("\(q.id) : difficulté hors 1…3") }
        }
        return issues
    }

    /// `"40:60"`, `"103:1-3"`, `"2:255,256"` — sourate 1…114, versets positifs.
    static func isValidQuranRef(_ ref: String) -> Bool {
        let parts = ref.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let surah = Int(parts[0]), (1...114).contains(surah) else { return false }
        let verses = parts[1].split(whereSeparator: { $0 == "-" || $0 == "," })
        return !verses.isEmpty && verses.allSatisfy { Int($0).map { $0 > 0 } ?? false }
    }

    private static func duplicates(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { !seen.insert($0).inserted }
    }
}
