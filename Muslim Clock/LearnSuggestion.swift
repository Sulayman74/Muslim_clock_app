//
//  LearnSuggestion.swift
//  Muslim Clock — onglet Apprendre, suggestion du moment
//
//  Logique pure : à un instant donné, quelle action d'apprentissage proposer
//  (révision Leitner, khatma, leçon, quiz hebdo, récitation, Kahf/Mulk) selon
//  la fenêtre de la journée ancrée sur les horaires de prière réels.
//  Pas d'état, pas de SwiftUI → testable en isolation (pattern AdhkarSuggestion).
//
//  Règles produit (validées) :
//  - une seule suggestion affichée (la première de la liste triée) ;
//  - priorité aux dettes réelles (cartes dues, retard khatma) sur le générique ;
//  - dismiss par fenêtre (clé "slot-yyyy-MM-dd"), aucune notification push ;
//  - si rien à proposer → liste vide, la carte disparaît (pas de tâche inventée).
//

import Foundation

// MARK: - Fenêtres de la journée

/// Fenêtre courante, bornée par les prières quand elles sont connues.
nonisolated enum LearnSlot: String, CaseIterable, Sendable {
    case morning    // Fajr → Dhuhr : l'esprit est frais — mémorisation
    case afternoon  // Dhuhr → Maghrib : révisions courtes
    case evening    // Maghrib → Isha : lecture du Coran
    case night      // Isha → Fajr : récitation de mémoire, sourates du soir
}

// MARK: - Entrées / sorties

/// Snapshot des états de programmes au moment du calcul. Tout est optionnel ou
/// neutre par défaut : un module sans plan ne produit simplement rien.
nonisolated struct LearnSuggestionInput: Sendable {
    var now: Date = .now
    var fajr: Date?
    var dhuhr: Date?
    var maghrib: Date?
    var isha: Date?
    var isFriday: Bool = false
    /// Cartes Leitner dues aujourd'hui (tous parcours).
    var dueReviewCount: Int = 0
    /// Titre de la prochaine leçon du plan ʿIlm — `nil` si pas de plan ou terminé.
    var nextLessonTitle: String?
    /// Solde khatma (négatif = retard) — `nil` si aucun plan de lecture.
    var khatmaBalance: Int?
    /// Une lecture a déjà été créditée aujourd'hui.
    var hasReadToday: Bool = false
    var quizAvailable: Bool = false
    var weeklyQuizDone: Bool = false
    /// Versets jamais réussis au seuil dans le correcteur de récitation.
    var recitationReworkCount: Int = 0
}

nonisolated enum LearnSuggestionKind: Equatable, Sendable {
    case kahf
    case reviewCards(count: Int)
    case weeklyQuiz
    /// `pagesBehind` > 0 : rattrapage ; 0 : simple « les pages du jour ».
    case khatmaReading(pagesBehind: Int)
    case lessonOfDay(title: String)
    case recitationRework(count: Int)
    /// Al-Mulk avant le sommeil.
    case nightSurahs
}

// MARK: - Moteur

nonisolated enum LearnSuggestionEngine {

    /// Fenêtre courante. Bornes = prières du jour ; repli sur l'heure civile
    /// si les horaires ne sont pas encore disponibles (GPS refusé, 1er lancement).
    static func slot(
        now: Date,
        fajr: Date? = nil,
        dhuhr: Date? = nil,
        maghrib: Date? = nil,
        isha: Date? = nil,
        calendar: Calendar = .current
    ) -> LearnSlot {
        if let fajr, let dhuhr, let maghrib, let isha {
            if now < fajr { return .night }
            if now < dhuhr { return .morning }
            if now < maghrib { return .afternoon }
            if now < isha { return .evening }
            return .night
        }
        switch calendar.component(.hour, from: now) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    /// Clé de dismiss d'une fenêtre : `"evening-2026-10-14"`. La fenêtre `night`
    /// à cheval sur minuit se réarme au changement de date — accepté (simple).
    static func slotKey(slot: LearnSlot, now: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%@-%04d-%02d-%02d", slot.rawValue, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Suggestions triées par pertinence décroissante — l'UI n'affiche que la
    /// première. Vide si rien n'est dû et qu'aucune fenêtre générique ne s'applique.
    static func suggestions(_ input: LearnSuggestionInput, calendar: Calendar = .current) -> [LearnSuggestionKind] {
        let slot = slot(
            now: input.now, fajr: input.fajr, dhuhr: input.dhuhr,
            maghrib: input.maghrib, isha: input.isha, calendar: calendar
        )

        var ranked: [(score: Int, kind: LearnSuggestionKind)] = []

        // Vendredi de jour : Al-Kahf passe devant tout (adab du jour, pas une dette).
        if input.isFriday && slot != .night {
            ranked.append((95, .kahf))
        }

        // Dette n°1 : les cartes de révision espacée dues aujourd'hui.
        if input.dueReviewCount > 0 {
            ranked.append((90, .reviewCards(count: input.dueReviewCount)))
        }

        // Dette n°2 : la khatma. Retard à toute heure ; sinon « pages du jour »
        // le soir uniquement (fenêtre de lecture naturelle après Maghrib).
        if let balance = input.khatmaBalance {
            if balance < 0 {
                ranked.append((80, .khatmaReading(pagesBehind: -balance)))
            } else if slot == .evening && !input.hasReadToday {
                ranked.append((75, .khatmaReading(pagesBehind: 0)))
            }
        }

        // Quiz hebdo pas encore fait — poussé le vendredi (après Al-Kahf).
        if input.quizAvailable && !input.weeklyQuizDone {
            ranked.append((input.isFriday ? 85 : 70, .weeklyQuiz))
        }

        // Leçon du jour : forte le matin (hifz à l'esprit frais), faible sinon.
        if let title = input.nextLessonTitle {
            ranked.append((slot == .morning ? 60 : 40, .lessonOfDay(title: title)))
        }

        // Versets à retravailler : surtout le soir/la nuit (récitation de mémoire).
        if input.recitationReworkCount > 0 {
            let score = (slot == .evening || slot == .night) ? 55 : 35
            ranked.append((score, .recitationRework(count: input.recitationReworkCount)))
        }

        // Avant le sommeil : Al-Mulk.
        if slot == .night {
            ranked.append((30, .nightSurahs))
        }

        return ranked.sorted { $0.score > $1.score }.map(\.kind)
    }
}
