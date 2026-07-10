//
//  AdhkarSearch.swift
//  Muslim Clock — Livret d'invocations
//
//  Filtrage pur (texte FR/arabe + authenticité). Sans état ni SwiftUI → testable
//  en isolation (pattern AdhkarSuggestion / IlmMath).
//

import Foundation

enum AdhkarSearch {

    /// Filtre les catégories par texte et par niveau d'authenticité.
    ///
    /// - La recherche texte est insensible aux accents FR et aux harakât arabes.
    /// - Si le titre d'une catégorie correspond, toutes ses invocations (respectant
    ///   le filtre d'authenticité) sont retournées.
    /// - Une catégorie sans aucune invocation retenue est retirée du résultat.
    ///
    /// - Parameters:
    ///   - categories: contenu complet du livret.
    ///   - query: texte saisi (vide = pas de filtre texte).
    ///   - authenticity: "sahih"/"hasan"/… ou `nil` pour tous les niveaux.
    static func filter(
        _ categories: [AdhkarCategory],
        query: String,
        authenticity: String?
    ) -> [AdhkarCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !trimmed.isEmpty
        let q = trimmed.searchFoldedFr
        let qAr = trimmed.strippedTashkeel

        return categories.compactMap { category in
            let titleMatches = hasQuery && (
                category.titleFr.searchFoldedFr.contains(q) ||
                category.titleAr.strippedTashkeel.contains(qAr)
            )

            let matching = category.adhkar.filter { dhikr in
                if let authenticity, dhikr.authenticity != authenticity { return false }
                // Pas de texte recherché, ou titre déjà pertinent → on garde tout
                // (sous réserve du filtre d'authenticité ci-dessus).
                guard hasQuery, !titleMatches else { return true }
                return dhikr.text.searchFoldedFr.contains(q)
                    || dhikr.benefit.searchFoldedFr.contains(q)
                    || dhikr.source.searchFoldedFr.contains(q)
                    || dhikr.arabic.strippedTashkeel.contains(qAr)
            }

            guard !matching.isEmpty else { return nil }
            return AdhkarCategory(
                id: category.id,
                titleAr: category.titleAr,
                titleFr: category.titleFr,
                icon: category.icon,
                moments: category.moments,
                adhkar: matching
            )
        }
    }
}
