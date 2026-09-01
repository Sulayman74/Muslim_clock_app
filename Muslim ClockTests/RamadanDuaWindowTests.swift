//
//  RamadanDuaWindowTests.swift
//  Muslim ClockTests
//
//  Tests de la fenêtre contextuelle Ramadan (RamadanDuaService.currentWindow).
//  Couvre notamment le débord après minuit de la fenêtre Suhoor (isha ≥ fajr).
//

import Testing
import Foundation
@testable import Muslim_Clock

struct RamadanDuaWindowTests {

    private let day0: TimeInterval = 1_700_000_000
    private func t(_ hours: Double) -> Date { Date(timeIntervalSince1970: day0 + hours * 3600) }

    init() {
        // La logique réelle est court-circuitée en DEBUG si l'override de test
        // est posé (Settings) — on le retire pour des tests déterministes.
        UserDefaults.standard.removeObject(forKey: "debugRamadanWindow")
    }

    // Journée type : Fajr 05:30, Maghrib 21:00, Isha 22:30 (le même jour → isha ≥ fajr).
    private var fajr: Date { t(5.5) }
    private var maghrib: Date { t(21) }
    private var isha: Date { t(22.5) }

    // MARK: - Fenêtre Iftar [Maghrib − 30 min, Maghrib + 30 min]

    @Test func iftarAtMaghrib() {
        #expect(RamadanDuaService.currentWindow(now: t(21), maghrib: maghrib, isha: isha, fajr: fajr) == .iftar)
    }

    @Test func iftarAtInclusiveBounds() {
        // Bornes incluses : Maghrib − 30 min et Maghrib + 30 min.
        #expect(RamadanDuaService.currentWindow(now: t(20.5), maghrib: maghrib, isha: isha, fajr: fajr) == .iftar)
        #expect(RamadanDuaService.currentWindow(now: t(21.5), maghrib: maghrib, isha: isha, fajr: fajr) == .iftar)
    }

    @Test func generalJustOutsideIftarWindow() {
        // 1 min avant la fenêtre (20:29) → pas encore Iftar.
        #expect(RamadanDuaService.currentWindow(now: t(20.5 - 1.0 / 60), maghrib: maghrib, isha: isha, fajr: fajr) == .general)
    }

    // MARK: - Fenêtre Suhoor avec débord minuit (isha ≥ fajr, horaires du même jour)

    @Test func suhoorAfterMidnightBeforeFajr() {
        // 03:00 : passé minuit, avant Fajr → sahari.
        #expect(RamadanDuaService.currentWindow(now: t(3), maghrib: maghrib, isha: isha, fajr: fajr) == .suhoor)
    }

    @Test func generalAtFajrExactly() {
        // Borne exclue : à Fajr pile, la fenêtre Suhoor est terminée.
        #expect(RamadanDuaService.currentWindow(now: t(5.5), maghrib: maghrib, isha: isha, fajr: fajr) == .general)
    }

    @Test func generalInDaytime() {
        // 12:00 : ni Iftar, ni Suhoor.
        #expect(RamadanDuaService.currentWindow(now: t(12), maghrib: maghrib, isha: isha, fajr: fajr) == .general)
    }

    // MARK: - Fenêtre Suhoor cas « même journée » (isha < fajr — Fajr de demain)

    @Test func suhoorBetweenIshaAndNextFajr() {
        // Isha 22:30 aujourd'hui, Fajr 05:30 demain (t(24 + 5.5)) → 23:30 est dans le sahari.
        let fajrTomorrow = t(24 + 5.5)
        #expect(RamadanDuaService.currentWindow(now: t(23.5), maghrib: maghrib, isha: isha, fajr: fajrTomorrow) == .suhoor)
    }

    @Test func generalBeforeIshaWithNextDayFajr() {
        // 22:00 : avant Isha (et hors fenêtre Iftar) → général.
        let fajrTomorrow = t(24 + 5.5)
        #expect(RamadanDuaService.currentWindow(now: t(22), maghrib: maghrib, isha: isha, fajr: fajrTomorrow) == .general)
    }

    // MARK: - Priorité et données manquantes

    @Test func iftarWinsOverSuhoorOverlap() {
        // Maghrib et Isha rapprochés : à Isha + 5 min on est encore dans la fenêtre
        // Iftar (Maghrib + 30 min) → Iftar prioritaire (testé en premier).
        let closeIsha = t(21.25) // 21:15
        let fajrTomorrow = t(24 + 5.5)
        #expect(RamadanDuaService.currentWindow(now: t(21 + 20.0 / 60), maghrib: maghrib, isha: closeIsha, fajr: fajrTomorrow) == .iftar)
    }

    @Test func generalWhenTimesMissing() {
        #expect(RamadanDuaService.currentWindow(now: t(21), maghrib: nil, isha: nil, fajr: nil) == .general)
        // Suhoor impossible sans le couple (isha, fajr) complet.
        #expect(RamadanDuaService.currentWindow(now: t(3), maghrib: maghrib, isha: isha, fajr: nil) == .general)
        #expect(RamadanDuaService.currentWindow(now: t(3), maghrib: maghrib, isha: nil, fajr: fajr) == .general)
    }
}
