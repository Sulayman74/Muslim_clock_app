//
//  AdhkarSuggestion.swift
//  Muslim Clock — Livret d'invocations
//
//  Logique pure de suggestion contextuelle : à un instant donné, quels moments
//  situationnels sont « actifs » d'après les horaires de prière réels.
//  Pas d'état, pas de SwiftUI → testable en isolation (pattern IlmMath).
//

import Foundation

enum AdhkarSuggestion {

    // MARK: - Fenêtres (constantes nommées, pas de magie inline)

    /// Autour de l'heure d'une prière = « l'adhan » (réponse à l'appel).
    private static let adhanWindow: TimeInterval = 5 * 60
    /// Avant une prière : ablutions + mosquée deviennent pertinentes.
    private static let preSalatBefore: TimeInterval = 20 * 60
    /// Durée après Fajr pendant laquelle « au réveil » est suggéré.
    private static let wakeWindow: TimeInterval = 90 * 60

    // MARK: - API

    /// Moments actifs à `now`, d'après les heures de prière du jour et, si dispo,
    /// le début du dernier tiers de la nuit.
    ///
    /// - Parameters:
    ///   - now: instant courant.
    ///   - prayerDates: Fajr, Dhuhr, Asr, Maghrib, Isha (ordre indifférent).
    ///   - fajr: heure du Fajr — `nil` si indisponible.
    ///   - lastThirdOfNight: début du dernier tiers — `nil` si indisponible.
    static func activeMoments(
        now: Date,
        prayerDates: [Date],
        fajr: Date?,
        lastThirdOfNight: Date?
    ) -> Set<String> {
        var moments: Set<String> = []

        for prayer in prayerDates {
            let delta = now.timeIntervalSince(prayer)
            if abs(delta) <= adhanWindow {
                moments.insert(AdhkarMoment.adhanResponse)
            }
            if delta >= -preSalatBefore && delta < 0 {
                moments.insert(AdhkarMoment.wudu)
                moments.insert(AdhkarMoment.mosque)
            }
        }

        // Dernier tiers de la nuit (jusqu'au Fajr) → Qiyâm + ablutions.
        if let lastThirdOfNight, let fajr,
           now >= lastThirdOfNight, now < fajr {
            moments.insert(AdhkarMoment.qiyam)
            moments.insert(AdhkarMoment.wudu)
        }

        // Fenêtre réveil : juste après Fajr.
        if let fajr, now >= fajr, now < fajr.addingTimeInterval(wakeWindow) {
            moments.insert(AdhkarMoment.wake)
        }

        // Sommeil / repas : plages horaires simples (indépendantes des prières).
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 22 || hour < 4 { moments.insert(AdhkarMoment.sleep) }
        if (11...13).contains(hour) || (19...21).contains(hour) { moments.insert(AdhkarMoment.eating) }

        return moments
    }

    /// Catégories à mettre en avant maintenant : celles qui partagent au moins un
    /// moment actif avec l'instant courant. Vide si aucun moment n'est actif →
    /// l'UI n'affiche alors pas de section « suggéré ».
    static func suggested(
        from categories: [AdhkarCategory],
        now: Date,
        prayerDates: [Date],
        fajr: Date?,
        lastThirdOfNight: Date?
    ) -> [AdhkarCategory] {
        let active = activeMoments(
            now: now,
            prayerDates: prayerDates,
            fajr: fajr,
            lastThirdOfNight: lastThirdOfNight
        )
        guard !active.isEmpty else { return [] }
        return categories.filter { !Set($0.moments).isDisjoint(with: active) }
    }
}
