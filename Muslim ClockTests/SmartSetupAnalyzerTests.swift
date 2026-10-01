//
//  SmartSetupAnalyzerTests.swift
//  Muslim ClockTests
//
//  Phase 2 de la Configuration Magique : l'observation est la référence, la
//  méthode et les offsets en sont dérivés pour n'importe quel angle choisi.
//  Les horaires « mosquée » sont générés par le moteur partagé lui-même
//  (SharedPrayerSchedule) à partir d'une méthode connue, puis on vérifie que
//  l'analyse la retrouve.
//

import Testing
import Foundation
@testable import Muslim_Clock

struct SmartSetupAnalyzerTests {

    private let paris = (lat: 48.8566, lon: 2.3522)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = 12
        return Calendar.current.date(from: comps)!
    }

    private func settings(
        method: String, fajr: Int = 0, dhuhr: Int = 0, asr: Int = 0, maghrib: Int = 0,
        isha: Int = 0, ishaFixed: Bool = false, ishaDuration: Int = 90
    ) -> PrayerSettingsSnapshot {
        PrayerSettingsSnapshot(
            latitude: paris.lat, longitude: paris.lon,
            calculationMethod: method,
            fajrOffset: fajr, dhuhrOffset: dhuhr, asrOffset: asr, maghribOffset: maghrib, ishaOffset: isha,
            isIshaFixed: ishaFixed, ishaFixedDuration: ishaDuration,
            jumuahEnabled: false, jumuahHour: 13, jumuahMinute: 0
        )
    }

    /// Observation « mosquée » fabriquée depuis une méthode connue.
    private func observation(on day: Date, from s: PrayerSettingsSnapshot) -> MosqueObservation {
        let schedule = SharedPrayerSchedule.schedule(for: day, settings: s)!
        return MosqueObservation(
            date: day, latitude: s.latitude, longitude: s.longitude,
            fajr: schedule.fajr, dhuhr: schedule.dhuhr, asr: schedule.asr,
            maghrib: schedule.maghrib, isha: schedule.isha
        )
    }

    private func freshDefaults(_ function: String = #function) -> UserDefaults {
        let name = "test.smartsetup.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Reconnaissance

    @Test func recoversISNAWithOffsetsAndAstronomicalIshaInWinter() throws {
        let day = date(2026, 1, 15)
        let obs = observation(on: day, from: settings(method: "ISNA (15°)", fajr: 3, dhuhr: 5, asr: 2, maghrib: 4, isha: 1))
        let proposal = try #require(SmartSetupAnalyzer.analyze(obs))

        #expect(proposal.recommendedMethod == "ISNA (15°)")
        let applied = proposal.settings(for: proposal.recommendedMethod)
        #expect(applied.fajrOffset == 3)
        #expect(applied.dhuhrOffset == 5)
        #expect(applied.asrOffset == 2)
        #expect(applied.maghribOffset == 4)
        // En hiver l'écart Maghrib → Isha ressemble à un lissage (60…120), mais
        // l'Isha colle à l'angle à ±3 min → astronomique, pas « fixe ».
        #expect(applied.ishaMode == .astronomical(offset: 1))
        #expect(applied.warnings.isEmpty)
        #expect(proposal.warnings.isEmpty)
    }

    @Test func recoversUOIFWithFixedIshaInSummerAndExcludes18() throws {
        let day = date(2026, 6, 15)
        let obs = observation(on: day, from: settings(method: "UOIF (12°)", ishaFixed: true, ishaDuration: 90))
        let proposal = try #require(SmartSetupAnalyzer.analyze(obs))

        #expect(proposal.recommendedMethod == "UOIF (12°)")
        #expect(proposal.candidate(named: "Ligue Islamique (18°)")?.isReachable == false)
        #expect(proposal.candidate(named: "UOIF (12°)")?.isReachable == true)

        let applied = proposal.settings(for: "UOIF (12°)")
        #expect(applied.fajrOffset == 0)
        #expect(applied.ishaMode == .fixed(duration: 90))
    }

    // MARK: - Changer de méthode re-dérive les offsets

    @Test func switchingMethodRederivesFajrAndIshaOffsets() throws {
        let day = date(2026, 1, 15)
        let obs = observation(on: day, from: settings(method: "ISNA (15°)", fajr: 3))
        let proposal = try #require(SmartSetupAnalyzer.analyze(obs))

        let isna = proposal.settings(for: "ISNA (15°)")
        let mwl = proposal.settings(for: "Ligue Islamique (18°)")
        let uoif = proposal.settings(for: "UOIF (12°)")

        // 18° place Fajr plus tôt → offset nettement positif ; 12° plus tard → négatif.
        #expect(isna.fajrOffset == 3)
        #expect(mwl.fajrOffset > isna.fajrOffset + 5)
        #expect(uoif.fajrOffset < 0)
        // Dhuhr/Asr/Maghrib ne dépendent pas de l'angle.
        #expect(mwl.dhuhrOffset == isna.dhuhrOffset)
        #expect(uoif.maghribOffset == isna.maghribOffset)
    }

    @Test func legacyMosqueeDeParisMapsToLigueIslamique() throws {
        let obs = observation(on: date(2026, 1, 15), from: settings(method: "ISNA (15°)"))
        let proposal = try #require(SmartSetupAnalyzer.analyze(obs))
        #expect(proposal.settings(for: "Mosquée de Paris").method == "Ligue Islamique (18°)")
        #expect(PrayerCalculationEngine.normalizedMethod("Mosquée de Paris") == "Ligue Islamique (18°)")
        #expect(PrayerCalculationEngine.normalizedMethod("ISNA (15°)") == "ISNA (15°)")
        #expect(PrayerCalculationEngine.classicMethodNames.contains("Mosquée de Paris") == false)
    }

    // MARK: - Plausibilité

    @Test func implausibleAsrIsBoundedAndFlagged() throws {
        let day = date(2026, 1, 15)
        var obs = observation(on: day, from: settings(method: "UOIF (12°)"))
        obs.asr = obs.asr.addingTimeInterval(50 * 60)   // mosquée Hanafi ou saisie erronée
        let proposal = try #require(SmartSetupAnalyzer.analyze(obs))

        #expect(proposal.asrOffset == SmartSetupMath.minorOffsetRange.upperBound)
        #expect(proposal.warnings.count == 1)
        #expect(proposal.warnings[0].contains("Asr"))
        #expect(proposal.warnings[0].contains("Hanafi"))
    }

    // MARK: - Persistance

    @Test func observationRoundTripsThroughUserDefaults() {
        let d = freshDefaults()
        #expect(MosqueObservation.load(from: d) == nil)
        let obs = observation(on: date(2026, 3, 1), from: settings(method: "UOIF (12°)"))
        obs.save(to: d)
        #expect(MosqueObservation.load(from: d) == obs)
    }
}
