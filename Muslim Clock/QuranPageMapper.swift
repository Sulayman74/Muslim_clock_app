//
//  QuranPageMapper.swift
//  Muslim Clock — module Quran Library
//
//  Bridge entre l'unité « page Madinah » (1…604) utilisée par le plan Khatma et
//  l'unité « (sura, ayah) » utilisée par l'API `quran-json`.
//
//  Source : Tanzil.net (Complex Roi Fahd), mushaf Madinah standard. Fichier statique
//  embarqué `quran-page-mapping.json` — 604 entrées (1ʳᵉ ayah de chaque page).
//
//  Robustesse : pas de force unwrap. Lookup ayah→page en recherche binaire O(log 604) ≈ 10 itérations.
//  Performance : décodé une seule fois au 1er appel, gardé en mémoire (≈ 30 KB).
//

import Foundation
import os

/// Représente la 1ère ayah d'une page Madinah donnée.
struct QuranPageEntry: Codable, Hashable {
    let page: Int          // 1...604
    let firstSura: Int     // 1...114
    let firstAyah: Int     // numéro d'ayah dans la sourate

    enum CodingKeys: String, CodingKey {
        case page
        case firstSura = "first_sura"
        case firstAyah = "first_ayah"
    }
}

/// Wrapper racine du JSON embarqué.
private struct QuranPageMappingFile: Codable {
    let source: String
    let version: String
    let totalPages: Int
    let pages: [QuranPageEntry]

    enum CodingKeys: String, CodingKey {
        case source, version, pages
        case totalPages = "total_pages"
    }
}

@MainActor
final class QuranPageMapper {

    static let shared = QuranPageMapper()

    private let log = Logger(subsystem: "kappsi.Muslim-Clock", category: "QuranPageMapper")

    /// Mapping trié par `page` croissant (et donc aussi par `firstSura/firstAyah` croissant).
    private(set) var pages: [QuranPageEntry] = []

    /// Indique si le mapping a pu être chargé. `false` désactive proprement les features
    /// dépendantes (auto-scroll, "Reprendre où j'en étais") sans crash.
    var isAvailable: Bool { !pages.isEmpty }

    private init() {
        loadIfNeeded()
    }

    // MARK: - Chargement (idempotent)

    func loadIfNeeded() {
        guard pages.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "quran-page-mapping", withExtension: "json") else {
            log.error("quran-page-mapping.json introuvable dans le bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(QuranPageMappingFile.self, from: data)
            // Sécurité : trier par page croissant (le fichier l'est déjà mais on garantit l'invariant).
            pages = decoded.pages.sorted { $0.page < $1.page }
            log.info("Mapping chargé : \(decoded.pages.count) pages — source: \(decoded.source, privacy: .public)")
        } catch {
            log.error("Erreur décodage mapping : \(error.localizedDescription)")
        }
    }

    // MARK: - Lookups

    /// Renvoie la page Madinah contenant un verset donné, ou `nil` si hors mushaf.
    ///
    /// Algorithme : recherche binaire pour trouver la dernière `QuranPageEntry` dont
    /// `(firstSura, firstAyah)` est `≤ (sura, ayah)`. Cette entrée définit la page de ce verset.
    func page(for sura: Int, ayah: Int) -> Int? {
        guard !pages.isEmpty else { return nil }
        guard sura >= 1 && ayah >= 1 else { return nil }

        let key = (sura, ayah)
        var lo = 0
        var hi = pages.count - 1
        var best: Int?

        while lo <= hi {
            let mid = (lo + hi) / 2
            let entry = pages[mid]
            if (entry.firstSura, entry.firstAyah) <= key {
                best = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return best.map { pages[$0].page }
    }

    /// Renvoie la 1ère ayah d'une page Madinah donnée (1…604).
    func firstAyah(of page: Int) -> (sura: Int, ayah: Int)? {
        guard let entry = pages.first(where: { $0.page == page }) else { return nil }
        return (entry.firstSura, entry.firstAyah)
    }

    /// Pour un numéro de sourate donné, renvoie le numéro de la 1ère page qui la contient.
    /// Utile pour le bouton "Reprendre où j'en étais" si on veut afficher directement la sourate.
    func firstPage(of sura: Int) -> Int? {
        pages.first(where: { $0.firstSura == sura })?.page
    }
}

// MARK: - Helper de comparaison de tuples

private func <= (lhs: (Int, Int), rhs: (Int, Int)) -> Bool {
    if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
    return lhs.1 <= rhs.1
}
