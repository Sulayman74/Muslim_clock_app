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

    /// Surcoût d'une fusion/scission (la dictée colle « يا أيها » en « ياأيها »
    /// ou coupe « ولم » en « و لم »). Ces mouvements ne sont admis que si la
    /// concaténation est clairement le même mot (≥ `matchThreshold`) : on ne
    /// masque jamais une vraie erreur derrière un recollage hasardeux.
    private static let fusionPenalty = 0.15

    /// Score accordé quand seuls les squelettes consonantiques coïncident
    /// (فاتقوا entendu فتق : le moteur avale les voyelles longues du tartil).
    /// Dans la bande « approximatif » — jamais « juste » : une vraie différence
    /// de voyelle longue (قاتلوا/قتلوا) reste signalée, en jaune.
    private static let consonantSkeletonScore = 0.6
    /// Longueur minimale (scalaires normalisés) du mot de référence pour la
    /// deuxième chance au squelette — évite de rapprocher قل/قال.
    private static let skeletonMinimumLength = 5

    /// Troncature : le moteur avale un préfixe ou un suffixe (يحق → حق,
    /// أنها → أن). Le mot entendu est un morceau CONTIGU du mot attendu qui en
    /// couvre au moins la moitié → approximatif, pas « autre mot ». Jamais dans
    /// l'autre sens (un mot entendu plus long que l'attendu reste jugé).
    private static let truncationScore = 0.6
    private static let truncationMinimumCoverage = 0.5
    private static let truncationMinimumReferenceLength = 3

    private static let taawwudhTokens = ["اعوذ", "بالله", "من", "الشيطان", "الرجيم"]

    // MARK: - API

    static func align(reference: RecitationReference, transcript: RecitationTranscript) -> RecitationAlignment {
        align(reference: reference, transcript: transcript, equivalences: .bundled)
    }

    /// Alignement calibré par le récitateur : les formes que le moteur produit
    /// sur la récitation parfaite sont acceptées comme justes à leur position,
    /// puis les mots qu'il rate complètement deviennent non vérifiables.
    static func align(reference: RecitationReference,
                      transcript: RecitationTranscript,
                      calibration: RecitationCalibration) -> RecitationAlignment {
        align(reference: reference, transcript: transcript, equivalences: .bundled,
              reciterForms: calibration.reciterForms)
            .applying(calibration)
    }

    /// Aligne la transcription sur la référence (Needleman-Wunsch, O(n·m)).
    ///
    /// - Le préambule (ta'awwudh puis basmala) est retiré de la transcription,
    ///   sauf si la référence commence elle-même par la basmala (Fatiha en Hafs)
    ///   ou s'il s'agit de la sourate 9 (où la réciter est une erreur à signaler).
    /// - Coût de substitution : `1 − similarité` (Dice sur trigrammes de caractères
    ///   des formes canoniques, cf. `RecitationEquivalences`).
    /// - `reciterForms` : graphies supplémentaires acceptées comme justes, par
    ///   position (ce que le moteur rend du récitateur pour ce mot précis).
    /// - Les hésitations ne sont détectées qu'avec des horodatages.
    static func align(reference: RecitationReference,
                      transcript: RecitationTranscript,
                      equivalences: RecitationEquivalences,
                      reciterForms: [AyahWordKey: String] = [:]) -> RecitationAlignment {
        let refs = reference.words
        let heard = strippingPreamble(transcript.tokens, reference: reference)

        var trigramCache: [String: [UInt32]] = [:]
        func trigrams(_ word: String) -> [UInt32] {
            if let cached = trigramCache[word] { return cached }
            let computed = paddedTrigramHashes(word)
            trigramCache[word] = computed
            return computed
        }

        let refForms = refs.map { word -> [(form: String, trigrams: [UInt32])] in
            var forms = equivalences.referenceForms(display: word.display, normalized: word.normalized)
            // Forme produite par le moteur sur le récitateur, à cette position :
            // la reproduire, c'est réciter comme lui.
            if let reciterForm = reciterForms[AyahWordKey(ayah: word.ayah, index: word.index)],
               !reciterForm.isEmpty, !forms.contains(reciterForm) {
                forms.append(reciterForm)
            }
            return forms.map { (form: $0, trigrams: trigrams($0)) }
        }
        let heardForms = heard.map { equivalences.canonical($0.normalized) }

        /// Similarité d'un mot de référence avec une forme entendue (meilleure
        /// des graphies acceptables de la référence). Deuxième chance : si les
        /// squelettes consonantiques coïncident (voyelles longues avalées par
        /// le moteur), le score est relevé dans la bande « approximatif ».
        func similarity(_ i: Int, form: String) -> Double {
            let target = trigrams(form)
            var best = 0.0
            for candidate in refForms[i] {
                if candidate.form == form { return 1 }
                best = max(best, dice(candidate.trigrams, target))
            }
            if best < matchThreshold {
                let heardSkeleton = consonantSkeleton(form)
                for candidate in refForms[i]
                where candidate.form.unicodeScalars.count >= skeletonMinimumLength
                    && !heardSkeleton.isEmpty
                    && consonantSkeleton(candidate.form) == heardSkeleton {
                    best = max(best, consonantSkeletonScore)
                    break
                }
            }
            if best < matchThreshold, isTruncation(of: refForms[i].map(\.form), heard: form) {
                best = max(best, truncationScore)
            }
            return best
        }
        func similarity(_ i: Int, _ j: Int) -> Double { similarity(i, form: heardForms[j]) }

        /// Fusion : refs[i] + refs[i+1] prononcés comme heard[j] (graphie canonique de chacun).
        func mergeSimilarity(_ i: Int, _ j: Int) -> Double {
            let glued = refForms[i][0].form + refForms[i + 1][0].form
            return glued == heardForms[j] ? 1 : dice(trigrams(glued), trigrams(heardForms[j]))
        }
        /// Scission : refs[i] entendu en deux morceaux heard[j] + heard[j+1].
        func splitSimilarity(_ i: Int, _ j: Int) -> Double {
            similarity(i, form: equivalences.canonical(heard[j].normalized + heard[j + 1].normalized))
        }

        let path = needlemanWunsch(
            rows: refs.count, heard: heard, heardForms: heardForms,
            similarity: similarity, mergeSimilarity: mergeSimilarity, splitSimilarity: splitSimilarity
        )

        // ── Classement ──
        var items: [AlignedWord] = []
        items.reserveCapacity(path.count)
        for step in path {
            let kind: AlignedWordKind
            switch (step.ref, step.heard) {
            case (_?, _?):
                let score = step.score ?? 0
                kind = score >= matchThreshold ? .matched
                    : score >= approximateThreshold ? .approximate : .substituted
            case (_?, nil): kind = .omitted
            default: kind = .inserted
            }
            items.append(AlignedWord(id: items.count, kind: kind,
                                     reference: step.ref.map { refs[$0] },
                                     heard: step.heard))
        }
        items = markingRepetitions(items, path: path) { refIndex, form in similarity(refIndex, form: form) }

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

    /// Une case du chemin : mot de référence et/ou mot entendu, avec la
    /// similarité retenue. Une scission produit un mot entendu **synthétique**
    /// (les deux morceaux recollés, plage temporelle réunie) ; une fusion
    /// rattache le même mot entendu à deux mots de référence consécutifs.
    private struct Step {
        let ref: Int?
        let heard: HeardToken?
        /// Forme canonique du mot entendu (pour la détection des répétitions).
        let heardForm: String?
        let score: Double?
    }

    private enum Move: UInt8 { case diagonal, omit, insert, merge, split }

    /// Chemin d'alignement de coût minimal, dans l'ordre de lecture.
    /// Égalités : diagonale > omission > insertion > fusion > scission (sortie
    /// déterministe ; un mot dupliqué est rattaché à sa DERNIÈRE occurrence).
    private static func needlemanWunsch(
        rows n: Int, heard: [HeardToken], heardForms: [String],
        similarity: (Int, Int) -> Double,
        mergeSimilarity: (Int, Int) -> Double,
        splitSimilarity: (Int, Int) -> Double
    ) -> [Step] {
        let m = heard.count
        let width = m + 1
        var cost = [Double](repeating: 0, count: (n + 1) * width)
        var moves = [Move](repeating: .diagonal, count: (n + 1) * width)
        var scores = [Double](repeating: 0, count: (n + 1) * width)
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
                let index = i * width + j
                let diagonalScore = similarity(i - 1, j - 1)
                var best = cost[(i - 1) * width + j - 1] + (1 - diagonalScore)
                var move = Move.diagonal
                var score = diagonalScore

                let omit = cost[(i - 1) * width + j] + gapCost
                if omit < best { best = omit; move = .omit }
                let insert = cost[i * width + j - 1] + gapCost
                if insert < best { best = insert; move = .insert }

                // Fusion/scission : seulement si le recollage est clairement le même mot.
                if i >= 2 {
                    let s = mergeSimilarity(i - 2, j - 1)
                    if s >= matchThreshold {
                        let merge = cost[(i - 2) * width + j - 1] + (1 - s) + fusionPenalty
                        if merge < best { best = merge; move = .merge; score = s }
                    }
                }
                if j >= 2 {
                    let s = splitSimilarity(i - 1, j - 2)
                    if s >= matchThreshold {
                        let split = cost[(i - 1) * width + j - 2] + (1 - s) + fusionPenalty
                        if split < best { best = split; move = .split; score = s }
                    }
                }
                cost[index] = best
                moves[index] = move
                scores[index] = score
            }
        }

        return backtrace(moves: moves, scores: scores, width: width, rows: n, heard: heard, heardForms: heardForms)
    }

    /// Reconstruit le chemin à partir de la matrice des mouvements : `Step`
    /// produits à rebours puis inversés.
    private static func backtrace(moves: [Move], scores: [Double], width: Int, rows n: Int,
                                  heard: [HeardToken], heardForms: [String]) -> [Step] {
        func heardToken(_ j: Int) -> HeardToken { heard[j] }
        func heardForm(_ j: Int) -> String { heardForms[j] }
        var steps: [Step] = []
        var i = n, j = heard.count
        while i > 0 || j > 0 {
            let index = i * width + j
            switch moves[index] {
            case .diagonal:
                i -= 1; j -= 1
                steps.append(Step(ref: i, heard: heardToken(j), heardForm: heardForm(j), score: scores[index]))
            case .omit:
                i -= 1
                steps.append(Step(ref: i, heard: nil, heardForm: nil, score: nil))
            case .insert:
                j -= 1
                steps.append(Step(ref: nil, heard: heardToken(j), heardForm: heardForm(j), score: nil))
            case .merge:
                i -= 2; j -= 1
                // Ordre de lecture après inversion : (i, j) puis (i+1, j).
                steps.append(Step(ref: i + 1, heard: heardToken(j), heardForm: heardForm(j), score: scores[index]))
                steps.append(Step(ref: i, heard: heardToken(j), heardForm: heardForm(j), score: scores[index]))
            case .split:
                i -= 1; j -= 2
                let first = heardToken(j), second = heardToken(j + 1)
                let range: ClosedRange<TimeInterval>? = {
                    guard let a = first.timeRange, let b = second.timeRange else { return first.timeRange ?? second.timeRange }
                    return min(a.lowerBound, b.lowerBound)...max(a.upperBound, b.upperBound)
                }()
                let glued = HeardToken(text: first.text + " " + second.text,
                                       normalized: first.normalized + second.normalized,
                                       timeRange: range,
                                       confidence: nil)
                steps.append(Step(ref: i, heard: glued, heardForm: heardForm(j) + heardForm(j + 1), score: scores[index]))
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
                                           similarity: (Int, String) -> Double) -> [AlignedWord] {
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
                guard let form = path[start + offset].heardForm else { continue }
                let candidates = [after.indices.contains(offset) ? after[offset] : nil,
                                  before.count == length ? before[offset] : nil]
                let isRepetition = candidates.compactMap { $0 }.contains { position in
                    guard let refIndex = path[position].ref else { return false }
                    return similarity(refIndex, form) >= matchThreshold
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

    // MARK: - Troncature

    /// `heard` est un morceau contigu d'une des formes de référence, couvrant
    /// au moins `truncationMinimumCoverage` de ses lettres.
    static func isTruncation(of referenceForms: [String], heard: String) -> Bool {
        let heardCount = heard.unicodeScalars.count
        guard heardCount >= 2 else { return false }
        return referenceForms.contains { reference in
            let referenceCount = reference.unicodeScalars.count
            return referenceCount >= truncationMinimumReferenceLength
                && heardCount < referenceCount
                && Double(heardCount) / Double(referenceCount) >= truncationMinimumCoverage
                && reference.contains(heard)
        }
    }

    // MARK: - Squelette consonantique

    /// Mot sans ses voyelles longues (ا, و, ي hors première lettre) : ce que
    /// le moteur de dictée restitue d'un mot psalmodié avec des madd tenus.
    static func consonantSkeleton(_ word: String) -> String {
        var result = String.UnicodeScalarView()
        for (index, scalar) in word.unicodeScalars.enumerated() {
            if index > 0, scalar == "\u{0627}" || scalar == "\u{0648}" || scalar == "\u{064A}" {
                continue
            }
            result.append(scalar)
        }
        return String(result)
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
