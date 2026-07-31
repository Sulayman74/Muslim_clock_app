//
//  SmartSetupMathTests.swift
//  Muslim ClockTests
//
//  Volet 1 — Couverture additionnelle de l'algorithme "Configuration Magique".
//
//  Deux blocs :
//
//  1. `EngineEdgeCases` : tests RUNNABLES des fonctions pures existantes
//     (`PrayerCalculationEngine.currentWindow` / `.nightMarkers`) qui produisent
//     les marqueurs de nuit affichés/utilisés en aval du Smart Setup. On couvre
//     ici les cas limites non testés par `PrayerCalculationEngineTests`
//     (nuit décalée DST, nuit très courte hautes latitudes, bornes exactes des
//     fenêtres Dhuhr/Asr/Maghrib, milieu de nuit après minuit, etc.).
//
//  2. `DecisionMath` : tests de la logique de DÉCISION du Smart Setup,
//     extraite dans `SmartSetupMath` (pur) : écart en minutes avec repli
//     minuit, détection Isha fixe, scoring d'angle Fajr.
//     `SmartSetupView.runAnalysis()` délègue désormais à ces fonctions.
//

import Testing
import Foundation
@testable import Muslim_Clock

// MARK: - 1. Cas limites du moteur pur (RUNNABLE)

struct SmartSetupEngineEdgeCasesTests {

    private let day0: TimeInterval = 1_700_000_000
    private func t(_ hours: Double) -> Date { Date(timeIntervalSince1970: day0 + hours * 3600) }

    private func window(
        at hours: Double,
        fajr: Double = 5, sunrise: Double = 6.5, dhuhr: Double = 13,
        asr: Double = 16, maghrib: Double = 21, isha: Double = 22.5, middle: Double = 26
    ) -> (window: PrayerWindow, start: Date?, end: Date?) {
        PrayerCalculationEngine.currentWindow(
            now: t(hours), fajr: t(fajr), sunrise: t(sunrise), dhuhr: t(dhuhr),
            asr: t(asr), maghrib: t(maghrib), isha: t(isha), middleOfNight: t(middle)
        )
    }

    // MARK: currentWindow — bornes exactes (half-open) non couvertes

    @Test func dhuhrStartsExactlyAtDhuhr() {
        #expect(window(at: 13).window == .dhuhr)
    }

    @Test func dhuhrEndsExactlyAtAsr() {
        // Borne haute exclusive : à Asr pile, on est déjà dans la fenêtre Asr.
        #expect(window(at: 16).window == .asr)
    }

    @Test func asrEndsExactlyAtMaghrib() {
        #expect(window(at: 21).window == .maghrib)
    }

    @Test func maghribEndsExactlyAtIsha() {
        #expect(window(at: 22.5).window == .isha)
    }

    @Test func ishaStartsExactlyAtIsha() {
        #expect(window(at: 22.5).window == .isha)
    }

    @Test func noneExactlyAtMiddleOfNight() {
        // Milieu de nuit = borne haute exclusive de la fenêtre Isha → plus de fenêtre.
        #expect(window(at: 26).window == .none)
    }

    @Test func noneExactlyBeforeFajr() {
        // Juste avant Fajr (nuit profonde) : aucune fenêtre active.
        #expect(window(at: 4.999).window == .none)
    }

    @Test func windowStartsAndEndsAreConsistentForDhuhr() {
        let w = window(at: 14)
        #expect(w.start == t(13))
        #expect(w.end == t(16))
    }

    // MARK: nightMarkers — cas limites

    /// Nuit très courte (hautes latitudes en été) : Maghrib 23h, Fajr 02h30 → 3h30.
    @Test func nightMarkersShortSummerNight() {
        let m = PrayerCalculationEngine.nightMarkers(maghrib: t(23), fajrTomorrow: t(26.5))
        // Milieu = 23h + 1h45 = 24h45.
        #expect(abs(m.middleOfNight.timeIntervalSince(t(24.75))) < 0.001)
        // Dernier tiers = Fajr − (3.5/3)h.
        #expect(abs(m.lastThirdOfNight.timeIntervalSince(t(26.5 - 3.5 / 3))) < 0.001)
    }

    /// Le milieu de nuit doit toujours être avant le dernier tiers (invariant géométrique).
    @Test func middleOfNightIsBeforeLastThird() {
        let m = PrayerCalculationEngine.nightMarkers(maghrib: t(21), fajrTomorrow: t(29))
        #expect(m.middleOfNight < m.lastThirdOfNight)
    }

    /// Nuit longue d'hiver (14h) : vérifie que le partage 1/2 et 2/3 reste correct.
    @Test func nightMarkersLongWinterNight() {
        let maghrib = t(17)
        let fajrTomorrow = t(31) // +14h
        let m = PrayerCalculationEngine.nightMarkers(maghrib: maghrib, fajrTomorrow: fajrTomorrow)
        #expect(abs(m.middleOfNight.timeIntervalSince(t(24))) < 0.001)       // 17 + 7
        #expect(abs(m.lastThirdOfNight.timeIntervalSince(t(31 - 14.0 / 3))) < 0.001)
    }

    /// Marqueurs cohérents quand la fenêtre Isha se termine au milieu de nuit calculé.
    @Test func ishaWindowRespectsComputedMiddleOfNight() {
        let m = PrayerCalculationEngine.nightMarkers(maghrib: t(21), fajrTomorrow: t(29)) // milieu = 25h
        let w = PrayerCalculationEngine.currentWindow(
            now: t(24.9), fajr: t(5), sunrise: t(6.5), dhuhr: t(13),
            asr: t(16), maghrib: t(21), isha: t(22.5), middleOfNight: m.middleOfNight
        )
        #expect(w.window == .isha)
        let wAfter = PrayerCalculationEngine.currentWindow(
            now: t(25.1), fajr: t(5), sunrise: t(6.5), dhuhr: t(13),
            asr: t(16), maghrib: t(21), isha: t(22.5), middleOfNight: m.middleOfNight
        )
        #expect(wAfter.window == .none)
    }
}

// MARK: - 2. Logique de décision Smart Setup (SmartSetupMath)

struct SmartSetupDecisionMathTests {

    @Test func minutesBetweenSignedUserMinusCalculated() {
        // Mosquée Fajr 05:12, calcul 05:07 → +5 min.
        #expect(SmartSetupMath.minutesBetween(calc: (5, 7), user: (5, 12)) == 5)
        // Mosquée avant le calcul → offset négatif.
        #expect(SmartSetupMath.minutesBetween(calc: (13, 30), user: (13, 28)) == -2)
        // Identiques → 0.
        #expect(SmartSetupMath.minutesBetween(calc: (21, 3), user: (21, 3)) == 0)
    }

    @Test func minutesBetweenWrapsAroundMidnight() {
        // Isha calculée 23:50, mosquée 00:10 → +20 min (pas −1420).
        #expect(SmartSetupMath.minutesBetween(calc: (23, 50), user: (0, 10)) == 20)
        // Inverse : calcul 00:10, mosquée 23:50 → −20 min (pas +1420).
        #expect(SmartSetupMath.minutesBetween(calc: (0, 10), user: (23, 50)) == -20)
    }

    @Test func ishaFixedDetectionWindow() {
        #expect(SmartSetupMath.isFixedIsha(90) == true)   // lissage classique 90 min
        #expect(SmartSetupMath.isFixedIsha(60) == true)   // borne basse incluse
        #expect(SmartSetupMath.isFixedIsha(120) == true)  // borne haute incluse
        #expect(SmartSetupMath.isFixedIsha(45) == false)  // trop court → astronomique
        #expect(SmartSetupMath.isFixedIsha(121) == false) // trop long → astronomique
    }

    @Test func angleScoringPrefersSmallestNonNegativeOffset() {
        // Offsets positifs : on prend le plus proche de 0.
        #expect(SmartSetupMath.score(3) == 3)
        #expect(SmartSetupMath.score(0) == 0)
        // Arrondis tolérés : -1 et -2 gardent leur valeur (pas de pénalité).
        #expect(SmartSetupMath.score(-2) == -2)
        // Négatif franc → forte pénalité.
        #expect(SmartSetupMath.score(-3) == 103)
    }

    @Test func bestAngleChoosesUOIFWhenClosestToZero() {
        // UOIF (12°) colle presque parfaitement, ISNA/Ligue trop tôt (négatif franc).
        let best = SmartSetupMath.bestAngle([
            (name: "UOIF (12°)", offset: 1),
            (name: "ISNA (15°)", offset: -8),
            (name: "Ligue Islamique (18°)", offset: -15)
        ])
        #expect(best.name == "UOIF (12°)")
        #expect(best.offset == 1)
    }

    @Test func bestAnglePicksLargerAngleWhenFajrIsLater() {
        // La mosquée fait Fajr tard → l'angle 18° donne l'offset positif minimal.
        let best = SmartSetupMath.bestAngle([
            (name: "UOIF (12°)", offset: 22),
            (name: "ISNA (15°)", offset: 11),
            (name: "Ligue Islamique (18°)", offset: 2)
        ])
        #expect(best.name == "Ligue Islamique (18°)")
    }
}
