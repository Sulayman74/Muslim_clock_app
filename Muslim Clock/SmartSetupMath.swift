//
//  SmartSetupMath.swift
//  Muslim Clock
//
//  Fonctions pures de la décision « Configuration Magique » (Smart Setup) :
//  écart en minutes, détection Isha fixe, scoring d'angle Fajr, faisabilité
//  d'un angle crépusculaire, bornes de plausibilité des offsets.
//
//  Extraites de `SmartSetupView.runAnalysis()` pour être testables sans
//  Calendar/@AppStorage/Adhan — même pattern que `IlmMath`/`PodcastMath`.
//

import Foundation

enum SmartSetupMath {

    // MARK: - Méthodes candidates

    /// Les trois méthodes « classiques » testées par l'analyse, avec leur angle
    /// Fajr/Isha. Les noms sont ceux de `PrayerCalculationEngine.parameters`.
    static let candidateMethods: [(name: String, angle: Double)] = [
        ("UOIF (12°)", 12),
        ("ISNA (15°)", 15),
        ("Ligue Islamique (18°)", 18),
    ]

    /// Méthode de référence pour Dhuhr / Asr / Maghrib (indépendants de l'angle).
    static let referenceMethod = "Ligue Islamique (18°)"

    // MARK: - Plages de plausibilité (alignées sur les steppers de ManualAdjustmentsView)

    static let fajrOffsetRange = -30...30
    static let minorOffsetRange = -15...15     // Dhuhr, Asr, Maghrib
    static let ishaOffsetRange = -15...30
    static let ishaDurationRange = 60...120
    static let ishaDurationStep = 5

    // MARK: - Écarts

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
        ishaDurationRange.contains(maghribToIshaMinutes)
    }

    /// Durée Isha fixe telle que l'app la stocke : arrondie au pas du stepper
    /// (5 min) et bornée à `ishaDurationRange`. Une détection à 93 min donne 95,
    /// jamais une valeur hors grille que le stepper ne saurait plus afficher.
    static func roundedIshaDuration(_ minutes: Int) -> Int {
        let step = ishaDurationStep
        let rounded = Int((Double(minutes) / Double(step)).rounded()) * step
        return clamped(rounded, to: ishaDurationRange).value
    }

    // MARK: - Plausibilité

    /// Borne un offset détecté à sa plage plausible et signale s'il a fallu le faire.
    /// Un écart hors plage trahit presque toujours une saisie erronée, une position
    /// GPS loin de la mosquée, ou un madhab Hanafi (Asr) — à signaler, pas à appliquer.
    static func clamped(_ offset: Int, to range: ClosedRange<Int>) -> (value: Int, wasClamped: Bool) {
        let value = min(max(offset, range.lowerBound), range.upperBound)
        return (value, value != offset)
    }

    // MARK: - Faisabilité d'un angle

    /// Marge (degrés) sous laquelle on considère l'angle comme « limite » et donc
    /// peu fiable — compense l'approximation de la déclinaison solaire (~0,5°).
    static let twilightSafetyMargin = 0.5

    /// Déclinaison solaire approchée (degrés) pour un jour de l'année (1…366).
    /// Formule de Cooper : précision ≈ ±0,5°, suffisante pour un test de faisabilité.
    static func solarDeclination(dayOfYear: Int) -> Double {
        23.44 * sin(2 * .pi * Double(284 + dayOfYear) / 365)
    }

    /// Vrai si le soleil descend bien à `angle`° sous l'horizon cette nuit-là à
    /// cette latitude. Au minuit solaire, l'altitude du soleil vaut
    /// `|φ + δ| − 90` : l'angle est atteint si `angle < 90 − |φ + δ|`.
    ///
    /// Quand ce n'est pas le cas (été en Europe du Nord pour 18°, voire 15°),
    /// Adhan remplace silencieusement Fajr/Isha par une règle de haute latitude :
    /// comparer la mosquée à cette valeur artificielle n'a aucun sens, le
    /// candidat doit être écarté.
    static func isTwilightAngleReachable(angle: Double, latitude: Double, dayOfYear: Int) -> Bool {
        let depressionAtMidnight = 90 - abs(latitude + solarDeclination(dayOfYear: dayOfYear))
        return angle + twilightSafetyMargin < depressionAtMidnight
    }

    // MARK: - Scoring d'angle

    /// Score d'un offset Fajr candidat : plus petit = meilleur.
    ///
    /// Les mosquées ajoutent presque toujours des minutes (offsets positifs) ;
    /// −1/−2 sont tolérés comme arrondis, en deçà on pénalise lourdement (+100)
    /// pour écarter les angles qui placent le calcul APRÈS l'heure de la mosquée.
    static func score(_ fajrOffset: Int) -> Int {
        fajrOffset >= -2 ? fajrOffset : abs(fajrOffset) + 100
    }

    /// Ne garde que les candidats dont l'angle est atteint ce jour-là. Si aucun
    /// ne l'est (cas théorique), on garde tout plutôt que de ne rien proposer.
    static func reliableCandidates(
        _ items: [(name: String, offset: Int, isReliable: Bool)]
    ) -> [(name: String, offset: Int)] {
        let reliable = items.filter(\.isReliable)
        let kept = reliable.isEmpty ? items : reliable
        return kept.map { (name: $0.name, offset: $0.offset) }
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
