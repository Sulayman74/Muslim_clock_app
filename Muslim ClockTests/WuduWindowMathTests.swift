//
//  WuduWindowMathTests.swift
//  Muslim ClockTests
//
//  Tests de la fenêtre de la carte « Se préparer à la prière » (wudû'/ghusl).
//

import Testing
import Foundation
@testable import Muslim_Clock

struct WuduWindowMathTests {

    private let day0: TimeInterval = 1_700_000_000
    private func t(_ hours: Double) -> Date { Date(timeIntervalSince1970: day0 + hours * 3600) }

    private var weekday: [(name: String, time: Date)] {
        [("Fajr", t(6)), ("Dhuhr", t(13)), ("Asr", t(16)), ("Maghrib", t(21)), ("Isha", t(22.5))]
    }

    private var friday: [(name: String, time: Date)] {
        [("Fajr", t(6)), ("Jumu'ah", t(13.5)), ("Asr", t(16)), ("Maghrib", t(21)), ("Isha", t(22.5))]
    }

    // MARK: - Fenêtre standard [prochaine − 45 min, prochaine)

    @Test func wuduShownInsideWindow() {
        let v = WuduWindowMath.target(prayers: weekday, now: t(15.5), isFriday: false)
        #expect(v == .wudu(prayer: "Asr", time: t(16)))
    }

    @Test func windowStartIsInclusive() {
        // 15:15 pile = Asr − 45 min → inclus.
        #expect(WuduWindowMath.target(prayers: weekday, now: t(15.25), isFriday: false) != nil)
    }

    @Test func windowEndIsExclusiveAtAdhan() {
        // À l'adhan pile, la carte s'éteint.
        let v = WuduWindowMath.target(prayers: weekday, now: t(16), isFriday: false)
        #expect(v != .wudu(prayer: "Asr", time: t(16)))
    }

    @Test func nilBeforeWindow() {
        #expect(WuduWindowMath.target(prayers: weekday, now: t(14), isFriday: false) == nil)
    }

    @Test func targetsTheNextPrayerNotALaterOne() {
        // Entre Dhuhr et Asr, hors fenêtre Asr → nil (pas Maghrib).
        #expect(WuduWindowMath.target(prayers: weekday, now: t(13.5), isFriday: false) == nil)
        // Dans la fenêtre du Fajr au petit matin.
        let v = WuduWindowMath.target(prayers: weekday, now: t(5.5), isFriday: false)
        #expect(v == .wudu(prayer: "Fajr", time: t(6)))
    }

    @Test func nilAfterLastPrayer() {
        #expect(WuduWindowMath.target(prayers: weekday, now: t(23), isFriday: false) == nil)
    }

    @Test func emptyPrayersReturnsNil() {
        #expect(WuduWindowMath.target(prayers: [], now: t(12), isFriday: false) == nil)
    }

    // MARK: - Vendredi : ghusl, fenêtre élargie

    @Test func jumuahLabelTriggersGhusl() {
        // 3 h avant Jumu'ah (13:30) → fenêtre ghusl (180 min) active dès 10:30.
        let v = WuduWindowMath.target(prayers: friday, now: t(11), isFriday: true)
        #expect(v == .fridayGhusl(time: t(13.5)))
    }

    @Test func dhuhrOnFridayFallsBackToGhusl() {
        // jumuahEnabled off → le label reste « Dhuhr », mais isFriday couvre.
        let v = WuduWindowMath.target(prayers: weekday, now: t(11), isFriday: true)
        #expect(v == .fridayGhusl(time: t(13)))
    }

    @Test func ghuslWindowRespectsExtendedLead() {
        // Jumu'ah − 181 min → pas encore.
        #expect(WuduWindowMath.target(prayers: friday, now: t(13.5 - 181.0 / 60), isFriday: true) == nil)
        // Jumu'ah − 179 min → actif.
        #expect(WuduWindowMath.target(prayers: friday, now: t(13.5 - 179.0 / 60), isFriday: true) != nil)
    }

    @Test func asrOnFridayIsPlainWudu() {
        // Le vendredi après Jumu'ah, l'approche d'Asr redevient un wudû' normal.
        let v = WuduWindowMath.target(prayers: friday, now: t(15.5), isFriday: true)
        #expect(v == .wudu(prayer: "Asr", time: t(16)))
    }

    @Test func customLeadMinutes() {
        #expect(WuduWindowMath.target(prayers: weekday, now: t(15.1), isFriday: false, leadMinutes: 60) != nil)
        #expect(WuduWindowMath.target(prayers: weekday, now: t(15.1), isFriday: false, leadMinutes: 30) == nil)
    }
}
