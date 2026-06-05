//
//  QuranLibraryLoader.swift
//  Muslim Clock — module Quran Library
//
//  Loader du Coran complet via CDN jsDelivr (`risan/quran-json@3.1.2`).
//
//  Stratégie cache 2 niveaux :
//    1. Cache mémoire `NSCache` — instances déjà décodées, accès O(1) sans I/O.
//    2. Cache disque `.cachesDirectory/quran/` — Coran immutable, purgeable par iOS.
//
//  Stratégie réseau : skip si fichier en cache disque (Coran immutable).
//  Décodage en background pour ne pas bloquer le main thread.
//

import Foundation
import Combine
import os

@MainActor
final class QuranLibraryLoader: ObservableObject {

    static let shared = QuranLibraryLoader()

    private let log = Logger(subsystem: "kappsi.Muslim-Clock", category: "QuranLibrary")

    /// Cache mémoire des sourates décodées. NSCache gère l'éviction automatique
    /// si la pression mémoire est forte.
    private let chapterMemoryCache: NSCache<NSNumber, CachedChapter> = {
        let cache = NSCache<NSNumber, CachedChapter>()
        cache.countLimit = 30 // 30 sourates max en mémoire (≈ 1.5 MB peak)
        return cache
    }()

    /// Index racine mémorisé une fois chargé.
    private var indexCache: [QuranChapterIndex]?

    /// Tâches de chargement en cours par sourate — évite les fetches concurrents
    /// pour la même sourate.
    private var inflightTasks: [Int: Task<QuranChapter?, Never>] = [:]

    private init() {}

    // MARK: - API publique

    /// Charge l'index des 114 sourates (méta seulement, ~23 KB).
    func loadIndex() async -> [QuranChapterIndex]? {
        if let cached = indexCache { return cached }

        let result = await fetchIndex()
        if let result {
            indexCache = result
        }
        return result
    }

    /// Charge une sourate complète. Hit cache mémoire si possible, sinon cache disque,
    /// sinon réseau. Idempotent — appels concurrents pour la même sourate ne déclenchent
    /// qu'un seul fetch.
    func loadChapter(_ chapterId: Int) async -> QuranChapter? {
        guard (1...QuranConstants.totalChapters).contains(chapterId) else {
            log.error("loadChapter: id hors plage \(chapterId)")
            return nil
        }

        // Hit mémoire
        if let cached = chapterMemoryCache.object(forKey: NSNumber(value: chapterId)) {
            return cached.chapter
        }

        // Tâche déjà en cours pour cette sourate ?
        if let existing = inflightTasks[chapterId] {
            return await existing.value
        }

        let task = Task<QuranChapter?, Never> { [weak self] in
            await self?.fetchChapter(chapterId)
        }
        inflightTasks[chapterId] = task

        let result = await task.value
        inflightTasks[chapterId] = nil

        if let result {
            chapterMemoryCache.setObject(CachedChapter(chapter: result), forKey: NSNumber(value: chapterId))
        }
        return result
    }

    /// Pré-charge les N premières sourates en arrière-plan (warm-up).
    /// À appeler après l'apparition de `QuranLibraryView` pour fluidifier le scrolling.
    func prefetch(chapterIds: [Int]) {
        for id in chapterIds {
            Task { _ = await loadChapter(id) }
        }
    }

    // MARK: - Privé : fetch + décodage

    /// Fetch et décode l'index. Décodage en background via `Task.detached` pour ne pas
    /// bloquer le main thread (23 KB c'est petit mais on garde la discipline).
    private func fetchIndex() async -> [QuranChapterIndex]? {
        let result = await RemoteJSONLoader.load(
            filename: "quran-index-fr.json",
            remoteURL: "https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/chapters/fr/index.json",
            type: [QuranChapterIndex].self,
            timeout: 8.0
        )
        if let result {
            log.info("Index chargé : \(result.count) sourates")
        } else {
            log.error("Index : échec total (réseau + cache + bundle)")
        }
        return result
    }

    /// Fetch et décode une sourate. Cache disque géré par `RemoteJSONLoader` au niveau Documents.
    /// Le Coran étant immutable, après un premier fetch réussi le cache ne sera plus revalidé.
    private func fetchChapter(_ id: Int) async -> QuranChapter? {
        let result = await RemoteJSONLoader.load(
            filename: "quran-chapter-\(id)-fr.json",
            remoteURL: "https://cdn.jsdelivr.net/npm/quran-json@3.1.2/dist/chapters/fr/\(id).json",
            type: QuranChapter.self,
            timeout: 15.0
        )
        if result == nil {
            log.error("Sourate \(id) : échec total")
        }
        return result
    }
}

// MARK: - Wrapper NSCache

/// `NSCache` exige un type classe — on wrap la struct `QuranChapter`.
private final class CachedChapter {
    let chapter: QuranChapter
    init(chapter: QuranChapter) { self.chapter = chapter }
}
