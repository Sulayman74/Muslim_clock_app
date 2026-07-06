//
//  IlmContentLoader.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Charge ilm_tracks.json depuis le bundle — une seule lecture, cache mémoire
//  (pattern QuranPageMapper). Le contenu est canonique et figé : pas de remote.
//

import Foundation
import os

/// Source unique du contenu des parcours d'apprentissage.
///
/// Le JSON est décodé une seule fois à la première utilisation. En cas d'échec
/// (fichier absent/corrompu), `tracks` est vide et l'UI affiche un état neutre —
/// l'app ne crashe jamais (erreur loggée, frontière de décodage).
final class IlmContentLoader {

    static let shared = IlmContentLoader()

    /// Tous les parcours, dans l'ordre du JSON (ordre d'affichage).
    let tracks: [IlmTrack]

    /// Index par id pour lookup O(1).
    private let trackByID: [String: IlmTrack]

    var isAvailable: Bool { !tracks.isEmpty }

    func track(id: String) -> IlmTrack? {
        trackByID[id]
    }

    private init() {
        let logger = Logger(subsystem: "com.kappsi.muslimclock", category: "IlmContent")
        var loaded: [IlmTrack] = []

        if let url = Bundle.main.url(forResource: "ilm_tracks", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                loaded = try JSONDecoder().decode([IlmTrack].self, from: data)
            } catch {
                logger.error("Décodage ilm_tracks.json impossible: \(error.localizedDescription)")
            }
        } else {
            logger.error("ilm_tracks.json absent du bundle")
        }

        self.tracks = loaded
        self.trackByID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })

        // Invariants du contenu (debug uniquement) : ids de leçons uniques + parcours non vides.
        #if DEBUG
        let allLessonIDs = loaded.flatMap { $0.lessons.map(\.id) }
        assert(Set(allLessonIDs).count == allLessonIDs.count, "ilm_tracks.json : ids de leçons dupliqués")
        assert(loaded.allSatisfy { !$0.lessons.isEmpty }, "ilm_tracks.json : parcours sans leçons")
        #endif
    }
}
