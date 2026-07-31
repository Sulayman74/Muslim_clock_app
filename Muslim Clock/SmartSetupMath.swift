//
//  SmartSetupMath.swift
//  Muslim Clock
//
//  Fonctions pures de la décision « Configuration Magique » (Smart Setup) :
//  écart en minutes, détection Isha fixe, scoring d'angle Fajr.
//
//  Extraites de `SmartSetupView.runAnalysis()` pour être testables sans
//  Calendar/@AppStorage/Adhan — même pattern que `IlmMath`/`PodcastMath`.
//

import Foundation

enum SmartSetupMath {

    /// Écart signé `user − calculé`, en minutes, comparé sur (heure, minute).
    ///
    /// Replié au plus proche autour de minuit : un écart brut au-delà de ±12 h
    /// (±720 min) est ramené dans `(-720, +720]`. Sans ça, une Isha calculée à
    /// 23:50 pointée par l'utilisateur à 00:10 donnerait −1420 min au lieu de +20.
    static func minutesBetween(calc: (Int, Int), user: (Int, Int)) -> Int {
        let calcMinutes = calc.0 * 60 + calc.1
        let userMinutes = user.0 * 60 + user.1
        var delta = userMinutes - calcMinutes
        if delta > 720 { delta -= 1440 }
        if delta <= -720 { delta += 1440 }
        return delta
    }

    /// Vrai si l'écart Maghrib → Isha correspond à un intervalle fixe plausible
    /// (lissage mosquée) : entre 60 et 120 minutes inclus.
    static func isFixedIsha(_ maghribToIshaMinutes: Int) -> Bool {
        maghribToIshaMinutes >= 60 && maghribToIshaMinutes <= 120
    }

    /// Score d'un offset Fajr candidat : plus petit = meilleur.
    ///
    /// Les mosquées ajoutent presque toujours des minutes (offsets positifs) ;
    /// −1/−2 sont tolérés comme arrondis, en deçà on pénalise lourdement (+100)
    /// pour écarter les angles qui placent le calcul APRÈS l'heure de la mosquée.
    static func score(_ fajrOffset: Int) -> Int {
        fajrOffset >= -2 ? fajrOffset : abs(fajrOffset) + 100
    }

    /// Choisit l'angle dont l'offset Fajr a le meilleur score (voir `score(_:)`).
    /// En cas d'égalité, le premier de la liste gagne (ordre d'essai stable).
    static func bestAngle(_ items: [(name: String, offset: Int)]) -> (name: String, offset: Int) {
        precondition(!items.isEmpty, "bestAngle requiert au moins un candidat")
        var best = items[0]
        var bestScore = Int.max
        for item in items {
            let s = score(item.offset)
            if s < bestScore {
                bestScore = s
                best = item
            }
        }
        return best
    }
}
