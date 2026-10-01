//
//  SharedPrayerSchedule.swift
//  Muslim Clock — horaires de prière calculés à partir des réglages publiés.
//
//  Fichier PARTAGÉ par les 4 cibles (app iOS, SalatWidgetExtension,
//  PrayerComplicationExtension, WatchExtension Watch App). C'est la SEULE
//  implémentation du calcul « position + réglages → horaires du jour » :
//  l'app iOS publie ce qu'elle calcule ici, et les extensions recalculent avec
//  exactement le même code — aucune copie, donc aucune dérive possible
//  (Jumu'ah, offsets, méthode, fenêtres).
//
//  Toute logique métier d'horaires vit ici ou dans `PrayerCalculationEngine`,
//  jamais dans une cible en particulier.
//

import Foundation
import Adhan

// MARK: - Réglages publiés

/// Position + réglages de calcul, tels que publiés dans l'App Group par
/// `PrayerSynchronizer.publishSettings` (clés `saved_*` et `w_*`) et envoyés à
/// la montre via WatchConnectivity (mêmes clés).
nonisolated struct PrayerSettingsSnapshot: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var calculationMethod: String
    var fajrOffset: Int
    var dhuhrOffset: Int
    var asrOffset: Int
    var maghribOffset: Int
    var ishaOffset: Int
    var isIshaFixed: Bool
    var ishaFixedDuration: Int
    var jumuahEnabled: Bool
    var jumuahHour: Int
    var jumuahMinute: Int

    /// Valeurs par défaut alignées sur les `@AppStorage` de `PrayerTimesViewModel`.
    static let defaultCalculationMethod = "UOIF (12°)"
    static let defaultIshaFixedDuration = 90
    static let defaultJumuahHour = 13

    /// Lit le snapshot publié dans `defaults`.
    ///
    /// - Returns: `nil` tant que l'app iPhone n'a jamais publié de position
    ///   (clés absentes). Le point (0, 0) est traité comme « jamais publié ».
    static func load(from defaults: UserDefaults?) -> PrayerSettingsSnapshot? {
        guard let d = defaults else { return nil }
        let latitude = d.double(forKey: StorageKeys.savedLatitude)
        let longitude = d.double(forKey: StorageKeys.savedLongitude)
        guard latitude != 0 || longitude != 0 else { return nil }

        func int(_ key: String, default value: Int) -> Int {
            d.object(forKey: key) == nil ? value : d.integer(forKey: key)
        }
        func bool(_ key: String, default value: Bool) -> Bool {
            d.object(forKey: key) == nil ? value : d.bool(forKey: key)
        }

        return PrayerSettingsSnapshot(
            latitude: latitude,
            longitude: longitude,
            calculationMethod: d.string(forKey: StorageKeys.wCalculationMethod) ?? defaultCalculationMethod,
            fajrOffset: int(StorageKeys.wFajrOffset, default: 0),
            dhuhrOffset: int(StorageKeys.wDhuhrOffset, default: 0),
            asrOffset: int(StorageKeys.wAsrOffset, default: 0),
            maghribOffset: int(StorageKeys.wMaghribOffset, default: 0),
            ishaOffset: int(StorageKeys.wIshaOffset, default: 0),
            isIshaFixed: bool(StorageKeys.wIsIshaFixed, default: true),
            ishaFixedDuration: int(StorageKeys.wIshaFixedDuration, default: defaultIshaFixedDuration),
            jumuahEnabled: bool(StorageKeys.wJumuahEnabled, default: false),
            jumuahHour: int(StorageKeys.wJumuahHour, default: defaultJumuahHour),
            jumuahMinute: int(StorageKeys.wJumuahMinute, default: 0)
        )
    }
}

// MARK: - Horaires d'une journée

/// Les cinq prières, dans l'ordre de la journée. La valeur brute est le nom
/// utilisé partout dans l'app (clés de dictionnaires, labels, notifications).
nonisolated enum PrayerName: String, CaseIterable, Sendable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
}

/// Horaires d'une journée. `dhuhr` est déjà l'heure Jumu'ah le vendredi si
/// l'option est activée (`isFridayJumuah`).
nonisolated struct DaySchedule: Equatable, Sendable {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    let isFridayJumuah: Bool

    func time(for prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr: fajr
        case .dhuhr: dhuhr
        case .asr: asr
        case .maghrib: maghrib
        case .isha: isha
        }
    }

    /// Les cinq prières avec leur heure, dans l'ordre de la journée.
    var ordered: [(prayer: PrayerName, time: Date)] {
        PrayerName.allCases.map { ($0, time(for: $0)) }
    }
}

// MARK: - Calcul

nonisolated enum SharedPrayerSchedule {

    /// Horaires résolus pour un instant donné : la journée de cet instant + le
    /// Fajr du lendemain (nécessaire après Isha et pour le milieu de la nuit).
    nonisolated struct Resolved: Equatable, Sendable {
        let today: DaySchedule
        let tomorrowFajr: Date
        /// `true` si calculé localement (position publiée) ; `false` si repli sur
        /// les timestamps publiés par l'app iOS, qui peuvent être périmés.
        let isComputedLocally: Bool
    }

    static func isFriday(_ day: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: day) == 6
    }

    /// Heure Jumu'ah (hh:mm des réglages) posée sur la journée de `day`.
    static func jumuahTime(on day: Date, hour: Int, minute: Int, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    /// Horaires de la journée de `day` pour `settings` (Adhan + Jumu'ah).
    ///
    /// - Returns: `nil` si Adhan ne peut pas calculer (coordonnées hors plage).
    static func schedule(for day: Date, settings: PrayerSettingsSnapshot, calendar: Calendar = .current) -> DaySchedule? {
        let params = PrayerCalculationEngine.parameters(
            method: settings.calculationMethod,
            fajrOffset: settings.fajrOffset,
            dhuhrOffset: settings.dhuhrOffset,
            asrOffset: settings.asrOffset,
            maghribOffset: settings.maghribOffset,
            ishaOffset: settings.ishaOffset,
            isIshaFixed: settings.isIshaFixed,
            ishaFixedDuration: settings.ishaFixedDuration
        )
        let coordinates = Coordinates(latitude: settings.latitude, longitude: settings.longitude)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        guard let times = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else {
            return nil
        }

        let friday = isFriday(day, calendar: calendar) && settings.jumuahEnabled
        let dhuhr = friday
            ? (jumuahTime(on: day, hour: settings.jumuahHour, minute: settings.jumuahMinute, calendar: calendar) ?? times.dhuhr)
            : times.dhuhr

        return DaySchedule(
            fajr: times.fajr,
            sunrise: times.sunrise,
            dhuhr: dhuhr,
            asr: times.asr,
            maghrib: times.maghrib,
            isha: times.isha,
            isFridayJumuah: friday
        )
    }

    /// Journée de `date` + Fajr du lendemain, calculés localement.
    static func resolve(at date: Date, settings: PrayerSettingsSnapshot, calendar: Calendar = .current) -> Resolved? {
        guard let today = schedule(for: date, settings: settings, calendar: calendar),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
              let next = schedule(for: tomorrow, settings: settings, calendar: calendar) else {
            return nil
        }
        return Resolved(today: today, tomorrowFajr: next.fajr, isComputedLocally: true)
    }

    /// Point d'entrée des extensions (widget, complication, app Watch).
    ///
    /// Calcul local dès que l'app iPhone a publié une position — la journée
    /// bascule donc toute seule à minuit, sans que l'app tourne. Sinon, repli sur
    /// les timestamps `prayer_*` publiés (comportement historique).
    static func resolve(at date: Date, defaults: UserDefaults?, calendar: Calendar = .current) -> Resolved? {
        if let settings = PrayerSettingsSnapshot.load(from: defaults),
           let resolved = resolve(at: date, settings: settings, calendar: calendar) {
            return resolved
        }
        return publishedSchedule(from: defaults, calendar: calendar)
    }

    /// Repli : horaires reconstruits depuis les timestamps publiés par l'app iOS.
    static func publishedSchedule(from defaults: UserDefaults?, calendar: Calendar = .current) -> Resolved? {
        guard let d = defaults else { return nil }
        func date(_ key: String) -> Date? {
            let value = d.double(forKey: key)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        guard let fajr = date(StorageKeys.prayerFajr),
              let dhuhr = date(StorageKeys.prayerDhuhr),
              let asr = date(StorageKeys.prayerAsr),
              let maghrib = date(StorageKeys.prayerMaghrib),
              let isha = date(StorageKeys.prayerIsha) else {
            return nil
        }
        let today = DaySchedule(
            fajr: fajr,
            sunrise: date(StorageKeys.prayerSunrise) ?? dhuhr,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            isFridayJumuah: isFriday(fajr, calendar: calendar) && d.bool(forKey: StorageKeys.wJumuahEnabled)
        )
        let tomorrowFajr = date(StorageKeys.prayerFajrTomorrow) ?? fajr.addingTimeInterval(24 * 3600)
        return Resolved(today: today, tomorrowFajr: tomorrowFajr, isComputedLocally: false)
    }
}

// MARK: - Dérivés (prochaine prière, fenêtres)

nonisolated extension SharedPrayerSchedule.Resolved {

    /// Prochaine prière à `date` : première heure de début strictement future,
    /// sinon le Fajr du lendemain. Sémantique commune widget / complication / Watch.
    func nextPrayer(at date: Date) -> (prayer: PrayerName, time: Date) {
        if let upcoming = today.ordered.first(where: { $0.time > date }) {
            return upcoming
        }
        return (.fajr, tomorrowFajr)
    }

    var middleOfNight: Date {
        PrayerCalculationEngine.nightMarkers(maghrib: today.maghrib, fajrTomorrow: tomorrowFajr).middleOfNight
    }

    /// Fin de la fenêtre d'une prière (jurisprudence) : Fajr → lever du soleil,
    /// Isha → milieu de la nuit, sinon début de la prière suivante.
    func windowEnd(of prayer: PrayerName) -> Date {
        switch prayer {
        case .fajr: today.sunrise
        case .dhuhr: today.asr
        case .asr: today.maghrib
        case .maghrib: today.isha
        case .isha: middleOfNight
        }
    }

    func currentWindow(at date: Date) -> (window: PrayerWindow, start: Date?, end: Date?) {
        PrayerCalculationEngine.currentWindow(
            now: date,
            fajr: today.fajr,
            sunrise: today.sunrise,
            dhuhr: today.dhuhr,
            asr: today.asr,
            maghrib: today.maghrib,
            isha: today.isha,
            middleOfNight: middleOfNight
        )
    }
}
