//
//  PrayerCountdownMathTests.swift
//  Muslim ClockTests
//
//  Libellés naturels et progression du héros « Prochaine prière ».
//

import Testing
import Foundation
@testable import Muslim_Clock

struct PrayerCountdownMathTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func after(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    @Test func minutesOnlyUnderAnHour() {
        #expect(PrayerCountdownMath.remainingLabel(until: after(12 * 60), now: t0) == "12 min")
    }

    @Test func roundsUpToTheNextMinute() {
        // 11 min 30 s restantes → « 12 min » (au plus 12 minutes).
        #expect(PrayerCountdownMath.remainingLabel(until: after(11 * 60 + 30), now: t0) == "12 min")
    }

    @Test func exactHoursDropTheMinutes() {
        #expect(PrayerCountdownMath.remainingLabel(until: after(2 * 3600), now: t0) == "2 h")
        // 59 min 30 s → arrondi 60 min → « 1 h ».
        #expect(PrayerCountdownMath.remainingLabel(until: after(59 * 60 + 30), now: t0) == "1 h")
    }

    @Test func hoursAndMinutesPadTheMinutes() {
        #expect(PrayerCountdownMath.remainingLabel(until: after(4 * 3600 + 5 * 60), now: t0) == "4 h 05")
        #expect(PrayerCountdownMath.remainingLabel(until: after(1 * 3600 + 23 * 60), now: t0) == "1 h 23")
    }

    @Test func underAMinuteAndPastTargetAreClamped() {
        #expect(PrayerCountdownMath.remainingLabel(until: after(30), now: t0) == "moins d'une minute")
        #expect(PrayerCountdownMath.remainingLabel(until: after(-600), now: t0) == "moins d'une minute")
    }

    @Test func progressIsBoundedAndLinear() {
        let start = t0, end = after(1000)
        #expect(PrayerCountdownMath.progress(start: start, end: end, now: after(-10)) == 0)
        #expect(PrayerCountdownMath.progress(start: start, end: end, now: after(500)) == 0.5)
        #expect(PrayerCountdownMath.progress(start: start, end: end, now: after(2000)) == 1)
        // Intervalle dégénéré → terminé.
        #expect(PrayerCountdownMath.progress(start: start, end: start, now: start) == 1)
    }

    @Test func barCadenceHasAOneSecondFloor() {
        #expect(PrayerCountdownMath.barCadence(start: t0, end: after(60)) == 1)
        #expect(PrayerCountdownMath.barCadence(start: t0, end: after(3500)) == 10)
    }
}
