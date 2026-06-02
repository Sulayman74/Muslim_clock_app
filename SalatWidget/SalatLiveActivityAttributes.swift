//
//  SalatLiveActivityAttributes.swift
//  SalatWidget
//
//  Attributs partagés app iOS ↔ widget extension pour la Live Activity "Prochaine Salât".
//
//  Target membership : par défaut dans SalatWidgetExtension (dossier synchronisé).
//  Inclus aussi dans le target "Muslim Clock" via une exception déclarée dans le pbxproj
//  ("Exceptions for 'SalatWidget' folder in 'Muslim Clock' target"), au même titre que
//  AppIntent.swift et SalatWidget.swift.
//

import ActivityKit
import Foundation

/// Attributs constants de la Live Activity pour une prière donnée.
/// Le `ContentState` (heure cible) peut être mis à jour, mais les attributs (nom, clé) sont immuables.
struct SalatLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Heure de début de la prochaine prière (utilisée pour `Text(date, style: .timer)`).
        var targetTime: Date
    }

    /// Identifiant logique de la prière ("fajr", "dhuhr", "asr", "maghrib", "isha", "jumuah").
    let prayerKey: String

    /// Nom français affiché (ex: "Fajr", "Jumu'ah").
    let frenchName: String

    /// Nom arabe affiché (ex: "الفجر").
    let arabicName: String

    /// SF Symbol associé à la prière (sunrise.fill, sun.max.fill, etc.).
    let iconName: String
}
