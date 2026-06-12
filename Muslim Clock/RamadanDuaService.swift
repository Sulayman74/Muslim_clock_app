//
//  RamadanDuaService.swift
//  Muslim Clock — module Ramadan
//
//  Charge le pool de du'as Ramadan (OTA + cache + bundle) et sélectionne
//  la du'a contextuelle selon le moment de la journée (Iftar / Suhoor / général).
//

import Foundation
import SwiftUI

// MARK: - Modèle

enum RamadanDuaCategory: String, Codable {
    case iftar
    case suhoor
    case general
}

struct RamadanDua: Codable, Identifiable {
    let id: String
    let category: RamadanDuaCategory
    let arabic: String
    let french: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, category, arabic, french, source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.arabic = try c.decode(String.self, forKey: .arabic)
        self.french = try c.decode(String.self, forKey: .french)
        self.source = try c.decode(String.self, forKey: .source)
        // Tolérant : catégorie inconnue → .general (forward-compat).
        let raw = try c.decodeIfPresent(String.self, forKey: .category)
        self.category = raw.flatMap { RamadanDuaCategory(rawValue: $0) } ?? .general
    }
}

// MARK: - Contexte temporel

/// Fenêtre temporelle déterminant quelle catégorie de du'a afficher.
enum RamadanDuaWindow {
    case iftar
    case suhoor
    case general

    var category: RamadanDuaCategory {
        switch self {
        case .iftar:   return .iftar
        case .suhoor:  return .suhoor
        case .general: return .general
        }
    }
}

// MARK: - Service

@MainActor
@Observable
final class RamadanDuaService {

    /// Pool complet chargé depuis le JSON (OTA → cache → bundle).
    private(set) var allDuas: [RamadanDua] = []

    /// Indique si un chargement est en cours (pour skeleton UI).
    private(set) var isLoading: Bool = false

    /// URL OTA — peut être 404 sans casser l'app (fallback bundle).
    private let remoteURL = "https://sulayman74.github.io/Muslim_clock_app/ramadan_duas.json"

    /// Charge le pool. À appeler une fois quand on entre dans Ramadan.
    func loadIfNeeded() async {
        guard allDuas.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let loaded = await RemoteJSONLoader.load(
            filename: "ramadan_duas.json",
            remoteURL: remoteURL,
            type: [RamadanDua].self
        )
        if let loaded {
            self.allDuas = loaded
        }
    }

    /// Sélectionne la fenêtre courante en fonction des horaires de prière.
    ///
    /// - Fenêtre **Iftar** : `[Maghrib − 30min, Maghrib + 30min]` — moment de la rupture.
    /// - Fenêtre **Suhoor** : `[Isha, Fajr]` (gestion du débord après minuit) — fenêtre du sahari.
    /// - Sinon : `general` — du'a du mois.
    ///
    /// En DEBUG, l'override `debugRamadanWindow` (settings) force une fenêtre
    /// (`iftar`, `suhoor`, `general`) pour pouvoir tester la carte sans attendre
    /// l'heure réelle. Vide = auto.
    ///
    /// - Parameters:
    ///   - now: Date courante (injectable pour tests).
    ///   - maghrib: Heure du Maghrib aujourd'hui.
    ///   - isha: Heure d'Isha aujourd'hui.
    ///   - fajr: Heure de Fajr aujourd'hui (ou demain selon contexte).
    static func currentWindow(
        now: Date = .now,
        maghrib: Date?,
        isha: Date?,
        fajr: Date?
    ) -> RamadanDuaWindow {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "debugRamadanWindow") {
        case "iftar":   return .iftar
        case "suhoor":  return .suhoor
        case "general": return .general
        default:        break // tombe sur logique réelle ci-dessous
        }
        #endif

        let iftarOffset: TimeInterval = 30 * 60
        if let m = maghrib,
           now >= m.addingTimeInterval(-iftarOffset),
           now <= m.addingTimeInterval(iftarOffset) {
            return .iftar
        }
        if let i = isha, let f = fajr {
            // Cas 1 : isha < fajr (même journée) → après Isha et avant Fajr.
            if i < f, now >= i, now < f {
                return .suhoor
            }
            // Cas 2 : on est passé minuit, isha appartient à hier — on
            // approxime en disant : tant que now < fajr aujourd'hui, on est dans le sahari.
            if i >= f, now < f {
                return .suhoor
            }
        }
        return .general
    }

    /// Renvoie une du'a de la catégorie cible, ou `nil` si aucune disponible.
    func dua(for window: RamadanDuaWindow) -> RamadanDua? {
        let category = window.category
        let matching = allDuas.filter { $0.category == category }
        if !matching.isEmpty { return matching.randomElement() }
        // Fallback : si aucune du'a de la catégorie demandée, on tente general.
        if category != .general {
            return allDuas.first(where: { $0.category == .general })
        }
        return allDuas.first
    }
}
