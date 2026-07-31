//
//  PodcastMath.swift
//  Muslim Clock
//
//  Fonctions pures du lecteur audio : progression, navigation épisode,
//  décodage/migration des positions de reprise.
//
//  Isolées de `PodcastManager` (qui gère AVPlayer + UserDefaults + I/O) pour
//  être testables sans effets de bord — même pattern que `IlmMath` et les
//  fonctions statiques de `CompassManager`.
//

import Foundation

enum PodcastMath {

    // MARK: - Progression de série

    /// Fraction d'épisodes lus dans `[0, 1]`.
    ///
    /// Seuls les épisodes présents dans `episodeURLs` **et** dans `playedURLs`
    /// comptent : une URL lue absente de la liste courante (ex. série changée)
    /// n'est pas comptabilisée.
    ///
    /// - Parameters:
    ///   - playedURLs: Ensemble des URLs (absolute string) déjà écoutées.
    ///   - episodeURLs: URLs des épisodes de la série courante, dans l'ordre.
    /// - Returns: Ratio lus/total, ou `0` si la série est vide.
    static func seriesProgress(playedURLs: Set<String>, episodeURLs: [String]) -> Double {
        guard !episodeURLs.isEmpty else { return 0 }
        let played = episodeURLs.reduce(into: 0) { count, url in
            if playedURLs.contains(url) { count += 1 }
        }
        return Double(played) / Double(episodeURLs.count)
    }

    // MARK: - Navigation épisode

    /// Index de l'épisode suivant, ou `nil` si `current` est le dernier / invalide.
    static func nextIndex(after current: Int, count: Int) -> Int? {
        guard current >= 0, current + 1 < count else { return nil }
        return current + 1
    }

    /// Index de l'épisode précédent, ou `nil` si `current` est le premier / invalide.
    static func previousIndex(before current: Int, count: Int) -> Int? {
        guard current - 1 >= 0, current < count else { return nil }
        return current - 1
    }

    // MARK: - Positions de reprise (décodage + migration)

    /// Décode le blob de positions de reprise stocké en `UserDefaults`.
    ///
    /// Gère deux formats pour la rétro-compatibilité prod :
    /// 1. Nouveau : dictionnaire `[urlString: secondes]` (position par épisode).
    /// 2. Ancien : `ResumeBookmark` unique → migré en une seule entrée.
    ///
    /// Les deux formats sont mutuellement non-ambigus (l'un a des valeurs
    /// `Double`, l'autre des clés `String` non-numériques), donc l'ordre d'essai
    /// n'importe pas.
    ///
    /// - Parameter data: Blob brut, ou `nil` si aucune donnée stockée.
    /// - Returns: Positions par URL. Vide si `data` est `nil` ou illisible.
    static func decodeResumePositions(from data: Data?) -> [String: Double] {
        guard let data else { return [:] }
        if let dict = try? JSONDecoder().decode([String: Double].self, from: data) {
            return dict
        }
        if let legacy = try? JSONDecoder().decode(ResumeBookmark.self, from: data) {
            return [legacy.episodeURL: legacy.position]
        }
        return [:]
    }

    /// Encode les positions de reprise pour stockage `UserDefaults`.
    static func encodeResumePositions(_ positions: [String: Double]) -> Data? {
        try? JSONEncoder().encode(positions)
    }

    /// Cible de reprise : `(url, position)` du dernier épisode joué si sa position
    /// dépasse `minimum` secondes, sinon `nil` (rien de significatif à reprendre).
    ///
    /// - Parameters:
    ///   - lastPlayedURL: URL du dernier épisode écouté pour la série.
    ///   - positions: Positions mémorisées par URL.
    ///   - minimum: Seuil sous lequel une reprise n'a pas de sens (défaut : 5 s).
    static func resumeTarget(
        lastPlayedURL: String?,
        positions: [String: Double],
        minimum: Double = 5
    ) -> (url: String, position: Double)? {
        guard let url = lastPlayedURL,
              let position = positions[url],
              position > minimum else { return nil }
        return (url, position)
    }

    // MARK: - Recherche playlist

    /// Indique si un titre d'épisode correspond à la requête de recherche.
    ///
    /// Comparaison insensible à la casse **et** aux diacritiques : gère le français
    /// accentué et l'arabe vocalisé (harakât). Une requête vide correspond à tout.
    static func episodeMatches(title: String, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        // Retire d'abord les harakât arabes, puis replie accents FR + casse
        // (mêmes helpers que la recherche Adhkar).
        let normalize: (String) -> String = { $0.strippedTashkeel.searchFoldedFr }
        return normalize(title).contains(normalize(query))
    }
}
