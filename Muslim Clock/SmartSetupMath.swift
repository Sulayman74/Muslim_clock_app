//
//  SmartSetupMath.swift
//  Muslim Clock
//
//  Fonctions pures de la décision « Configuration Magique » (Smart Setup) :
//  écart en minutes, décision Isha (fixe / astronomique), scoring conjoint
//  Fajr + Isha, préférence régionale, faisabilité d'un angle, bornes de
//  plausibilité des offsets.
//
//  Testables sans Calendar/@AppStorage/Adhan — même pattern que `IlmMath`.
//  Le calcul astronomique lui-même vit dans `SmartSetupAnalyzer`.
//

import Foundation

nonisolated enum SmartSetupMath {

    // MARK: - Méthodes candidates

    /// Les trois méthodes « classiques » testées par l'analyse, avec leur angle
    /// Fajr. Même source que les pickers (`PrayerCalculationEngine.classicMethods`).
    static var candidateMethods: [(name: String, angle: Double)] {
        PrayerCalculationEngine.classicMethods.map { (name: $0.name, angle: $0.fajrAngle) }
    }

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

    // MARK: - Isha

    /// Mode Isha déduit de l'observation.
    nonisolated enum IshaMode: Equatable {
        /// Lissage mosquée : Isha = Maghrib + `duration` minutes.
        case fixed(duration: Int)
        /// Isha astronomique de la méthode choisie, avec décalage en minutes.
        case astronomical(offset: Int)
    }

    /// Un écart Isha astronomique à ±3 min est considéré comme « la mosquée suit l'angle ».
    static let ishaAngleMatchTolerance = 3

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

    /// Décide entre Isha fixe et astronomique pour la méthode retenue.
    ///
    /// En hiver, l'Isha astronomique tombe naturellement 75 à 110 min après
    /// Maghrib : un simple test « entre 60 et 120 » la prendrait pour un lissage.
    /// On préfère donc l'astronomique dès que l'angle de la méthode colle à
    /// ±`ishaAngleMatchTolerance`. Sinon, un écart « rond » (multiple de 5) est
    /// un lissage ; un écart quelconque est un lissage incertain (arrondi).
    ///
    /// - Parameters:
    ///   - maghribToIsha: écart saisi Maghrib → Isha (min).
    ///   - astronomicalOffset: écart `Isha saisie − Isha astronomique` de la méthode.
    /// - Returns: le mode et un drapeau « incertain » à signaler à l'utilisateur.
    static func ishaMode(maghribToIsha: Int, astronomicalOffset: Int) -> (mode: IshaMode, isUncertain: Bool) {
        guard isFixedIsha(maghribToIsha) else {
            return (.astronomical(offset: clamped(astronomicalOffset, to: ishaOffsetRange).value), false)
        }
        if abs(astronomicalOffset) <= ishaAngleMatchTolerance {
            return (.astronomical(offset: astronomicalOffset), false)
        }
        if maghribToIsha % ishaDurationStep == 0 {
            return (.fixed(duration: maghribToIsha), false)
        }
        return (.fixed(duration: roundedIshaDuration(maghribToIsha)), true)
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

    // MARK: - Préférence régionale

    /// Boîte englobante (approximative) de la France métropolitaine.
    static let franceLatitudeRange = 41.3...51.1
    static let franceLongitudeRange = -5.2...9.6

    static func isInMetropolitanFrance(latitude: Double, longitude: Double) -> Bool {
        franceLatitudeRange.contains(latitude) && franceLongitudeRange.contains(longitude)
    }

    /// Ordre de préférence pour départager des méthodes ex æquo.
    /// En France, les mosquées (Mawaqit) sont majoritairement en 12° puis 15° ;
    /// ailleurs, l'ordre neutre favorise la Ligue Islamique (18°).
    static func preferenceOrder(latitude: Double, longitude: Double) -> [String] {
        isInMetropolitanFrance(latitude: latitude, longitude: longitude)
            ? ["UOIF (12°)", "ISNA (15°)", "Ligue Islamique (18°)"]
            : ["Ligue Islamique (18°)", "ISNA (15°)", "UOIF (12°)"]
    }

    // MARK: - Scoring

    /// Score d'un offset candidat : plus petit = meilleur.
    ///
    /// Les mosquées ajoutent presque toujours des minutes (offsets positifs) ;
    /// −1/−2 sont tolérés comme arrondis, en deçà on pénalise lourdement (+100)
    /// pour écarter les angles qui placent le calcul APRÈS l'heure de la mosquée.
    static func score(_ offset: Int) -> Int {
        offset >= -2 ? offset : abs(offset) + 100
    }

    /// Score conjoint d'une méthode : Fajr, plus Isha quand elle est astronomique
    /// (`ishaOffset == nil` quand l'Isha est fixe : elle ne dit rien sur l'angle).
    /// Deux signaux séparent bien mieux 12° / 15° / 18° qu'un seul.
    static func jointScore(fajrOffset: Int, ishaOffset: Int?) -> Int {
        score(fajrOffset) + (ishaOffset.map(score) ?? 0)
    }

    /// Deux scores à moins de `tieTolerance` points sont ex æquo : la préférence
    /// régionale départage (un écart de 1 à 2 min est du bruit d'arrondi).
    static let tieTolerance = 3

    /// Choisit la méthode : meilleur score parmi les candidats fiables (angle
    /// atteint), ex æquo départagés par `preferenceOrder`. Si aucun candidat n'est
    /// fiable, on les garde tous plutôt que de ne rien proposer.
    static func bestMethod(
        _ scored: [(name: String, score: Int, isReliable: Bool)],
        preferenceOrder: [String]
    ) -> String {
        precondition(!scored.isEmpty, "bestMethod requiert au moins un candidat")
        let reliable = scored.filter(\.isReliable)
        let pool = reliable.isEmpty ? scored : reliable
        let bestScore = pool.map(\.score).min() ?? 0
        let tied = pool.filter { $0.score <= bestScore + tieTolerance }
        func rank(_ name: String) -> Int { preferenceOrder.firstIndex(of: name) ?? preferenceOrder.count }
        return tied.min { rank($0.name) < rank($1.name) }?.name ?? pool[0].name
    }

    // MARK: - API historique (phase 1, conservée pour les tests existants)

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
