//
//  RecitationReferenceLoader.swift
//  Muslim Clock — Correcteur de récitation (phase 4 : socle)
//
//  Charge le texte de référence d'une riwaya depuis le bundle :
//  - Hafs   : quran-search-corpus.json (imla'i vocalisé, déjà utilisé par le Spotlight) ;
//  - Warsh  : quran-warsh.json   (KFGQPC, numérotation madani) ;
//  - Qaloun : quran-qaloun.json  (KFGQPC, numérotation madani).
//  Même schéma compact pour les trois. Décodage hors main thread, mis en
//  cache par riwaya. Licences : RECITATION_DATA_LICENSES.md.
//

import Foundation
import os

// MARK: - Erreurs

nonisolated enum RecitationReferenceError: LocalizedError, Equatable {
    case riwayaUnavailable(Riwaya)
    case surahNotFound(Int)
    case ayahRangeInvalid(ClosedRange<Int>, ayahCount: Int)
    case rangeTooLarge(count: Int, maximum: Int)

    var errorDescription: String? {
        switch self {
        case .riwayaUnavailable(let riwaya):
            String(localized: "Le texte de la riwaya \(riwaya.label) n'est pas disponible.")
        case .surahNotFound(let surah):
            String(localized: "Sourate \(surah) introuvable.")
        case .ayahRangeInvalid(let range, let count):
            String(localized: "Versets \(range.lowerBound)–\(range.upperBound) hors de la sourate (\(count) versets).")
        case .rangeTooLarge(let count, let maximum):
            String(localized: "\(count) versets demandés : \(maximum) au maximum par séance.")
        }
    }
}

// MARK: - Loader

enum RecitationReferenceLoader {

    /// Plafond d'une séance : borne l'alignement O(n·m) et reste pédagogique.
    static let maxAyahsPerSession = 20

    private nonisolated static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "RecitationReference")

    /// Corpus décodés (ou en cours de décodage), par riwaya.
    private static var corpusTasks: [Riwaya: Task<RiwayaCorpus?, Never>] = [:]

    // MARK: API

    /// Riwayat dont le texte est présent dans le bundle.
    static func availableRiwayat() -> [Riwaya] {
        Riwaya.allCases.filter {
            Bundle.main.url(forResource: $0.corpusResourceName, withExtension: "json") != nil
        }
    }

    static func ayahCount(surah: Int, riwaya: Riwaya) async -> Int? {
        await corpus(for: riwaya)?.surahs[surah]?.verses.count
    }

    static func surahNames(riwaya: Riwaya) async -> [(id: Int, nameArabic: String, nameLatin: String)] {
        guard let corpus = await corpus(for: riwaya) else { return [] }
        return corpus.surahs.keys.sorted().compactMap { id in
            corpus.surahs[id].map { (id, $0.nameArabic, $0.nameLatin) }
        }
    }

    /// Texte de référence d'une plage de versets (numérotation de la riwaya).
    ///
    /// - Throws: `RecitationReferenceError` — riwaya absente du bundle,
    ///   sourate inconnue, plage hors sourate ou plus de `maxAyahsPerSession` versets.
    static func load(riwaya: Riwaya, surah: Int, ayahRange: ClosedRange<Int>) async throws -> RecitationReference {
        guard ayahRange.count <= maxAyahsPerSession else {
            throw RecitationReferenceError.rangeTooLarge(count: ayahRange.count, maximum: maxAyahsPerSession)
        }
        guard let corpus = await corpus(for: riwaya) else {
            throw RecitationReferenceError.riwayaUnavailable(riwaya)
        }
        guard let entry = corpus.surahs[surah] else {
            throw RecitationReferenceError.surahNotFound(surah)
        }
        guard ayahRange.lowerBound >= 1, ayahRange.upperBound <= entry.verses.count else {
            throw RecitationReferenceError.ayahRangeInvalid(ayahRange, ayahCount: entry.verses.count)
        }
        var texts: [Int: String] = [:]
        for ayah in ayahRange { texts[ayah] = entry.verses[ayah - 1] }
        return makeReference(riwaya: riwaya, surah: surah, ayahTexts: texts)
    }

    /// Découpe des versets en `ReferenceWord` (les signes de pause isolés,
    /// sans lettre, ne sont pas des mots). Pur — utilisé aussi par les tests.
    nonisolated static func makeReference(riwaya: Riwaya, surah: Int, ayahTexts: [Int: String]) -> RecitationReference {
        let ayahs = ayahTexts.keys.sorted()
        var words: [ReferenceWord] = []
        for ayah in ayahs {
            guard let text = ayahTexts[ayah] else { continue }
            var index = 0
            for chunk in text.split(whereSeparator: \.isWhitespace) {
                let normalized = QuranSearchNormalizer.tokens(String(chunk)).joined()
                guard !normalized.isEmpty else { continue }
                words.append(ReferenceWord(ayah: ayah, index: index, display: String(chunk), normalized: normalized))
                index += 1
            }
        }
        let range = (ayahs.first ?? 1)...(ayahs.last ?? 1)
        return RecitationReference(riwaya: riwaya, surah: surah, ayahRange: range, words: words, ayahTexts: ayahTexts)
    }

    // MARK: Corpus

    private static func corpus(for riwaya: Riwaya) async -> RiwayaCorpus? {
        if let task = corpusTasks[riwaya] { return await task.value }
        let resource = riwaya.corpusResourceName
        let task = Task<RiwayaCorpus?, Never>.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else { return nil }
            do {
                let file = try JSONDecoder().decode(CorpusFile.self, from: Data(contentsOf: url))
                var surahs: [Int: RiwayaCorpus.Surah] = [:]
                for sura in file.s {
                    surahs[sura.c] = RiwayaCorpus.Surah(nameArabic: sura.n, nameLatin: sura.e,
                                                        verses: sura.v.sorted { $0.i < $1.i }.map(\.t))
                }
                return RiwayaCorpus(surahs: surahs)
            } catch {
                Self.logger.error("\(resource, privacy: .public).json indécodable : \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        corpusTasks[riwaya] = task
        let corpus = await task.value
        // Échec : on autorise une nouvelle tentative plutôt que de figer l'erreur.
        if corpus == nil { corpusTasks[riwaya] = nil }
        return corpus
    }
}

// MARK: - Schéma du corpus

private nonisolated struct RiwayaCorpus: Sendable {
    nonisolated struct Surah: Sendable {
        let nameArabic: String
        let nameLatin: String
        /// Texte de chaque verset ; index 0 = verset 1.
        let verses: [String]
    }
    let surahs: [Int: Surah]
}

private nonisolated struct CorpusFile: Decodable {
    let s: [CorpusSura]
}

private nonisolated struct CorpusSura: Decodable {
    let c: Int
    let n: String
    let e: String
    let v: [CorpusVerse]
}

private nonisolated struct CorpusVerse: Decodable {
    let i: Int
    let t: String
}
