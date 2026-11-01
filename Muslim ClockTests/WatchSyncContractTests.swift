//
//  WatchSyncContractTests.swift
//  Muslim ClockTests
//
//  Teste la « connexion » iPhone → montre/widgets au niveau du contrat de données :
//  ce que l'app produit (`PrayerSynchronizer.watchSettingsPayload` / `watchContext`),
//  une fois stocké côté récepteur comme le fait `WatchSessionReceiver.store`, doit
//  permettre à `SharedPrayerSchedule` de recalculer EXACTEMENT le même horaire que
//  l'iPhone. Si une clé de payload ou un type change, ce test casse.
//
//  Le transport WatchConnectivity lui-même n'est pas testable en unitaire (WCSession
//  n'est pas injectable) : on vérifie le contrat sérialisé, qui est la seule chose
//  qui peut dériver silencieusement.
//

import Testing
import Foundation
import CoreLocation
@testable import Muslim_Clock

struct WatchSyncContractTests {

    // MARK: - Fixtures

    private let paris = CLLocation(latitude: 48.8566, longitude: 2.3522)

    private func parisSync(jumuahEnabled: Bool = false) -> PrayerSyncSettings {
        PrayerSyncSettings(
            calculationMethod: "UOIF (12°)",
            fajrOffset: 0, dhuhrOffset: 0, asrOffset: 0, maghribOffset: 0, ishaOffset: 0,
            isIshaFixed: true, ishaFixedDuration: 90,
            jumuahEnabled: jumuahEnabled, jumuahHour: 13, jumuahMinute: 30
        )
    }

    /// UserDefaults isolé et vierge, propre à chaque test.
    private func freshDefaults(_ function: String = #function) -> UserDefaults {
        let name = "test.watchsync.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func t(_ ts: Double) -> Date { Date(timeIntervalSince1970: ts) }

    /// Simule `WatchSessionReceiver.store` : écrit tel quel chaque couple reçu dans l'App Group local.
    private func store(_ payload: [String: Any], into defaults: UserDefaults) {
        for (key, value) in payload { defaults.set(value, forKey: key) }
    }

    /// Prochain jour de semaine (`weekday` : 1 = dimanche … 6 = vendredi) à partir de `date`.
    private func next(weekday: Int, from date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.startOfDay(for: date)
        while cal.component(.weekday, from: day) != weekday {
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return day
    }

    // MARK: - Boucle complète : payload montre → recalcul identique

    @Test func settingsPayloadRoundTripsToIdenticalSchedule() {
        let sync = parisSync()
        let instant = t(1_750_000_000)

        // iPhone : l'horaire qu'il calcule lui-même pour cet instant.
        let snapshot = PrayerSettingsSnapshot(location: paris, sync: sync)
        let iPhone = SharedPrayerSchedule.resolve(at: instant, settings: snapshot)

        // Montre : reçoit le payload RÉEL, le stocke, puis recalcule via l'App Group.
        let watchDefaults = freshDefaults()
        store(PrayerSynchronizer.watchSettingsPayload(location: paris, settings: sync), into: watchDefaults)
        let watch = SharedPrayerSchedule.resolve(at: instant, defaults: watchDefaults)

        #expect(watch != nil)
        #expect(watch?.isComputedLocally == true)   // calcul local, pas repli
        #expect(watch == iPhone)                      // aucune dérive de sérialisation
    }

    @Test func fridayJumuahPropagatesThroughPayload() {
        let sync = parisSync(jumuahEnabled: true)
        let friday = next(weekday: 6, from: t(1_750_000_000))
        let beforeJumuah = friday.addingTimeInterval(11 * 3600) // 11:00, avant 13:30

        let snapshot = PrayerSettingsSnapshot(location: paris, sync: sync)
        let iPhone = SharedPrayerSchedule.resolve(at: beforeJumuah, settings: snapshot)

        let watchDefaults = freshDefaults()
        store(PrayerSynchronizer.watchSettingsPayload(location: paris, settings: sync), into: watchDefaults)
        let watch = SharedPrayerSchedule.resolve(at: beforeJumuah, defaults: watchDefaults)

        #expect(watch?.today.isFridayJumuah == true)
        #expect(watch == iPhone)
    }

    @Test func offsetsAndMethodSurviveTheRoundTrip() {
        let sync = PrayerSyncSettings(
            calculationMethod: "ISNA (15°)",
            fajrOffset: 2, dhuhrOffset: -1, asrOffset: 3, maghribOffset: 1, ishaOffset: -4,
            isIshaFixed: false, ishaFixedDuration: 90,
            jumuahEnabled: false, jumuahHour: 13, jumuahMinute: 0
        )
        let watchDefaults = freshDefaults()
        store(PrayerSynchronizer.watchSettingsPayload(location: paris, settings: sync), into: watchDefaults)

        let reloaded = PrayerSettingsSnapshot.load(from: watchDefaults)
        #expect(reloaded?.calculationMethod == "ISNA (15°)")
        #expect(reloaded?.fajrOffset == 2)
        #expect(reloaded?.dhuhrOffset == -1)
        #expect(reloaded?.ishaOffset == -4)
        #expect(reloaded?.isIshaFixed == false)
    }

    // MARK: - Contexte : repli montre si elle ne peut pas calculer

    @Test func contextCarriesScheduleTimestampsForWatchFallback() {
        // L'app publie les horaires du jour dans l'App Group...
        let source = freshDefaults()
        PrayerSynchronizer.publishSchedule(
            fajr: t(100), sunrise: t(200), dhuhr: t(300), asr: t(400),
            maghrib: t(500), isha: t(600), fajrTomorrow: t(700), defaults: source
        )

        // ... le contexte applicatif doit transporter ces timestamps ET la position/réglages.
        let settingsPayload = PrayerSynchronizer.watchSettingsPayload(location: paris, settings: parisSync())
        let context = PrayerSynchronizer.watchContext(settingsPayload: settingsPayload, defaults: source)

        #expect(context[StorageKeys.prayerFajr] as? Double == 100)
        #expect(context[StorageKeys.prayerIsha] as? Double == 600)
        #expect(context[StorageKeys.prayerFajrTomorrow] as? Double == 700)
        #expect(context[StorageKeys.savedLatitude] as? Double != nil)
        #expect(context[StorageKeys.wCalculationMethod] as? String == "UOIF (12°)")
    }

    @Test func contextOmitsUnpublishedScheduleKeys() {
        // Aucun horaire publié → le contexte ne doit pas inventer de timestamps à 0.
        let source = freshDefaults()
        let settingsPayload = PrayerSynchronizer.watchSettingsPayload(location: paris, settings: parisSync())
        let context = PrayerSynchronizer.watchContext(settingsPayload: settingsPayload, defaults: source)

        #expect(context[StorageKeys.prayerFajr] == nil)
        #expect(context[StorageKeys.prayerFajrTomorrow] == nil)
        // Les réglages, eux, restent présents.
        #expect(context[StorageKeys.savedLongitude] as? Double != nil)
    }
}
