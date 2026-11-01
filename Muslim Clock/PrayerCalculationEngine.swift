//
//  PrayerCalculationEngine.swift
//  Muslim Clock — cœur de calcul des horaires (pur, testable).
//
//  Extrait de `PrayerTimesViewModel` (refactor testabilité) : fonctions pures,
//  sans état, sans SwiftUI, sans I/O. Le ViewModel les appelle pour construire
//  les paramètres Adhan et dériver les fenêtres — comportement inchangé.
//
//  Fichier PARTAGÉ par les 4 cibles (app, widget, complication, Watch) via
//  `SharedPrayerSchedule` : `nonisolated` pour être appelable depuis les
//  TimelineProvider (hors MainActor) comme depuis les ViewModels.
//

import Foundation
import Adhan

/// Fenêtre de prière en cours (jurisprudence), ou `.none` hors fenêtre.
nonisolated enum PrayerWindow: String, Sendable {
    case fajr = "Fajr", dhuhr = "Dhuhr", asr = "Asr"
    case maghrib = "Maghrib", isha = "Isha", none = "none"

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        case .none: return ""
        }
    }

    var icon: String {
        switch self {
        case .fajr: return "sun.and.horizon.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.dust.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        case .none: return "clock.fill"
        }
    }
}

nonisolated enum PrayerCalculationEngine {

    // MARK: - Méthodes

    /// Les trois méthodes « classiques » proposées à l'utilisateur, avec leur
    /// angle Fajr. Source unique pour les pickers (Réglages, Ajustements) et
    /// pour les candidats de la Configuration Magique.
    static let classicMethods: [(name: String, fajrAngle: Double)] = [
        ("UOIF (12°)", 12),
        ("ISNA (15°)", 15),
        ("Ligue Islamique (18°)", 18),
    ]

    static var classicMethodNames: [String] { classicMethods.map(\.name) }

    /// Méthode par défaut de l'app (usage majoritaire en France).
    static let defaultMethod = "UOIF (12°)"

    /// Ramène une valeur stockée à une méthode classique. « Mosquée de Paris »
    /// (ancien préréglage 18°/18°, retiré des pickers) devient Ligue Islamique ;
    /// toute valeur inconnue retombe sur Ligue Islamique comme avant.
    static func normalizedMethod(_ method: String) -> String {
        classicMethodNames.contains(method) ? method : "Ligue Islamique (18°)"
    }

    // MARK: - Paramètres Adhan

    /// Construit les `CalculationParameters` Adhan à partir de la méthode choisie
    /// et des offsets utilisateur (temkine). Madhab Shafi fixé (Asr).
    ///
    /// Méthodes reconnues : "UOIF (12°)", "ISNA (15°)", "Ligue Islamique (18°)".
    /// Toute autre valeur (dont l'ancien « Mosquée de Paris ») est normalisée via
    /// `normalizedMethod` → Ligue Islamique.
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
        switch normalizedMethod(method) {
        case "UOIF (12°)":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 12
            params.ishaAngle = 12
        case "ISNA (15°)":
            params = CalculationMethod.northAmerica.params
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

    /// Fenêtre Isha de la **veille** : entre minuit et le milieu de la nuit
    /// (Maghrib d'hier → Fajr d'aujourd'hui), la prière d'Isha est encore valide
    /// alors que `currentWindow` ne regarde que les horaires du jour. `.none`
    /// si l'on n'est pas avant le Fajr du jour ou si le milieu de nuit est passé.
    static func previousNightWindow(
        now: Date,
        fajrToday: Date,
        maghribYesterday: Date,
        ishaYesterday: Date
    ) -> (window: PrayerWindow, start: Date?, end: Date?) {
        guard now < fajrToday else { return (.none, nil, nil) }
        let middle = nightMarkers(maghrib: maghribYesterday, fajrTomorrow: fajrToday).middleOfNight
        if now >= ishaYesterday && now < middle { return (.isha, ishaYesterday, middle) }
        return (.none, nil, nil)
    }

    // MARK: - Rafraîchissement de l'état

    /// Prochain instant où l'état affiché change de lui-même : fin de la fenêtre
    /// en cours, heure de la prochaine prière, ou minuit (nouvelle journée).
    /// Sert de borne au minuteur du ViewModel — sans lui, la jauge restait figée
    /// au lever du soleil ou quand les notifications d'adhan sont refusées.
    ///
    /// - Returns: le plus proche des candidats strictement postérieurs à `now`.
    ///   Minuit est toujours candidat, donc le résultat n'est jamais `nil`.
    static func nextRefreshDate(
        now: Date,
        windowEnd: Date?,
        nextPrayer: Date?,
        calendar: Calendar = .current
    ) -> Date {
        let startOfTomorrow = calendar.startOfDay(for: now).addingTimeInterval(86_400)
        let midnight = calendar.startOfDay(for: startOfTomorrow)
        let candidates = [windowEnd, nextPrayer, midnight].compactMap { $0 }.filter { $0 > now }
        return candidates.min() ?? midnight
    }
}
