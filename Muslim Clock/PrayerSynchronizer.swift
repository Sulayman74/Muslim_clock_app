//
//  PrayerSynchronizer.swift
//  Muslim Clock — publication des horaires & réglages vers l'App Group, la Watch
//  et les widgets.
//
//  Extrait de `PrayerTimesViewModel` (refactor SRP) : cette couche fait UNIQUEMENT
//  l'I/O de partage (UserDefaults App Group + WatchConnectivity + WidgetCenter).
//  Le calcul reste dans le ViewModel / `SharedPrayerSchedule`.
//
//  ⚠️ Non-régression : l'ordre et les valeurs des écritures App Group sont
//  identiques à l'implémentation d'origine (contrat lu par widgets/complication/watch).
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

extension PrayerSettingsSnapshot {
    /// Snapshot de calcul à partir des réglages de l'app et de la position courante.
    /// C'est ce snapshot que l'app iOS donne à `SharedPrayerSchedule` pour publier —
    /// exactement ce que les extensions reliront depuis l'App Group.
    init(location: CLLocation, sync: PrayerSyncSettings) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            calculationMethod: sync.calculationMethod,
            fajrOffset: sync.fajrOffset,
            dhuhrOffset: sync.dhuhrOffset,
            asrOffset: sync.asrOffset,
            maghribOffset: sync.maghribOffset,
            ishaOffset: sync.ishaOffset,
            isIshaFixed: sync.isIshaFixed,
            ishaFixedDuration: sync.ishaFixedDuration,
            jumuahEnabled: sync.jumuahEnabled,
            jumuahHour: sync.jumuahHour,
            jumuahMinute: sync.jumuahMinute
        )
    }
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
        fajrTomorrow: Date?,
        defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)
    ) {
        let shared = defaults
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

    /// Publie la position + le miroir des réglages dans l'App Group, envoie le tout
    /// à la Watch (file d'attente + contexte applicatif), puis rafraîchit les widgets.
    /// Appelé même si le calcul des horaires du jour a échoué (comme l'implémentation d'origine).
    static func publishSettings(
        location: CLLocation,
        settings: PrayerSyncSettings,
        defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)
    ) {
        let shared = defaults
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

        // Watch : position + réglages complets (et plus seulement Jumu'ah) pour que
        // la montre recalcule les horaires localement via SharedPrayerSchedule.
        let watchSettings = watchSettingsPayload(location: location, settings: settings)
        WatchSessionManager.shared.sendSettings(watchSettings)
        WatchSessionManager.shared.updateContext(
            watchContext(settingsPayload: watchSettings, defaults: shared)
        )

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Payloads Watch

    /// Position + réglages, sous les mêmes clés que l'App Group iOS : la montre les
    /// stocke tels quels et `PrayerSettingsSnapshot.load` les relit à l'identique.
    static func watchSettingsPayload(location: CLLocation, settings: PrayerSyncSettings) -> [String: Any] {
        [
            StorageKeys.savedLatitude:      location.coordinate.latitude,
            StorageKeys.savedLongitude:     location.coordinate.longitude,
            StorageKeys.wCalculationMethod: settings.calculationMethod,
            StorageKeys.wFajrOffset:        settings.fajrOffset,
            StorageKeys.wDhuhrOffset:       settings.dhuhrOffset,
            StorageKeys.wAsrOffset:         settings.asrOffset,
            StorageKeys.wMaghribOffset:     settings.maghribOffset,
            StorageKeys.wIshaOffset:        settings.ishaOffset,
            StorageKeys.wIsIshaFixed:       settings.isIshaFixed,
            StorageKeys.wIshaFixedDuration: settings.ishaFixedDuration,
            StorageKeys.wJumuahEnabled:     settings.jumuahEnabled,
            StorageKeys.wJumuahHour:        settings.jumuahHour,
            StorageKeys.wJumuahMinute:      settings.jumuahMinute,
        ]
    }

    /// Contexte applicatif complet : réglages + horaires du jour déjà publiés dans
    /// `defaults` (repli de la montre si elle ne peut pas calculer).
    static func watchContext(settingsPayload: [String: Any], defaults: UserDefaults?) -> [String: Any] {
        var context = settingsPayload
        let scheduleKeys = [
            StorageKeys.prayerFajr, StorageKeys.prayerSunrise, StorageKeys.prayerDhuhr,
            StorageKeys.prayerAsr, StorageKeys.prayerMaghrib, StorageKeys.prayerIsha,
            StorageKeys.prayerFajrTomorrow,
        ]
        for key in scheduleKeys {
            let value = defaults?.double(forKey: key) ?? 0
            if value > 0 { context[key] = value }
        }
        return context
    }
}
