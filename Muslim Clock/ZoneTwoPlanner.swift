//
//  ZoneTwoPlanner.swift
//  Muslim Clock — garde-fou de la zone « Pour aller plus loin »
//
//  Décision pure : parmi les cartes contextuelles candidates à un instant
//  donné, lesquelles afficher. Plafond + ordre de priorité, pour que les jours
//  chargés (vendredi de Ramadan, en voyage, la nuit avant Fajr) ne produisent
//  jamais un mur de cartes. Les cartes permanentes (adhkar, sunnah, rappel,
//  lune) ne passent pas par ici.
//

import Foundation

nonisolated enum ZoneTwoPlanner {

    /// Cartes contextuelles, dans l'ordre de priorité décroissante.
    enum Card: Int, CaseIterable, Comparable, Sendable {
        /// « Se préparer à la prière » : fenêtre pré-prière, la plus pressante.
        case wudu
        /// « À réciter maintenant » : catégorie du livret liée au moment présent.
        case adhkarMoment
        /// « Prière de la nuit » : après le milieu de la nuit, jusqu'au Fajr.
        case night
        /// « Facilités du voyageur » : permanente tant que le mode voyage est actif.
        case travel

        static func < (lhs: Card, rhs: Card) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Nombre maximal de cartes contextuelles affichées en même temps.
    static let maxVisible = 3

    /// Cartes retenues : les `maxVisible` plus prioritaires parmi les candidates.
    static func plan(candidates: Set<Card>, maxVisible: Int = maxVisible) -> Set<Card> {
        Set(candidates.sorted().prefix(max(0, maxVisible)))
    }
}
