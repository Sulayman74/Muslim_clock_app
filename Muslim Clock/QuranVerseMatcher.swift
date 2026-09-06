//
//  QuranVerseMatcher.swift
//  Muslim Clock — Spotlight du Coran (Phase 1)
//
//  Moteur de recherche pur sur les 6 236 versets, en deux étages :
//  1. index inversé mot→versets pondéré IDF (génération de candidats, <5 ms) ;
//  2. re-scoring des candidats par CONTAINMENT de trigrammes de caractères —
//     tolérant aux fautes de frappe et aux erreurs de reconnaissance vocale.
//
//  Containment (|trigrammes(requête) ∩ trigrammes(verset)| / |trigrammes(requête)|)
//  et non Jaccard : l'utilisateur cherche un FRAGMENT — un verset long ne doit
//  pas être pénalisé parce qu'il contient plus que la requête.
//
//  Les versets au texte normalisé identique (refrain d'Ar-Rahman ×31…) sont
//  groupés : un seul résultat portant TOUTES ses occurrences.
//
//  Aucune I/O : l'index se construit à partir de données passées en paramètre
//  (testable avec une fixture) — le chargement vit dans QuranSearchCorpusLoader.
//

import Foundation

// MARK: - Modèles

/// Référence d'un verset dans le Mushaf.
nonisolated struct QuranVerseRef: Hashable, Comparable, Sendable {
    let sura: Int
    let ayah: Int

    static func < (lhs: QuranVerseRef, rhs: QuranVerseRef) -> Bool {
        (lhs.sura, lhs.ayah) < (rhs.sura, rhs.ayah)
    }
}

/// Un résultat de recherche : le verset représentant + toutes ses occurrences.
nonisolated struct QuranVerseMatch: Identifiable, Equatable, Sendable {
    /// Première occurrence dans l'ordre du Mushaf (celle ouverte au tap).
    let ref: QuranVerseRef
    /// Texte imla'i vocalisé, pour l'extrait affiché dans les résultats.
    let displayText: String
    /// Containment de trigrammes ∈ [0, 1].
    let score: Double
    /// Nombre de mots de la requête présents tels quels dans le verset.
    let matchedWordCount: Int
    /// Toutes les occurrences du même texte, triées (contient `ref`).
    let occurrences: [QuranVerseRef]

    var id: String { "\(ref.sura):\(ref.ayah)" }
}

// MARK: - Index

nonisolated struct QuranVerseIndex: Sendable {

    /// En-dessous de ce nombre de mots normalisés, la recherche ne répond pas
    /// (fragments indiscriminables — le Coran est massivement répétitif).
    static let minimumQueryTokens = 3

    /// Score plancher pour qu'un candidat apparaisse dans les résultats.
    static let minimumScore = 0.30

    private struct UniqueVerse {
        let rep: QuranVerseRef
        let occurrences: [QuranVerseRef]
        let displayText: String
        let tokenSet: Set<String>
        /// Hashes FNV-1a des trigrammes de caractères, triés (recherche binaire).
        let trigrams: [UInt32]

        /// Recherche binaire dans le tableau trié — évite un Set par verset
        /// (l'index complet tient en ~3 Mo au lieu de ~20).
        func containsTrigram(_ value: UInt32) -> Bool {
            var low = 0, high = trigrams.count - 1
            while low <= high {
                let mid = (low + high) / 2
                if trigrams[mid] == value { return true }
                if trigrams[mid] < value { low = mid + 1 } else { high = mid - 1 }
            }
            return false
        }
    }

    private let verses: [UniqueVerse]
    /// mot normalisé → indices dans `verses`.
    private let postings: [String: [Int32]]
    private let totalUniqueVerses: Int

    // MARK: Construction

    /// Construit l'index. ~6 236 versets en < 200 ms — à appeler hors main thread.
    init(verses input: [(ref: QuranVerseRef, text: String)]) {
        // Groupage des textes identiques (après normalisation).
        var byText: [String: (display: String, refs: [QuranVerseRef])] = [:]
        var order: [String] = []
        for (ref, text) in input {
            let key = QuranSearchNormalizer.normalize(text)
            guard !key.isEmpty else { continue }
            if byText[key] == nil {
                byText[key] = (text, [ref])
                order.append(key)
            } else {
                byText[key]?.refs.append(ref)
            }
        }

        var built: [UniqueVerse] = []
        built.reserveCapacity(order.count)
        var postings: [String: [Int32]] = [:]

        for key in order {
            let entry = byText[key]! // clé issue de `order` — présente par construction
            let refs = entry.refs.sorted()
            let tokens = key.split(separator: " ").map(String.init)
            let index = Int32(built.count)
            for word in Set(tokens) {
                postings[word, default: []].append(index)
            }
            built.append(UniqueVerse(
                rep: refs[0],
                occurrences: refs,
                displayText: entry.display,
                tokenSet: Set(tokens),
                trigrams: Self.trigramHashes(of: key).sorted()
            ))
        }

        self.verses = built
        self.postings = postings
        self.totalUniqueVerses = built.count
    }

    // MARK: Recherche

    /// Recherche les meilleurs versets pour la requête (texte libre arabe).
    /// Retourne au plus `limit` résultats, score décroissant, filtrés au plancher.
    func match(query: String, limit: Int = 5) -> [QuranVerseMatch] {
        let rawTokens = QuranSearchNormalizer.tokens(query)

        // Basmala seule → Fatiha 1:1 (elle Y EST un verset).
        if rawTokens == QuranSearchNormalizer.basmalaTokens {
            if let i = verses.firstIndex(where: { $0.rep == QuranVerseRef(sura: 1, ayah: 1) }) {
                let v = verses[i]
                return [QuranVerseMatch(ref: v.rep, displayText: v.displayText,
                                        score: 1.0, matchedWordCount: rawTokens.count,
                                        occurrences: v.occurrences)]
            }
        }

        // Basmala préfixée retirée — sauf si ça rend la requête trop courte
        // (« بسم الله الرحمن الرحيم الحمد » doit rester cherchable).
        let stripped = QuranSearchNormalizer.strippingLeadingBasmala(rawTokens)
        let tokens = stripped.count >= Self.minimumQueryTokens ? stripped : rawTokens
        guard tokens.count >= Self.minimumQueryTokens else { return [] }

        // ── Étage 1 : candidats par accumulation IDF ──
        var accumulator: [Int32: Double] = [:]
        for word in Set(tokens) {
            guard let list = postings[word] else { continue }
            let idf = log(Double(totalUniqueVerses) / Double(list.count))
            for verseIndex in list {
                accumulator[verseIndex, default: 0] += idf
            }
        }

        let candidateIndices: [Int32]
        if accumulator.isEmpty {
            // Aucun mot exact (tout est mal orthographié) → scan complet aux
            // trigrammes. ~6 200 intersections de sets : < 50 ms, cas rare.
            candidateIndices = Array(Int32(0)..<Int32(totalUniqueVerses))
        } else {
            candidateIndices = accumulator.sorted { $0.value > $1.value }
                .prefix(50).map(\.key)
        }

        // ── Étage 2 : containment de trigrammes ──
        let queryKey = tokens.joined(separator: " ")
        let queryTrigrams = Set(Self.trigramHashes(of: queryKey))
        guard !queryTrigrams.isEmpty else { return [] }

        var results: [QuranVerseMatch] = []
        for i in candidateIndices {
            let verse = verses[Int(i)]
            var hit = 0
            for t in queryTrigrams where verse.containsTrigram(t) { hit += 1 }
            let score = Double(hit) / Double(queryTrigrams.count)
            guard score >= Self.minimumScore else { continue }
            let matchedWords = tokens.filter { verse.tokenSet.contains($0) }.count
            results.append(QuranVerseMatch(
                ref: verse.rep,
                displayText: verse.displayText,
                score: score,
                matchedWordCount: matchedWords,
                occurrences: verse.occurrences
            ))
        }

        // Ex æquo (une phrase présente dans plusieurs versets, ex. « الحمد لله
        // رب العالمين » ×6) : ordre du Mushaf — la Fatiha avant Az-Zumar.
        return results
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.matchedWordCount != $1.matchedWordCount { return $0.matchedWordCount > $1.matchedWordCount }
                return $0.ref < $1.ref
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Décision « résultat sûr » (sélection automatique côté voix, mise en avant
    /// côté UI) : score fort, assez de mots, et écart net avec le n°2.
    static func isConfident(_ matches: [QuranVerseMatch]) -> Bool {
        guard let first = matches.first,
              first.score >= 0.55,
              first.matchedWordCount >= 3 else { return false }
        guard matches.count > 1 else { return true }
        return first.score - matches[1].score >= 0.15
    }

    // MARK: Trigrammes

    /// Hashes FNV-1a 32 bits des trigrammes de caractères de `text` (espaces
    /// simples inclus — capture les frontières de mots). Collisions tolérées :
    /// on score, on ne prouve pas.
    private static func trigramHashes(of text: String) -> [UInt32] {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count >= 3 else { return [] }
        var hashes: [UInt32] = []
        hashes.reserveCapacity(scalars.count - 2)
        for i in 0...(scalars.count - 3) {
            var hash: UInt32 = 2_166_136_261
            for j in i..<(i + 3) {
                hash = (hash ^ scalars[j].value) &* 16_777_619
            }
            hashes.append(hash)
        }
        return hashes
    }
}

