//
//  PrayerCalculationEngine.swift
//  Muslim Clock — cœur de calcul des horaires (pur, testable).
//
//  Extrait de `PrayerTimesViewModel` (refactor testabilité) : fonctions pures,
//  sans état, sans SwiftUI, sans I/O. Le ViewModel les appelle pour construire
//  les paramètres Adhan et dériver les fenêtres — comportement inchangé.
//

import Foundation
import Adhan

enum PrayerCalculationEngine {

    // MARK: - Paramètres Adhan

    /// Construit les `CalculationParameters` Adhan à partir de la méthode choisie
    /// et des offsets utilisateur (temkine). Madhab Shafi fixé (Asr).
    ///
    /// Méthodes reconnues : "UOIF (12°)", "ISNA (15°)", "Mosquée de Paris",
    /// et par défaut "Ligue Islamique (18°)".
    static func parameters(
        method: String,
        fajrOffset: Int,
        dhuhrOffset: Int,
        asrOffset: Int,
        maghribOffset: Int,
        ishaOffset: Int,
        isIshaFixed: Bool,
        ishaFixedDuration: Int
    ) -> CalculationParameters {
        var params: CalculationParameters
        switch method {
        case "UOIF (12°)":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 12
            params.ishaAngle = 12
        case "ISNA (15°)":
            params = CalculationMethod.northAmerica.params
        case "Mosquée de Paris":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 18
            params.ishaAngle = 18
        default: // "Ligue Islamique (18°)"
            params = CalculationMethod.muslimWorldLeague.params
        }

        params.madhab = .shafi

        params.adjustments.fajr = fajrOffset
        params.adjustments.dhuhr = dhuhrOffset
        params.adjustments.asr = asrOffset
        params.adjustments.maghrib = maghribOffset

        if isIshaFixed {
            params.ishaInterval = ishaFixedDuration
            params.adjustments.isha = maghribOffset
        } else {
            params.adjustments.isha = ishaOffset
        }
        return params
    }

    // MARK: - Marqueurs de nuit

    /// Milieu de la nuit (Maghrib + moitié de la nuit) et début du dernier tiers
    /// (Fajr du lendemain − tiers de la nuit), à partir du Maghrib du jour et du
    /// Fajr du lendemain.
    static func nightMarkers(
        maghrib: Date,
        fajrTomorrow: Date
    ) -> (middleOfNight: Date, lastThirdOfNight: Date) {
        let nightDuration = fajrTomorrow.timeIntervalSince(maghrib)
        return (
            middleOfNight: maghrib.addingTimeInterval(nightDuration / 2),
            lastThirdOfNight: fajrTomorrow.addingTimeInterval(-(nightDuration / 3))
        )
    }

    // MARK: - Fenêtre de prière en cours

    /// Fenêtre de prière active à `now` selon la jurisprudence :
    /// Fajr→Sunrise, Dhuhr→Asr, Asr→Maghrib, Maghrib→Isha, Isha→milieu de la nuit.
    /// `.none` en dehors (nuit après le milieu, ou entre Sunrise et Dhuhr).
    static func currentWindow(
        now: Date,
        fajr: Date,
        sunrise: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        middleOfNight: Date
    ) -> (window: PrayerWindow, start: Date?, end: Date?) {
        if now >= fajr && now < sunrise    { return (.fajr, fajr, sunrise) }
        if now >= dhuhr && now < asr       { return (.dhuhr, dhuhr, asr) }
        if now >= asr && now < maghrib     { return (.asr, asr, maghrib) }
        if now >= maghrib && now < isha    { return (.maghrib, maghrib, isha) }
        if now >= isha && now < middleOfNight { return (.isha, isha, middleOfNight) }
        return (.none, nil, nil)
    }
}
