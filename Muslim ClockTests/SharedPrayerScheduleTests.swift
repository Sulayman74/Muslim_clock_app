//
//  SharedPrayerScheduleTests.swift
//  Muslim ClockTests
//
//  Vérifie le calcul partagé app ↔ extensions : bascule de journée sans l'app,
//  repli sur les timestamps publiés, Jumu'ah, fenêtres, et surtout l'absence de
//  dérive entre ce que l'app publie et ce que les extensions recalculent.
//

import Testing
import Foundation
import CoreLocation
@testable import Muslim_Clock

struct SharedPrayerScheduleTests {

    // MARK: - Fixtures

    /// Paris, réglages par défaut de l'app.
    private func parisSettings(jumuahEnabled: Bool = false) -> PrayerSettingsSnapshot {
        PrayerSettingsSnapshot(
            latitude: 48.8566, longitude: 2.3522,
            calculationMethod: "UOIF (12°)",
            fajrOffset: 0, dhuhrOffset: 0, asrOffset: 0, maghribOffset: 0, ishaOffset: 0,
            isIshaFixed: true, ishaFixedDuration: 90,
            jumuahEnabled: jumuahEnabled, jumuahHour: 13, jumuahMinute: 30
        )
    }

    /// UserDefaults isolé et vierge, propre à chaque test.
    private func freshDefaults(_ function: String = #function) -> UserDefaults {
        let name = "test.schedule.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func t(_ ts: Double) -> Date { Date(timeIntervalSince1970: ts) }

    /// Prochain jour de semaine (`weekday` : 1 = dimanche … 6 = vendredi) à partir de `date`.
    private func next(weekday: Int, from date: Date) -> Date {
        let cal = Calendar.current
        var day = cal.startOfDay(for: date)
        while cal.component(.weekday, from: day) != weekday {
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return day
    }

    // MARK: - Chargement des réglages

    @Test func loadReturnsNilWithoutPublishedLocation() {
        let d = freshDefaults()
        d.set("ISNA (15°)", forKey: StorageKeys.wCalculationMethod)
        #expect(PrayerSettingsSnapshot.load(from: d) == nil)
    }

    @Test func loadReadsPublishedSettingsWithAppDefaults() {
        let d = freshDefaults()
        d.set(48.8566, forKey: StorageKeys.savedLatitude)
        d.set(2.3522, forKey: StorageKeys.savedLongitude)
        // Aucune clé w_* : on doit retomber sur les défauts de PrayerTimesViewModel.
        let s = PrayerSettingsSnapshot.load(from: d)
        #expect(s?.calculationMethod == "UOIF (12°)")
        #expect(s?.isIshaFixed == true)
        #expect(s?.ishaFixedDuration == 90)
        #expect(s?.jumuahHour == 13)
        #expect(s?.jumuahEnabled == false)
    }

    // MARK: - Repli timestamps

    @Test func resolveFallsBackToPublishedTimestampsWithoutLocation() {
        let d = freshDefaults()
        d.set(100.0, forKey: StorageKeys.prayerFajr)
        d.set(200.0, forKey: StorageKeys.prayerSunrise)
        d.set(300.0, forKey: StorageKeys.prayerDhuhr)
        d.set(400.0, forKey: StorageKeys.prayerAsr)
        d.set(500.0, forKey: StorageKeys.prayerMaghrib)
        d.set(600.0, forKey: StorageKeys.prayerIsha)
        d.set(700.0, forKey: StorageKeys.prayerFajrTomorrow)

        let r = SharedPrayerSchedule.resolve(at: t(350), defaults: d)
        #expect(r?.isComputedLocally == false)
        #expect(r?.today.fajr == t(100))
        #expect(r?.today.sunrise == t(200))
        #expect(r?.today.isha == t(600))
        #expect(r?.tomorrowFajr == t(700))
        #expect(r?.nextPrayer(at: t(350)).prayer == .asr)
    }

    @Test func resolveReturnsNilWithNothingPublished() {
        #expect(SharedPrayerSchedule.resolve(at: .now, defaults: freshDefaults()) == nil)
    }

    // MARK: - Bascule de journée (le bug « bloqué au Fajr »)

    @Test func resolveComputesTheRequestedDayEvenWithStaleTimestamps() {
        let d = freshDefaults()
        let now = Date()
        let cal = Calendar.current

        // Position publiée + timestamps périmés de 3 jours (app iPhone pas rouverte).
        d.set(48.8566, forKey: StorageKeys.savedLatitude)
        d.set(2.3522, forKey: StorageKeys.savedLongitude)
        let stale = now.addingTimeInterval(-3 * 24 * 3600).timeIntervalSince1970
        d.set(stale, forKey: StorageKeys.prayerFajr)
        d.set(stale + 3600, forKey: StorageKeys.prayerDhuhr)
        d.set(stale + 7200, forKey: StorageKeys.prayerAsr)
        d.set(stale + 9000, forKey: StorageKeys.prayerMaghrib)
        d.set(stale + 10800, forKey: StorageKeys.prayerIsha)
        d.set(stale + 86400, forKey: StorageKeys.prayerFajrTomorrow)

        let r = try! #require(SharedPrayerSchedule.resolve(at: now, defaults: d))
        #expect(r.isComputedLocally)
        // Les horaires sont ceux de la journée de `now`, pas les timestamps périmés.
        for (_, time) in r.today.ordered {
            #expect(cal.isDate(time, inSameDayAs: now))
        }
        #expect(cal.isDate(r.tomorrowFajr, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now)!))
        // La prochaine prière est toujours dans le futur — jamais « Fajr » figé dans le passé.
        #expect(r.nextPrayer(at: now).time > now)
    }

    @Test func nextPrayerAfterIshaIsTomorrowFajr() {
        let r = try! #require(SharedPrayerSchedule.resolve(at: .now, settings: parisSettings()))
        let afterIsha = r.today.isha.addingTimeInterval(60)
        let next = r.nextPrayer(at: afterIsha)
        #expect(next.prayer == .fajr)
        #expect(next.time == r.tomorrowFajr)
        #expect(r.tomorrowFajr > r.today.isha)
    }

    @Test func nextPrayerBeforeFajrIsTodayFajr() {
        let r = try! #require(SharedPrayerSchedule.resolve(at: .now, settings: parisSettings()))
        let next = r.nextPrayer(at: r.today.fajr.addingTimeInterval(-60))
        #expect(next.prayer == .fajr)
        #expect(next.time == r.today.fajr)
    }

    // MARK: - Jumu'ah

    @Test func jumuahTimeSetsHourAndMinuteOnTheGivenDay() {
        let day = Date()
        let j = try! #require(SharedPrayerSchedule.jumuahTime(on: day, hour: 13, minute: 30))
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: j)
        #expect(comps.hour == 13 && comps.minute == 30 && comps.second == 0)
        #expect(Calendar.current.isDate(j, inSameDayAs: day))
    }

    @Test func fridayJumuahReplacesDhuhrOnlyWhenEnabled() {
        let friday = next(weekday: 6, from: Date())
        let expected = SharedPrayerSchedule.jumuahTime(on: friday, hour: 13, minute: 30)

        let on = SharedPrayerSchedule.schedule(for: friday, settings: parisSettings(jumuahEnabled: true))
        #expect(on?.isFridayJumuah == true)
        #expect(on?.dhuhr == expected)

        let off = SharedPrayerSchedule.schedule(for: friday, settings: parisSettings(jumuahEnabled: false))
        #expect(off?.isFridayJumuah == false)
        #expect(off?.dhuhr != expected)
    }

    @Test func jumuahNeverAppliesOutsideFriday() {
        let thursday = next(weekday: 5, from: Date())
        let s = SharedPrayerSchedule.schedule(for: thursday, settings: parisSettings(jumuahEnabled: true))
        #expect(s?.isFridayJumuah == false)
    }

    // MARK: - Fenêtres

    @Test func windowEndsFollowJurisprudence() {
        let r = try! #require(SharedPrayerSchedule.resolve(at: .now, settings: parisSettings()))
        #expect(r.windowEnd(of: .fajr) == r.today.sunrise)
        #expect(r.windowEnd(of: .dhuhr) == r.today.asr)
        #expect(r.windowEnd(of: .asr) == r.today.maghrib)
        #expect(r.windowEnd(of: .maghrib) == r.today.isha)
        let night = r.tomorrowFajr.timeIntervalSince(r.today.maghrib)
        #expect(abs(r.windowEnd(of: .isha).timeIntervalSince(r.today.maghrib.addingTimeInterval(night / 2))) < 0.001)
        #expect(r.currentWindow(at: r.today.asr.addingTimeInterval(60)).window == .asr)
    }

    // MARK: - Anti-dérive app ↔ extensions

    /// Ce que l'app publie (via SharedPrayerSchedule + PrayerSynchronizer) et ce
    /// qu'une extension recalcule depuis l'App Group doivent être strictement égaux.
    @Test func publishedAndLocallyRecomputedSchedulesAreIdentical() {
        let d = freshDefaults()
        let now = Date()
        let location = CLLocation(latitude: 48.8566, longitude: 2.3522)
        let sync = PrayerSyncSettings(
            calculationMethod: "Mosquée de Paris",
            fajrOffset: 2, dhuhrOffset: 3, asrOffset: 0, maghribOffset: 4, ishaOffset: 0,
            isIshaFixed: false, ishaFixedDuration: 90,
            jumuahEnabled: true, jumuahHour: 13, jumuahMinute: 15
        )
        let snapshot = PrayerSettingsSnapshot(location: location, sync: sync)

        // Côté app : calcul + publication (même chemin que PrayerTimesViewModel).
        let published = try! #require(SharedPrayerSchedule.schedule(for: now, settings: snapshot))
        let tomorrowFajr = Calendar.current.date(byAdding: .day, value: 1, to: now)
            .flatMap { SharedPrayerSchedule.schedule(for: $0, settings: snapshot)?.fajr }
        PrayerSynchronizer.publishSchedule(
            fajr: published.fajr, sunrise: published.sunrise, dhuhr: published.dhuhr,
            asr: published.asr, maghrib: published.maghrib, isha: published.isha,
            fajrTomorrow: tomorrowFajr, defaults: d
        )
        PrayerSynchronizer.publishSettings(location: location, settings: sync, defaults: d)

        // Côté extension : relecture + recalcul local.
        let local = try! #require(SharedPrayerSchedule.resolve(at: now, defaults: d))
        #expect(local.isComputedLocally)
        #expect(local.today == published)
        #expect(local.tomorrowFajr == tomorrowFajr)

        // Et le repli timestamps donne la même journée.
        let fallback = try! #require(SharedPrayerSchedule.publishedSchedule(from: d))
        #expect(fallback.today == published)
    }
}
