//
//  StorageKeys.swift
//  Muslim Clock — source unique des clés UserDefaults (anti-typo).
//
//  Fichier PARTAGÉ par les 4 cibles (app, widget, complication, Watch) : les
//  extensions lisent les clés « App Group » via ces constantes, plus aucun
//  littéral dupliqué. Changer une *valeur* de clé reste une migration de données
//  (les valeurs déjà écrites sur les appareils ne seraient plus retrouvées).
//
//  Ne renseigne PAS ici les clés déjà encapsulées localement (ex.
//  NotificationDeepLink, AdhkarReminderScheduler) : elles ont leur propre namespace.
//

import Foundation

nonisolated enum StorageKeys {

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

    // MARK: - Iqamah (app, @AppStorage) — délais adhan → iqamah par prière

    static let iqamahFajrDelay = "iqamahFajrDelay"
    static let iqamahDhuhrDelay = "iqamahDhuhrDelay"
    static let iqamahAsrDelay = "iqamahAsrDelay"
    static let iqamahMaghribDelay = "iqamahMaghribDelay"
    static let iqamahIshaDelay = "iqamahIshaDelay"

    // MARK: - Configuration Magique (app)

    /// `MosqueObservation` encodée en JSON : horaires relevés dans la mosquée,
    /// date et position. Donnée de référence dont méthode et offsets sont dérivés.
    static let smartSetupObservation = "smartSetupObservation"

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

/// Délais adhan → iqamah par défaut (minutes), tant que l'utilisateur n'a rien
/// réglé dans « Ma mosquée ». Source unique : la liste des prières, la carte de
/// décompte, les réglages, la Configuration Magique et les rappels lisaient
/// chacun leur propre valeur — deux heures d'iqamah différentes à l'écran.
nonisolated enum IqamahDefaults {
    static let fajr = 20
    static let dhuhr = 15
    static let asr = 15
    static let maghrib = 5
    static let isha = 15

    /// Dictionnaire « nom de prière → délai » attendu par `IqamahMath` et les schedulers.
    static func delays(fajr: Int, dhuhr: Int, asr: Int, maghrib: Int, isha: Int) -> [String: Int] {
        ["Fajr": fajr, "Dhuhr": dhuhr, "Asr": asr, "Maghrib": maghrib, "Isha": isha]
    }
}
