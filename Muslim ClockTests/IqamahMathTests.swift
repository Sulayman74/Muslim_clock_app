//
//  IqamahMathTests.swift
//  Muslim ClockTests
//
//  Tests de la fenêtre Adhan → Iqamah (IqamahMath).
//

import Testing
import Foundation
@testable import Muslim_Clock

struct IqamahMathTests {

    private let day0: TimeInterval = 1_700_000_000
    private func t(_ hours: Double) -> Date { Date(timeIntervalSince1970: day0 + hours * 3600) }

    /// Journée type : Fajr 6h, Dhuhr 13h, Asr 16h, Maghrib 21h, Isha 23h50.
    private var prayers: [(name: String, adhan: Date)] {
        [("Fajr", t(6)), ("Dhuhr", t(13)), ("Asr", t(16)), ("Maghrib", t(21)), ("Isha", t(23 + 50.0 / 60))]
    }

    private let delays = ["Fajr": 20, "Dhuhr": 15, "Asr": 15, "Maghrib": 5, "Isha": 15]

    // MARK: - iqamahTarget

    @Test func targetFoundInsideWindow() {
        let target = IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: t(6 + 10.0 / 60))
        #expect(target?.name == "Fajr")
        #expect(target?.iqamah == t(6 + 20.0 / 60))
    }

    @Test func windowStartsAtAdhanInclusive() {
        let target = IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: t(13))
        #expect(target?.name == "Dhuhr")
    }

    @Test func windowEndsAtIqamahExclusive() {
        // À l'iqamah pile (13h15), la fenêtre Dhuhr est finie.
        let target = IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: t(13 + 15.0 / 60))
        #expect(target == nil)
    }

    @Test func nilOutsideAnyWindow() {
        #expect(IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: t(10)) == nil)
        #expect(IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: t(5.9)) == nil)
    }

    @Test func zeroOrMissingDelayDisablesWindow() {
        // Délai 0 → jamais de fenêtre pour Maghrib, même à l'adhan pile.
        let zeroDelays = ["Maghrib": 0]
        #expect(IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: zeroDelays, now: t(21)) == nil)
        // Délai absent → idem.
        #expect(IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: [:], now: t(13 + 5.0 / 60)) == nil)
    }

    @Test func jumuahInheritsDhuhrDelay() {
        let fridayPrayers: [(name: String, adhan: Date)] = [("Fajr", t(6)), ("Jumu'ah", t(13.5))]
        let target = IqamahMath.iqamahTarget(prayers: fridayPrayers, delaysMinutes: delays, now: t(13.5 + 10.0 / 60))
        #expect(target?.name == "Jumu'ah")
        #expect(target?.iqamah == t(13.5 + 15.0 / 60)) // délai Dhuhr = 15 min
    }

    @Test func lateIshaWindowCrossesMidnight() {
        // Isha 23h50 + 15 min → fenêtre jusqu'à 00h05 le lendemain.
        // Les Date sont absolues : pas de piège de wrap.
        let target = IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: t(24))
        #expect(target?.name == "Isha")
    }

    // MARK: - progress

    @Test func progressBoundsAndMidpoint() {
        let adhan = t(13), iqamah = t(13 + 15.0 / 60)
        #expect(IqamahMath.progress(adhan: adhan, iqamah: iqamah, now: adhan) == 0)
        #expect(abs(IqamahMath.progress(adhan: adhan, iqamah: iqamah, now: t(13 + 7.5 / 60)) - 0.5) < 0.0001)
        #expect(IqamahMath.progress(adhan: adhan, iqamah: iqamah, now: iqamah) == 1)
        // Clamp au-delà des bornes.
        #expect(IqamahMath.progress(adhan: adhan, iqamah: iqamah, now: t(14)) == 1)
        #expect(IqamahMath.progress(adhan: adhan, iqamah: iqamah, now: t(12)) == 0)
    }

    @Test func progressDegenerateWindowIsFinished() {
        #expect(IqamahMath.progress(adhan: t(13), iqamah: t(13), now: t(13)) == 1)
    }
}
