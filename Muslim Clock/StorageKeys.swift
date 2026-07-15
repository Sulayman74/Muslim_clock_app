//
//  StorageKeys.swift
//  Muslim Clock — source unique des clés UserDefaults (anti-typo).
//
//  ⚠️ CONTRAT INTER-TARGETS : les clés du groupe « App Group » ci-dessous sont
//  lues par les extensions (widget / complication / watch) qui, elles, utilisent
//  encore des littéraux identiques. NE JAMAIS changer une *valeur* de clé sans
//  mettre à jour la lecture correspondante côté extension — sinon les horaires
//  partagés (widgets/watch) cassent silencieusement.
//
//  Ne renseigne PAS ici les clés déjà encapsulées localement (ex.
//  NotificationDeepLink, AdhkarReminderScheduler) : elles ont leur propre namespace.
//

import Foundation

enum StorageKeys {

    // MARK: - Réglages de calcul (app, @AppStorage)

    static let fajrOffset = "userFajrOffset"
    static let calculationMethod = "userCalculationMethod"
    static let maghribOffset = "userMaghribOffset"
    static let isIshaFixed = "isIshaFixed"
    static let ishaFixedDuration = "userIshaFixedDuration"
    static let ishaOffset = "userIshaOffset"
    static let dhuhrOffset = "userDhuhrOffset"
    static let asrOffset = "userAsrOffset"
    static let jumuahEnabled = "jumuahEnabled"
    static let jumuahHour = "jumuahHour"
    static let jumuahMinute = "jumuahMinute"

    // MARK: - Horaires partagés (App Group) — lus par widgets/watch/complication

    static let prayerFajr = "prayer_fajr"
    static let prayerDhuhr = "prayer_dhuhr"
    static let prayerAsr = "prayer_asr"
    static let prayerMaghrib = "prayer_maghrib"
    static let prayerIsha = "prayer_isha"
    static let prayerSunrise = "prayer_sunrise"
    static let prayerFajrTomorrow = "prayer_fajr_tomorrow"
    static let savedLatitude = "saved_latitude"
    static let savedLongitude = "saved_longitude"

    // MARK: - Miroir des réglages pour Watch/Widget (préfixe « w_ »)

    static let wCalculationMethod = "w_calculationMethod"
    static let wFajrOffset = "w_fajrOffset"
    static let wDhuhrOffset = "w_dhuhrOffset"
    static let wAsrOffset = "w_asrOffset"
    static let wMaghribOffset = "w_maghribOffset"
    static let wIsIshaFixed = "w_isIshaFixed"
    static let wIshaFixedDuration = "w_ishaFixedDuration"
    static let wIshaOffset = "w_ishaOffset"
    static let wJumuahEnabled = "w_jumuahEnabled"
    static let wJumuahHour = "w_jumuahHour"
    static let wJumuahMinute = "w_jumuahMinute"
}
