//
//  PrayerCountdownMath.swift
//  Muslim Clock — libellés et cadences du héros « Prochaine prière »
//
//  Fonctions pures (pattern IqamahMath) : formulation naturelle du temps
//  restant (« 1 h 23 », « 12 min ») et progression d'une barre start → end.
//  Le héros les appelle depuis une TimelineView à la minute.
//

import Foundation

nonisolated enum PrayerCountdownMath {

    /// Largeur de barre de référence : ~1 pt de progression par tick.
    static let referenceBarWidth: Double = 350

    /// Temps restant jusqu'à `target`, en langage naturel : « 12 min », « 1 h »,
    /// « 1 h 05 », ou « moins d'une minute » sous 60 s. Au-delà, arrondi à la
    /// minute supérieure : « 12 min » signifie « au plus 12 minutes ».
    static func remainingLabel(until target: Date, now: Date) -> String {
        let seconds = max(0, target.timeIntervalSince(now))
        if seconds < 60 { return String(localized: "moins d'une minute") }
        let minutes = Int((seconds / 60).rounded(.up))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return String(localized: "\(rest) min") }
        if rest == 0 { return String(localized: "\(hours) h") }
        return String(localized: "\(hours) h \(String(format: "%02d", rest))")
    }

    /// Progression 0…1 de `now` dans l'intervalle `start → end` (bornée).
    static func progress(start: Date, end: Date, now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    /// Cadence adaptative de la barre : un tick par point de progression,
    /// plancher 1 s (fenêtres très courtes).
    static func barCadence(start: Date, end: Date) -> TimeInterval {
        max(1.0, end.timeIntervalSince(start) / referenceBarWidth)
    }
}
