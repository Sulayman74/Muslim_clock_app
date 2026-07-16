//
//  PrayerSynchronizer.swift
//  Muslim Clock — publication des horaires & réglages vers l'App Group, la Watch
//  et les widgets.
//
//  Extrait de `PrayerTimesViewModel` (refactor SRP) : cette couche fait UNIQUEMENT
//  l'I/O de partage (UserDefaults App Group + WatchConnectivity + WidgetCenter).
//  Le calcul reste dans le ViewModel / `PrayerCalculationEngine`.
//
//  ⚠️ Non-régression : l'ordre et les valeurs des écritures sont identiques à
//  l'implémentation d'origine (contrat lu par widgets/complication/watch).
//

import Foundation
import CoreLocation
import WidgetKit

/// Miroir des réglages de calcul, publié pour la Watch et les widgets.
struct PrayerSyncSettings {
    let calculationMethod: String
    let fajrOffset: Int
    let dhuhrOffset: Int
    let asrOffset: Int
    let maghribOffset: Int
    let ishaOffset: Int
    let isIshaFixed: Bool
    let ishaFixedDuration: Int
    let jumuahEnabled: Bool
    let jumuahHour: Int
    let jumuahMinute: Int
}

enum PrayerSynchronizer {

    /// Publie les horaires du jour dans l'App Group + les envoie à la Watch.
    /// `dhuhr` doit déjà refléter l'heure Jumu'ah si applicable. `fajrTomorrow`
    /// permet à la complication de calculer la fin de la fenêtre Isha.
    static func publishSchedule(
        fajr: Date,
        sunrise: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        fajrTomorrow: Date?
    ) {
        let shared = UserDefaults(suiteName: AppGroup.identifier)
        shared?.set(fajr.timeIntervalSince1970, forKey: StorageKeys.prayerFajr)
        shared?.set(dhuhr.timeIntervalSince1970, forKey: StorageKeys.prayerDhuhr)
        shared?.set(asr.timeIntervalSince1970, forKey: StorageKeys.prayerAsr)
        shared?.set(maghrib.timeIntervalSince1970, forKey: StorageKeys.prayerMaghrib)
        shared?.set(isha.timeIntervalSince1970, forKey: StorageKeys.prayerIsha)
        shared?.set(sunrise.timeIntervalSince1970, forKey: StorageKeys.prayerSunrise)
        if let fajrTomorrow {
            shared?.set(fajrTomorrow.timeIntervalSince1970, forKey: StorageKeys.prayerFajrTomorrow)
        }

        var payload: [String: Double] = [
            StorageKeys.prayerFajr:    fajr.timeIntervalSince1970,
            StorageKeys.prayerSunrise: sunrise.timeIntervalSince1970,
            StorageKeys.prayerDhuhr:   dhuhr.timeIntervalSince1970,
            StorageKeys.prayerAsr:     asr.timeIntervalSince1970,
            StorageKeys.prayerMaghrib: maghrib.timeIntervalSince1970,
            StorageKeys.prayerIsha:    isha.timeIntervalSince1970,
        ]
        if let fajrTomorrow {
            payload[StorageKeys.prayerFajrTomorrow] = fajrTomorrow.timeIntervalSince1970
        }
        WatchSessionManager.shared.sendPrayerTimes(payload)
    }

    /// Publie la position + le miroir des réglages dans l'App Group, envoie les
    /// réglages à la Watch, puis rafraîchit les widgets. Appelé même si le calcul
    /// des horaires du jour a échoué (comme l'implémentation d'origine).
    static func publishSettings(location: CLLocation, settings: PrayerSyncSettings) {
        let shared = UserDefaults(suiteName: AppGroup.identifier)
        shared?.set(location.coordinate.latitude, forKey: StorageKeys.savedLatitude)
        shared?.set(location.coordinate.longitude, forKey: StorageKeys.savedLongitude)

        shared?.set(settings.calculationMethod, forKey: StorageKeys.wCalculationMethod)
        shared?.set(settings.fajrOffset, forKey: StorageKeys.wFajrOffset)
        shared?.set(settings.dhuhrOffset, forKey: StorageKeys.wDhuhrOffset)
        shared?.set(settings.asrOffset, forKey: StorageKeys.wAsrOffset)
        shared?.set(settings.maghribOffset, forKey: StorageKeys.wMaghribOffset)
        shared?.set(settings.isIshaFixed, forKey: StorageKeys.wIsIshaFixed)
        shared?.set(settings.ishaFixedDuration, forKey: StorageKeys.wIshaFixedDuration)
        shared?.set(settings.ishaOffset, forKey: StorageKeys.wIshaOffset)
        shared?.set(settings.jumuahEnabled, forKey: StorageKeys.wJumuahEnabled)
        shared?.set(settings.jumuahHour, forKey: StorageKeys.wJumuahHour)
        shared?.set(settings.jumuahMinute, forKey: StorageKeys.wJumuahMinute)

        WatchSessionManager.shared.sendSettings([
            StorageKeys.wJumuahEnabled: settings.jumuahEnabled,
            StorageKeys.wJumuahHour: settings.jumuahHour,
            StorageKeys.wJumuahMinute: settings.jumuahMinute,
        ])

        WidgetCenter.shared.reloadAllTimelines()
    }
}
