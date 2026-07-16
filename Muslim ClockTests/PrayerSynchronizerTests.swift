//
//  PrayerSynchronizerTests.swift
//  Muslim ClockTests
//
//  Vérifie le contrat d'écriture de PrayerSynchronizer via un UserDefaults de
//  suite isolée (mock réel). Les effets Watch/Widget sont des no-op en test.
//

import Testing
import Foundation
import CoreLocation
@testable import Muslim_Clock

struct PrayerSynchronizerTests {

    /// UserDefaults isolé et vierge, propre à chaque test.
    private func freshDefaults(_ function: String = #function) -> UserDefaults {
        let name = "test.sync.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func t(_ ts: Double) -> Date { Date(timeIntervalSince1970: ts) }

    // MARK: publishSchedule

    @Test func publishScheduleWritesAllPrayerTimes() {
        let d = freshDefaults()
        PrayerSynchronizer.publishSchedule(
            fajr: t(100), sunrise: t(200), dhuhr: t(300), asr: t(400),
            maghrib: t(500), isha: t(600), fajrTomorrow: t(700), defaults: d
        )
        #expect(d.double(forKey: StorageKeys.prayerFajr) == 100)
        #expect(d.double(forKey: StorageKeys.prayerSunrise) == 200)
        #expect(d.double(forKey: StorageKeys.prayerDhuhr) == 300)
        #expect(d.double(forKey: StorageKeys.prayerAsr) == 400)
        #expect(d.double(forKey: StorageKeys.prayerMaghrib) == 500)
        #expect(d.double(forKey: StorageKeys.prayerIsha) == 600)
        #expect(d.double(forKey: StorageKeys.prayerFajrTomorrow) == 700)
    }

    @Test func publishScheduleOmitsTomorrowFajrWhenNil() {
        let d = freshDefaults()
        PrayerSynchronizer.publishSchedule(
            fajr: t(100), sunrise: t(200), dhuhr: t(300), asr: t(400),
            maghrib: t(500), isha: t(600), fajrTomorrow: nil, defaults: d
        )
        // Clé jamais écrite quand le calcul de demain n'aboutit pas.
        #expect(d.object(forKey: StorageKeys.prayerFajrTomorrow) == nil)
    }

    @Test func publishScheduleWritesProvidedDhuhrVerbatim() {
        // Le vendredi, le ViewModel passe l'heure Jumu'ah dans `dhuhr` :
        // le synchroniseur l'écrit telle quelle (aucun recalcul de son côté).
        let d = freshDefaults()
        PrayerSynchronizer.publishSchedule(
            fajr: t(100), sunrise: t(200), dhuhr: t(1234), asr: t(400),
            maghrib: t(500), isha: t(600), fajrTomorrow: nil, defaults: d
        )
        #expect(d.double(forKey: StorageKeys.prayerDhuhr) == 1234)
    }

    // MARK: publishSettings

    @Test func publishSettingsWritesLocationAndMirroredSettings() {
        let d = freshDefaults()
        let settings = PrayerSyncSettings(
            calculationMethod: "ISNA (15°)",
            fajrOffset: 1, dhuhrOffset: 2, asrOffset: 3, maghribOffset: 4, ishaOffset: 5,
            isIshaFixed: true, ishaFixedDuration: 90,
            jumuahEnabled: true, jumuahHour: 13, jumuahMinute: 30
        )
        PrayerSynchronizer.publishSettings(
            location: CLLocation(latitude: 48.8566, longitude: 2.3522),
            settings: settings, defaults: d
        )
        #expect(abs(d.double(forKey: StorageKeys.savedLatitude) - 48.8566) < 1e-9)
        #expect(abs(d.double(forKey: StorageKeys.savedLongitude) - 2.3522) < 1e-9)
        #expect(d.string(forKey: StorageKeys.wCalculationMethod) == "ISNA (15°)")
        #expect(d.integer(forKey: StorageKeys.wFajrOffset) == 1)
        #expect(d.integer(forKey: StorageKeys.wDhuhrOffset) == 2)
        #expect(d.integer(forKey: StorageKeys.wAsrOffset) == 3)
        #expect(d.integer(forKey: StorageKeys.wMaghribOffset) == 4)
        #expect(d.integer(forKey: StorageKeys.wIshaOffset) == 5)
        #expect(d.bool(forKey: StorageKeys.wIsIshaFixed))
        #expect(d.integer(forKey: StorageKeys.wIshaFixedDuration) == 90)
        #expect(d.bool(forKey: StorageKeys.wJumuahEnabled))
        #expect(d.integer(forKey: StorageKeys.wJumuahHour) == 13)
        #expect(d.integer(forKey: StorageKeys.wJumuahMinute) == 30)
    }
}
