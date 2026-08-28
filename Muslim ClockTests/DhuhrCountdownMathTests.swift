//
//  DhuhrCountdownMathTests.swift
//  Muslim ClockTests
//
//  Tests du rappel avant Dhuhr / Jumu'ah (DhuhrCountdownMath).
//

import Testing
import Foundation
@testable import Muslim_Clock

struct DhuhrCountdownMathTests {

    private let day0: TimeInterval = 1_700_000_000
    private func t(_ hours: Double) -> Date { Date(timeIntervalSince1970: day0 + hours * 3600) }

    private var weekday: [(name: String, time: Date)] {
        [("Fajr", t(6)), ("Dhuhr", t(13)), ("Asr", t(16)), ("Maghrib", t(21)), ("Isha", t(22.5))]
    }

    // MARK: - Fenêtre [Dhuhr − 60 min, Dhuhr)

    @Test func targetShownInLastHour() {
        let target = DhuhrCountdownMath.target(prayers: weekday, now: t(12 + 30.0 / 60))
        #expect(target?.label == "Dhuhr")
        #expect(target?.time == t(13))
    }

    @Test func targetShownAtExactStartOfWindow() {
        // 12:00 pile = Dhuhr − 60 min → inclus.
        #expect(DhuhrCountdownMath.target(prayers: weekday, now: t(12)) != nil)
    }

    @Test func nilBeforeWindow() {
        // 11:30 = plus d'une heure avant Dhuhr.
        #expect(DhuhrCountdownMath.target(prayers: weekday, now: t(11.5)) == nil)
    }

    @Test func nilAtAndAfterDhuhr() {
        // À Dhuhr pile (borne exclue) et après → plus de rappel.
        #expect(DhuhrCountdownMath.target(prayers: weekday, now: t(13)) == nil)
        #expect(DhuhrCountdownMath.target(prayers: weekday, now: t(13 + 5.0 / 60)) == nil)
    }

    @Test func fridayReturnsJumuahLabel() {
        let friday: [(name: String, time: Date)] = [("Fajr", t(6)), ("Jumu'ah", t(13.5)), ("Asr", t(16))]
        let target = DhuhrCountdownMath.target(prayers: friday, now: t(13))
        #expect(target?.label == "Jumu'ah")
        #expect(target?.time == t(13.5))
    }

    @Test func customLeadMinutes() {
        // Avec 30 min d'anticipation, 12:45 est dans la fenêtre, 12:15 non.
        #expect(DhuhrCountdownMath.target(prayers: weekday, now: t(12 + 45.0 / 60), leadMinutes: 30) != nil)
        #expect(DhuhrCountdownMath.target(prayers: weekday, now: t(12 + 15.0 / 60), leadMinutes: 30) == nil)
    }

    @Test func nilWhenNoDhuhrInList() {
        let noDhuhr: [(name: String, time: Date)] = [("Fajr", t(6)), ("Asr", t(16))]
        #expect(DhuhrCountdownMath.target(prayers: noDhuhr, now: t(12.5)) == nil)
    }
}
