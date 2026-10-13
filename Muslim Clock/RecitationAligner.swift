//
//  RecitationAligner.swift
//  Muslim Clock — Correcteur de récitation (phase 4 : socle)
//
//  Compare ce qui a été entendu au texte de référence, mot à mot. Là où
//  QuranVerseMatcher PARDONNE (il identifie un passage), l'aligneur JUGE :
//  chaque mot de référence est classé matched / approximate / omitted /
//  substituted, chaque mot entendu en trop inserted / repeated.
//
//  Pur, sans I/O (hors table d'équivalences bundlée par défaut), testé.
//

import Foundation

nonisolated enum RecitationAligner {

    /// Similarité à partir de laquelle un mot est considéré juste.
    static let matchThreshold = 0.75
    /// Similarité à partir de laquelle un mot est « proche » (approximate).
    static let approximateThreshold = 0.5
    /// Pause intra-verset au-delà de laquelle on signale une hésitation.
    static let hesitationThreshold: TimeInterval = 3

    /// Coût d'un trou (omission ou insertion). Une substitution coûte
    /// `1 − similarité` ≤ `gapCost` : deux mots en face l'un de l'autre sont
    /// toujours préférés à un couple omission + insertion.
    private static let gapCost = 1.0

    private static let taawwudhTokens = ["اعوذ", "بالله", "من", "الشيطان", "الرجيم"]

    // MARK: - API

    static func align(reference: RecitationReference, transcript: RecitationTranscript) -> RecitationAlignment {
        align(reference: reference, transcript: transcript, equivalences: .bundled)
    }

    /// Aligne la transcription sur la référence (Needleman-Wunsch, O(n·m)).
    ///
    /// - Le préambule (ta'awwudh puis basmala) est retiré de la transcription,
    ///   sauf si la référence commence elle-même par la basmala (Fatiha en Hafs)
    ///   ou s'il s'agit de la sourate 9 (où la réciter est une erreur à signaler).
    /// - Coût de substitution : `1 − similarité` (Dice sur trigrammes de caractères
    ///   des formes canoniques, cf. `RecitationEquivalences`).
    /// - Les hésitations ne sont détectées qu'avec des horodatages.
    static func align(reference: RecitationReference,
                      transcript: RecitationTranscript,
                      equivalences: RecitationEquivalences) -> RecitationAlignment {
        let refs = reference.words
        let heard = strippingPreamble(transcript.tokens, reference: reference)

        var trigramCache: [String: [UInt32]] = [:]
        func trigrams(_ word: String) -> [UInt32] {
            if let cached = trigramCache[word] { return cached }
            let computed = paddedTrigramHashes(word)
            trigramCache[word] = computed
            return computed
        }

        let refForms = refs.map { word in
            equivalences.referenceForms(display: word.display, normalized: word.normalized)
                .map { (form: $0, trigrams: trigrams($0)) }
        }
        let heardForms = heard.map { token -> (form: String, trigrams: [UInt32]) in
            let form = equivalences.canonical(token.normalized)
            return (form, trigrams(form))
        }

        func similarity(_ i: Int, _ j: Int) -> Double {
            let target = heardForms[j]
            var best = 0.0
            for candidate in refForms[i] {
                if candidate.form == target.form { return 1 }
                best = max(best, dice(candidate.trigrams, target.trigrams))
            }
            return best
        }

        let path = needlemanWunsch(rows: refs.count, columns: heard.count, similarity: similarity)

        // ── Classement ──
        var items: [AlignedWord] = []
        items.reserveCapacity(path.count)
        for step in path {
            let kind: AlignedWordKind
            switch (step.ref, step.heard) {
            case let (i?, j?):
                let score = similarity(i, j)
                kind = score >= matchThreshold ? .matched
                    : score >= approximateThreshold ? .approximate : .substituted
            case (_?, nil): kind = .omitted
            default: kind = .inserted
            }
            items.append(AlignedWord(id: items.count, kind: kind,
                                     reference: step.ref.map { refs[$0] },
                                     heard: step.heard.map { heard[$0] }))
        }
        items = markingRepetitions(items, path: path, similarity: similarity)

        let matched = items.filter { $0.kind == .matched }.count
        let approximate = items.filter { $0.kind == .approximate }.count
        let accuracy = refs.isEmpty ? 0 : (Double(matched) + 0.5 * Double(approximate)) / Double(refs.count)

        return RecitationAlignment(items: items,
                                   accuracy: accuracy,
                                   hesitations: hesitations(in: items),
                                   heardCount: heard.count)
    }

    /// Similarité de deux mots normalisés ∈ [0, 1] (1 ⇔ identiques).
    static func similarity(_ a: String, _ b: String) -> Double {
        a == b ? 1 : dice(paddedTrigramHashes(a), paddedTrigramHashes(b))
    }

    // MARK: - Préambule

    private static func strippingPreamble(_ tokens: [HeardToken], reference: RecitationReference) -> [HeardToken] {
        var result = tokens
        if hasPrefix(result, taawwudhTokens) {
            result.removeFirst(taawwudhTokens.count)
        }
        let basmala = QuranSearchNormalizer.basmalaTokens
        let referenceStartsWithBasmala = reference.words.prefix(basmala.count).map(\.normalized) == basmala
        if reference.surah != 9, !referenceStartsWithBasmala, hasPrefix(result, basmala) {
            result.removeFirst(basmala.count)
        }
        return result
    }

    private static func hasPrefix(_ tokens: [HeardToken], _ prefix: [String]) -> Bool {
        tokens.count >= prefix.count && zip(tokens, prefix).allSatisfy { $0.normalized == $1 }
    }

    // MARK: - Needleman-Wunsch

    private struct Step {
        let ref: Int?
        let heard: Int?
    }

    private enum Move: UInt8 { case diagonal, omit, insert }

    /// Chemin d'alignement de coût minimal, dans l'ordre de lecture.
    /// Égalités : diagonale > omission > insertion (rend la sortie déterministe
    /// et rattache un mot dupliqué à sa DERNIÈRE occurrence entendue).
    private static func needlemanWunsch(rows n: Int, columns m: Int,
                                        similarity: (Int, Int) -> Double) -> [Step] {
        let width = m + 1
        var cost = [Double](repeating: 0, count: (n + 1) * width)
        var moves = [Move](repeating: .diagonal, count: (n + 1) * width)
        for i in stride(from: 1, through: n, by: 1) {
            cost[i * width] = Double(i) * gapCost
            moves[i * width] = .omit
        }
        for j in stride(from: 1, through: m, by: 1) {
            cost[j] = Double(j) * gapCost
            moves[j] = .insert
        }
        for i in stride(from: 1, through: n, by: 1) {
            for j in stride(from: 1, through: m, by: 1) {
                let diagonal = cost[(i - 1) * width + j - 1] + (1 - similarity(i - 1, j - 1))
                let omit = cost[(i - 1) * width + j] + gapCost
                let insert = cost[i * width + j - 1] + gapCost
                let index = i * width + j
                if diagonal <= omit, diagonal <= insert {
                    cost[index] = diagonal; moves[index] = .diagonal
                } else if omit <= insert {
                    cost[index] = omit; moves[index] = .omit
                } else {
                    cost[index] = insert; moves[index] = .insert
                }
            }
        }

        var steps: [Step] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            switch moves[i * width + j] {
            case .diagonal:
                i -= 1; j -= 1
                steps.append(Step(ref: i, heard: j))
            case .omit:
                i -= 1
                steps.append(Step(ref: i, heard: nil))
            case .insert:
                j -= 1
                steps.append(Step(ref: nil, heard: j))
            }
        }
        return steps.reversed()
    }

    // MARK: - Répétitions

    /// Requalifie en `repeated` les mots en trop qui redisent le texte voisin.
    ///
    /// Une suite de L mots insérés est comparée, position par position, aux L
    /// mots prononcés juste après (reprise : « لم يلد لم يلد ») et juste avant
    /// (bégaiement en fin de groupe). Comparer par position — et non « à un mot
    /// quelconque du voisinage » — évite qu'une basmala récitée avant at-Tawba
    /// passe pour une répétition parce que « الله » apparaît plus loin.
    private static func markingRepetitions(_ items: [AlignedWord], path: [Step],
                                           similarity: (Int, Int) -> Double) -> [AlignedWord] {
        // Positions (dans `items`) des mots de référence effectivement prononcés.
        let spoken = items.indices.filter { items[$0].reference != nil && items[$0].heard != nil }
        var result = items
        var start = 0
        while start < items.count {
            guard items[start].kind == .inserted else { start += 1; continue }
            var end = start
            while end + 1 < items.count, items[end + 1].kind == .inserted { end += 1 }
            let length = end - start + 1
            let after = Array(spoken.filter { $0 > end }.prefix(length))
            let before = Array(spoken.filter { $0 < start }.suffix(length))
            for offset in 0..<length {
                guard let heardIndex = path[start + offset].heard else { continue }
                let candidates = [after.indices.contains(offset) ? after[offset] : nil,
                                  before.count == length ? before[offset] : nil]
                let isRepetition = candidates.compactMap { $0 }.contains { position in
                    guard let refIndex = path[position].ref else { return false }
                    return similarity(refIndex, heardIndex) >= matchThreshold
                }
                if isRepetition {
                    let item = items[start + offset]
                    result[start + offset] = AlignedWord(id: item.id, kind: .repeated, reference: nil, heard: item.heard)
                }
            }
            start = end + 1
        }
        return result
    }

    // MARK: - Hésitations

    /// Pauses > `hesitationThreshold` entre deux mots entendus consécutifs,
    /// quand le mot attendu après la pause est dans le même verset que le
    /// dernier mot prononcé (une pause en fin de verset est un waqf, pas une faute).
    private static func hesitations(in items: [AlignedWord]) -> [Hesitation] {
        var result: [Hesitation] = []
        var lastEnd: TimeInterval?
        var lastSpoken: ReferenceWord?
        for (position, item) in items.enumerated() {
            guard let heard = item.heard else { continue }
            if let start = heard.timeRange?.lowerBound, let end = lastEnd, let previous = lastSpoken,
               start - end > hesitationThreshold,
               let next = items[position...].lazy.compactMap(\.reference).first,
               next.ayah == previous.ayah {
                result.append(Hesitation(ayah: previous.ayah, afterWordIndex: previous.index, gap: start - end))
            }
            lastEnd = heard.timeRange?.upperBound
            if let reference = item.reference { lastSpoken = reference }
        }
        return result
    }

    // MARK: - Trigrammes

    /// Hashes FNV-1a 32 bits (même schéma que `QuranVerseIndex`) des trigrammes
    /// de « ␠mot␠ », triés et dédoublonnés : le remplissage par des espaces
    /// donne des trigrammes même aux mots d'une ou deux lettres (ق, من…).
    private static func paddedTrigramHashes(_ word: String) -> [UInt32] {
        let scalars = Array(" \(word) ".unicodeScalars)
        guard scalars.count >= 3 else { return [] }
        var hashes = Set<UInt32>()
        for i in 0...(scalars.count - 3) {
            var hash: UInt32 = 2_166_136_261
            for j in i..<(i + 3) {
                hash = (hash ^ scalars[j].value) &* 16_777_619
            }
            hashes.insert(hash)
        }
        return hashes.sorted()
    }

    /// Coefficient de Dice de deux ensembles triés : 2|A∩B| / (|A|+|B|).
    private static func dice(_ a: [UInt32], _ b: [UInt32]) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 0 }
        var i = 0, j = 0, common = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] { common += 1; i += 1; j += 1 }
            else if a[i] < b[j] { i += 1 }
            else { j += 1 }
        }
        return 2 * Double(common) / Double(a.count + b.count)
    }
}
