//
//  SalatWidgetControl.swift
//  SalatWidget
//
//  Control Center widgets (iOS 18+) — boutons d'accès rapide depuis le Centre de Contrôle,
//  le bouton Action (iPhone 15 Pro+) et le Lock Screen.
//
//  Les intents `OpenInMuslimClockIntent` sont définis dans `AppIntent.swift` (membre des
//  2 targets : Muslim Clock + SalatWidgetExtension) — c'est une exigence Apple pour que
//  `OpenIntent` puisse ouvrir l'app depuis un Control Widget.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Control Widgets

/// Bouton "Qibla" dans le Centre de Contrôle / Lock Screen / bouton Action.
struct QiblaControlWidget: ControlWidget {
    static let kind: String = "kappsi.Muslim-Clock.controls.qibla"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenInMuslimClockIntent(target: .qibla)) {
                Label("Qibla", systemImage: "safari")
            }
        }
        .displayName("Qibla")
        .description("Ouvrir la boussole Qibla.")
    }
}

/// Bouton "Adhkar" dans le Centre de Contrôle / Lock Screen / bouton Action.
struct AdhkarControlWidget: ControlWidget {
    static let kind: String = "kappsi.Muslim-Clock.controls.adhkar"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenInMuslimClockIntent(target: .adhkar)) {
                Label("Adhkar", systemImage: "hands.sparkles.fill")
            }
        }
        .displayName("Adhkar du moment")
        .description("Ouvrir les Adhkar (matin ou soir selon l'heure).")
    }
}

/// Bouton "Lire le Coran" dans le Centre de Contrôle / Lock Screen / bouton Action.
struct QuranControlWidget: ControlWidget {
    static let kind: String = "kappsi.Muslim-Clock.controls.quran"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenInMuslimClockIntent(target: .quran)) {
                Label("Coran", systemImage: "book.pages.fill")
            }
        }
        .displayName("Lire le Coran")
        .description("Ouvrir la bibliothèque des sourates.")
    }
}
