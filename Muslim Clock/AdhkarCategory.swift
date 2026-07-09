//
//  AdhkarCategory.swift
//  Muslim Clock — Livret d'invocations (type Hisn al-Muslim, authentifié)
//
//  Modèle de contenu. Réutilise `Dhikr` (déjà porteur de source + authenticity)
//  pour éviter toute duplication de modèle (DRY).
//

import Foundation

/// Identifiants de moments situationnels reconnus par le moteur de suggestion.
///
/// Ce ne sont **pas** un type décodé : `AdhkarCategory.moments` est un `[String]`
/// libre (robustesse — un moment inconnu dans le JSON ne casse jamais le décodage,
/// il est simplement ignoré par la suggestion). Ces constantes évitent les
/// « magic strings » côté `AdhkarSuggestion`.
enum AdhkarMoment {
    static let wake = "wake"                    // au réveil (après Fajr)
    static let wudu = "wudu"                    // ablutions (avant la prière + Qiyâm)
    static let mosque = "mosque"                // entrée / sortie de la mosquée
    static let adhanResponse = "adhan_response" // réponse à l'appel (à l'heure de l'adhan)
    static let qiyam = "qiyam"                  // dernier tiers de la nuit
    static let sleep = "sleep"                  // avant de dormir
    static let eating = "eating"                // repas
    // Sans déclencheur temporel (jamais auto-suggérés, accessibles via la liste) :
    // "toilet", "house", "anytime".
}

/// Une catégorie du livret : un thème (réveil, ablutions, mosquée…) regroupant
/// ses invocations. `moments` pilote la suggestion contextuelle.
struct AdhkarCategory: Codable, Identifiable {
    let id: String
    /// Titre arabe (affiché en RTL).
    let titleAr: String
    /// Titre français.
    let titleFr: String
    /// SF Symbol de la catégorie.
    let icon: String
    /// Moments où la catégorie est pertinente (chaînes libres — cf. `AdhkarMoment`).
    let moments: [String]
    /// Invocations de la catégorie (modèle partagé avec les adhkar matin/soir).
    let adhkar: [Dhikr]
}
