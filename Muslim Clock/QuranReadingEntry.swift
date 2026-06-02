//
//  ReadingEntry.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Entrée de journal SwiftData. Une entrée = un jour calendaire.
//

import Foundation
import SwiftData

/// Une session de lecture enregistrée pour un jour donné.
///
/// Le `date` est normalisé à minuit (jour calendaire local) pour garantir l'unicité
/// par jour et faciliter les requêtes de heatmap.
@Model
final class ReadingEntry {

    @Attribute(.unique) var id: UUID
    /// Jour calendaire (heure normalisée à 00:00 local).
    var date: Date
    /// Pages lues sur ce jour (peut être incrémenté plusieurs fois dans la même journée).
    var pagesRead: Int
    /// Dernière page atteinte dans le Mushaf à la fin de la journée (curseur).
    var lastPageReached: Int
    /// Note libre optionnelle (non exposée dans la 1ʳᵉ itération, conservée pour évolution).
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date,
        pagesRead: Int,
        lastPageReached: Int,
        note: String? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.pagesRead = max(0, pagesRead)
        self.lastPageReached = max(0, min(604, lastPageReached))
        self.note = note
    }
}
