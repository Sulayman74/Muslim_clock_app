//
//  PrayerCalculationEngineTests.swift
//  Muslim ClockTests
//
//  Tests des fonctions pures de calcul des fenêtres de prière (jurisprudence).
//  (Le mapping des `CalculationParameters` Adhan n'est pas testé ici : il dépend
//  du module Adhan non lié au target de test — il reste couvert par le build.)
//

import Testing
import Foundation
@testable import Muslim_Clock

struct PrayerCalculationEngineTests {

    /// Base fixe (un jour), + un helper pour des heures locales lisibles.
    private let day0: TimeInterval = 1_700_000_000
    private func t(_ hours: Double) -> Date { Date(timeIntervalSince1970: day0 + hours * 3600) }

    // Horaires type d'une journée.
    private var fajr: Date    { t(5) }
    private var sunrise: Date { t(6.5) }
    private var dhuhr: Date   { t(13) }
    private var asr: Date     { t(16) }
    private var maghrib: Date { t(21) }
    private var isha: Date    { t(22.5) }
    private var middle: Date  { t(26) } // 2h du matin

    private func window(at hours: Double) -> (window: PrayerWindow, start: Date?, end: Date?) {
        PrayerCalculationEngine.currentWindow(
            now: t(hours), fajr: fajr, sunrise: sunrise, dhuhr: dhuhr,
            asr: asr, maghrib: maghrib, isha: isha, middleOfNight: middle
        )
    }

    // MARK: currentWindow

    @Test func fajrWindowBetweenFajrAndSunrise() {
        let w = window(at: 5.5)
        #expect(w.window == .fajr)
        #expect(w.start == fajr)
        #expect(w.end == sunrise)
    }

    @Test func noneBetweenSunriseAndDhuhr() {
        let w = window(at: 10)
        #expect(w.window == .none)
        #expect(w.start == nil)
        #expect(w.end == nil)
    }

    @Test func dhuhrWindowBetweenDhuhrAndAsr() {
        #expect(window(at: 14).window == .dhuhr)
    }

    @Test func asrWindowBetweenAsrAndMaghrib() {
        #expect(window(at: 18).window == .asr)
    }

    @Test func maghribWindowBetweenMaghribAndIsha() {
        #expect(window(at: 21.5).window == .maghrib)
    }

    @Test func ishaWindowBetweenIshaAndMiddleOfNight() {
        let w = window(at: 23.5)
        #expect(w.window == .isha)
        #expect(w.end == middle)
    }

    @Test func noneAfterMiddleOfNight() {
        #expect(window(at: 27).window == .none)
    }

    @Test func boundariesAreHalfOpen() {
        // Exactement à Sunrise : la fenêtre Fajr est terminée (borne exclusive).
        #expect(window(at: 6.5).window == .none)
        // Exactement à Fajr : la fenêtre commence (borne inclusive).
        #expect(window(at: 5).window == .fajr)
    }

    // MARK: nightMarkers

    @Test func nightMarkersSplitTheNight() {
        let maghribTime = t(21)
        let fajrTomorrow = t(29) // Fajr du lendemain (5h) = 24 + 5
        let m = PrayerCalculationEngine.nightMarkers(maghrib: maghribTime, fajrTomorrow: fajrTomorrow)

        // Nuit de 8h : milieu = Maghrib + 4h = 25h.
        #expect(m.middleOfNight == t(25))
        // Dernier tiers = Fajr − (8h / 3) ≈ 26h20.
        #expect(abs(m.lastThirdOfNight.timeIntervalSince(t(29 - 8.0 / 3))) < 0.001)
    }
}
