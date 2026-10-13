//
//  WeeklyReviewPlanner.swift
//  Muslim Clock — module ʿIlm, révision hebdomadaire
//
//  Composition pure et déterministe de la session de la semaine (plan §3.4).
//  Pas d'état, pas de SwiftUI : testable en isolation.
//

import Foundation

nonisolated enum WeeklyReviewPlanner {

    /// Tailles de session proposées à l'utilisateur.
    static let sizePresets = [5, 10, 20]
    static let defaultSize = 10
    /// Fenêtre de rattrapage des erreurs : 4 semaines.
    static let mistakeWindowDays = 28

    /// Compose la session de la semaine.
    ///
    /// Répartition cible (arrondie, le complément comble les seaux vides) :
    /// - 50 % : questions liées aux leçons dues en révision Leitner (pont flash cards) ;
    /// - 30 % : rotation de thèmes — un thème par domaine (aqîda, fiqh, hadith), choisi
    ///   par `numéro de semaine mod nombre de thèmes du domaine` ;
    /// - 20 % : questions ratées dans les 4 dernières semaines ;
    /// - complément : tirage pseudo-aléatoire stable (graine = clé de semaine), en
    ///   privilégiant les questions jamais vues.
    /// Le même `weekKey` et les mêmes entrées donnent toujours la même session.
    ///
    /// - Parameters:
    ///   - weekKey: clé ISO de la semaine (`QuizWeek.key(for:)`), sert de graine.
    ///   - weekNumber: numéro ISO de la semaine (rotation des thèmes).
    ///   - dueLessonIDs: leçons dont la révision Leitner est due.
    /// - Returns: au plus `size` questions, sans doublon.
    static func build(
        questions: [QuizQuestion],
        topics: [QuizTopic],
        progress: QuizProgress,
        dueLessonIDs: Set<String>,
        weekKey: String,
        weekNumber: Int,
        size: Int = defaultSize,
        now: Date = .now
    ) -> [QuizQuestion] {
        guard size > 0, !questions.isEmpty else { return [] }

        let seed = stableSeed(weekKey)
        let dueQuota = Int((Double(size) * 0.5).rounded())
        let mistakeQuota = Int((Double(size) * 0.2).rounded())
        let rotationQuota = max(0, size - dueQuota - mistakeQuota)

        var picked: [QuizQuestion] = []
        var pickedIDs = Set<String>()
        func take(_ pool: [QuizQuestion], upTo quota: Int, salt: UInt64) {
            var added = 0
            for q in shuffled(pool, seed: seed &+ salt) where added < quota && !pickedIDs.contains(q.id) {
                picked.append(q)
                pickedIDs.insert(q.id)
                added += 1
            }
        }

        // 1. Leçons dues (Leitner).
        take(questions.filter { $0.lessonId.map(dueLessonIDs.contains) ?? false }, upTo: dueQuota, salt: 1)

        // 2. Rotation de thèmes.
        let rotationTopics = Set(rotationTopicIDs(topics: topics, weekNumber: weekNumber))
        take(questions.filter { rotationTopics.contains($0.topicId) }, upTo: rotationQuota, salt: 2)

        // 3. Erreurs récentes.
        let windowStart = now.addingTimeInterval(-Double(mistakeWindowDays) * 86_400)
        let recentMistakes = questions.filter { q in
            guard let record = progress.answers[q.id] else { return false }
            return !record.correct && record.date >= windowStart
        }
        take(recentMistakes, upTo: mistakeQuota, salt: 3)

        // 4. Complément : inédites d'abord, puis le reste.
        let remaining = size - picked.count
        if remaining > 0 {
            let unseen = questions.filter { progress.answers[$0.id] == nil }
            take(unseen, upTo: remaining, salt: 4)
            take(questions, upTo: size - picked.count, salt: 5)
        }

        return shuffled(picked, seed: seed &+ 6)
    }

    /// Un thème par domaine présent, en rotation hebdomadaire.
    static func rotationTopicIDs(topics: [QuizTopic], weekNumber: Int) -> [String] {
        QuizDomain.allCases.compactMap { domain in
            let inDomain = topics.filter { $0.domain == domain }.map(\.id).sorted()
            guard !inDomain.isEmpty else { return nil }
            return inDomain[abs(weekNumber) % inDomain.count]
        }
    }

    // MARK: - Hasard déterministe

    /// FNV-1a 64 bits : stable entre lancements et plateformes (contrairement à `hashValue`).
    static func stableSeed(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// Mélange de Fisher-Yates piloté par un générateur SplitMix64 initialisé par `seed`.
    static func shuffled<T>(_ items: [T], seed: UInt64) -> [T] {
        var generator = SplitMix64(state: seed)
        var result = items
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            let j = Int(generator.next() % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }
}

private nonisolated struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
