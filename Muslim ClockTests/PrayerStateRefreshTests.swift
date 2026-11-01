//
//  PrayerStateRefreshTests.swift
//  Muslim ClockTests
//
//  Minuteur d'état du ViewModel (borne du prochain recalcul) et fenêtre Isha de
//  la veille — fonctions pures de `PrayerCalculationEngine`.
//

import Testing
import Foundation
@testable import Muslim_Clock

struct PrayerStateRefreshTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return c
    }

    /// 1er novembre 2026 à `hour:minute` (heure de Paris).
    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 1) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 11; comps.day = day
        comps.hour = hour; comps.minute = minute
        return calendar.date(from: comps) ?? .distantPast
    }

    // MARK: - nextRefreshDate

    @Test func windowEndWinsWhenClosest() {
        let now = date(7, 0)
        let fire = PrayerCalculationEngine.nextRefreshDate(
            now: now, windowEnd: date(7, 37), nextPrayer: date(12, 35), calendar: calendar
        )
        #expect(fire == date(7, 37))
    }

    @Test func nextPrayerWinsOutsideWindow() {
        let now = date(9, 0)
        let fire = PrayerCalculationEngine.nextRefreshDate(
            now: now, windowEnd: nil, nextPrayer: date(12, 35), calendar: calendar
        )
        #expect(fire == date(12, 35))
    }

    @Test func midnightIsAlwaysACandidate() {
        // Après l'Isha, prochaine prière = Fajr de demain (6h27) : minuit arrive avant.
        let now = date(23, 0)
        let fire = PrayerCalculationEngine.nextRefreshDate(
            now: now, windowEnd: nil, nextPrayer: date(6, 27, day: 2), calendar: calendar
        )
        #expect(fire == date(0, 0, day: 2))
    }

    @Test func pastCandidatesAreIgnored() {
        // Une cible déjà passée (état périmé) ne doit pas produire un réveil immédiat en boucle.
        let now = date(8, 0)
        let fire = PrayerCalculationEngine.nextRefreshDate(
            now: now, windowEnd: date(7, 37), nextPrayer: date(6, 27), calendar: calendar
        )
        #expect(fire == date(0, 0, day: 2))
    }

    // MARK: - previousNightWindow

    private var maghribYesterday: Date { date(17, 30, day: 1) }
    private var ishaYesterday: Date { date(19, 0, day: 1) }
    private var fajrToday: Date { date(6, 27, day: 2) }
    /// Milieu de la nuit 17:30 → 06:27 ≈ 23:58.
    private var middle: Date {
        PrayerCalculationEngine.nightMarkers(maghrib: maghribYesterday, fajrTomorrow: fajrToday).middleOfNight
    }

    @Test func ishaOfPreviousDayStillActiveAfterMidnight() {
        // 23:30 est avant le milieu de nuit (~23:58) et après l'Isha d'hier.
        let w = PrayerCalculationEngine.previousNightWindow(
            now: date(23, 30, day: 1), fajrToday: fajrToday,
            maghribYesterday: maghribYesterday, ishaYesterday: ishaYesterday
        )
        #expect(w.window == .isha)
        #expect(w.start == ishaYesterday)
        #expect(w.end == middle)
    }

    @Test func noneAfterMiddleOfNight() {
        let w = PrayerCalculationEngine.previousNightWindow(
            now: date(3, 0, day: 2), fajrToday: fajrToday,
            maghribYesterday: maghribYesterday, ishaYesterday: ishaYesterday
        )
        #expect(w.window == .none)
    }

    @Test func noneOnceFajrHasStarted() {
        let w = PrayerCalculationEngine.previousNightWindow(
            now: date(6, 30, day: 2), fajrToday: fajrToday,
            maghribYesterday: maghribYesterday, ishaYesterday: ishaYesterday
        )
        #expect(w.window == .none)
    }
}
