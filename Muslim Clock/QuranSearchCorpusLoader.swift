//
//  QuranSearchCorpusLoader.swift
//  Muslim Clock — Spotlight du Coran (Phase 1)
//
//  Charge le corpus de recherche bundlé (quran-search-corpus.json — texte
//  imla'i des 6 236 versets + noms de sourates, ~1,35 Mo) et construit
//  l'index en arrière-plan. 100 % offline.
//
//  Le corpus de RECHERCHE est distinct de la bibliothèque d'AFFICHAGE
//  (QuranLibraryLoader, graphie uthmani, CDN + cache partiel) : la recherche
//  exige la graphie moderne (celle des requêtes tapées/dictées) et la
//  couverture complète hors-ligne. Le tap sur un résultat ouvre le lecteur
//  uthmani habituel.
//

import Foundation

// MARK: - Schéma du corpus bundlé

// nonisolated : décodés dans une Task.detached (hors MainActor) — même idiome
// que TravelStatus/RamadanDuaWindow pour Swift 6.
private nonisolated struct CorpusFile: Decodable {
    let s: [CorpusSura]
}

private nonisolated struct CorpusSura: Decodable {
    let c: Int        // numéro de sourate
    let n: String     // nom arabe
    let e: String     // nom anglais/translittéré
    let v: [CorpusVerse]
}

private nonisolated struct CorpusVerse: Decodable {
    let i: Int        // numéro de verset
    let t: String     // texte imla'i vocalisé
}

// MARK: - Loader

/// Métadonnées de sourate issues du corpus (affichage des résultats offline).
nonisolated struct QuranSuraMeta: Sendable {
    let arabicName: String
    let englishName: String
    let verseCount: Int
}

@MainActor
@Observable
final class QuranSearchCorpusLoader {

    static let shared = QuranSearchCorpusLoader()
    private init() {}

    /// Index prêt à interroger. `nil` tant que `loadIndex()` n'a pas abouti.
    private(set) var index: QuranVerseIndex?

    /// Noms de sourates par numéro — pour afficher les résultats sans réseau.
    private(set) var suraMeta: [Int: QuranSuraMeta] = [:]

    /// Idempotence : un seul build même si plusieurs vues demandent l'index.
    private var loadTask: Task<(QuranVerseIndex, [Int: QuranSuraMeta])?, Never>?

    /// Charge (ou retourne) l'index. Décodage + construction hors main thread.
    func loadIndex() async -> QuranVerseIndex? {
        if let index { return index }
        if let loadTask { return await loadTask.value?.0 }

        let task = Task<(QuranVerseIndex, [Int: QuranSuraMeta])?, Never>.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: "quran-search-corpus", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let corpus = try? JSONDecoder().decode(CorpusFile.self, from: data) else {
                print("⚠️ [QuranSearch] Corpus bundlé introuvable ou indécodable.")
                return nil
            }
            var verses: [(ref: QuranVerseRef, text: String)] = []
            verses.reserveCapacity(6_236)
            var meta: [Int: QuranSuraMeta] = [:]
            for sura in corpus.s {
                meta[sura.c] = QuranSuraMeta(arabicName: sura.n,
                                             englishName: sura.e,
                                             verseCount: sura.v.count)
                for verse in sura.v {
                    verses.append((QuranVerseRef(sura: sura.c, ayah: verse.i), verse.t))
                }
            }
            return (QuranVerseIndex(verses: verses), meta)
        }
        loadTask = task
        let built = await task.value
        if let built {
            index = built.0
            suraMeta = built.1
        }
        loadTask = nil
        return built?.0
    }

    /// Pré-chauffe l'index en arrière-plan (à appeler à l'ouverture de la
    /// bibliothèque, avant la première frappe).
    func prewarm() {
        Task { _ = await loadIndex() }
    }
}
