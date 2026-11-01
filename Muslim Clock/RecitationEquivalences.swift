//
//  RecitationEquivalences.swift
//  Muslim Clock — Correcteur de récitation (phase 4 : socle)
//
//  Rend comparables le texte de référence et la dictée quand ils ne diffèrent
//  que par la GRAPHIE, jamais par la lecture :
//  - table `riwaya_equivalences.json` (rasm uthmani Warsh/Qaloun ↔ imla'i) ;
//  - formes alternatives des alef suscrits (ٰ) : الصلوٰة → الصلاة, ءايٰت → ءايات.
//

import Foundation
import os

nonisolated struct RecitationEquivalences: Sendable {

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "RecitationEquivalences")

    /// Proclitiques détachés avant consultation de la table : un seul retiré,
    /// du plus long au plus court (والليل → و + الليل).
    private static let proclitics = ["وال", "فال", "بال", "كال", "ال", "و", "ف", "ب", "ل", "ك"]

    /// variante → canonique.
    private let canonicalByVariant: [String: String]

    init(pairs: [(variant: String, canonical: String)]) {
        var table: [String: String] = [:]
        for pair in pairs { table[pair.variant] = pair.canonical }
        canonicalByVariant = table
    }

    static let empty = RecitationEquivalences(pairs: [])

    /// Table bundlée, chargée une fois (fichier de quelques Ko). Vide si
    /// absente ou illisible : le correcteur reste utilisable, juste plus strict.
    static let bundled: RecitationEquivalences = {
        guard let url = Bundle.main.url(forResource: "riwaya_equivalences", withExtension: "json") else {
            logger.error("riwaya_equivalences.json absent du bundle")
            return .empty
        }
        do {
            let file = try JSONDecoder().decode(EquivalenceFile.self, from: Data(contentsOf: url))
            return RecitationEquivalences(pairs: file.pairs.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            })
        } catch {
            logger.error("riwaya_equivalences.json illisible : \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }()

    /// Forme canonique d'un mot normalisé (proclitique éventuel conservé).
    func canonical(_ token: String) -> String {
        if let canonical = canonicalByVariant[token] { return canonical }
        for prefix in Self.proclitics where token.hasPrefix(prefix) && token.count > prefix.count {
            let stem = String(token.dropFirst(prefix.count))
            if let canonical = canonicalByVariant[stem] { return prefix + canonical }
        }
        return token
    }

    /// Formes canoniques acceptables pour un mot de référence.
    ///
    /// Deux familles de variantes de GRAPHIE (jamais de lecture) :
    /// 1. Alef suscrit (U+0670) — se lit « a » mais s'écrit selon trois
    ///    logiques que la dictée (imla'i) rend différemment :
    ///    ignoré (عَلَىٰ → على), alef ajouté (ءَايَٰت → ايات), alef remplaçant
    ///    son support و/ي/ى (الصلوٰة → الصلاه).
    /// 2. Siège de hamza médiane/finale (ؤ ئ أ إ) — la dictée choisit le
    ///    support d'après la voyelle brève qu'elle croit entendre, que le
    ///    correcteur ne juge pas : وَيُؤْتُونَ est souvent transcrit ويأتون.
    ///    Chaque siège accepte donc ا/و/ي. La hamza INITIALE est exclue
    ///    (أ/إ → ا est déjà l'unification du normaliseur).
    /// L'aligneur retient la forme la plus proche de ce qui est entendu.
    func referenceForms(display: String, normalized: String) -> [String] {
        var forms = [canonical(normalized)]
        appendSuperscriptAlefForms(display: display, to: &forms)
        appendHamzaSeatForms(display: display, to: &forms)
        return forms
    }

    private func appendSuperscriptAlefForms(display: String, to forms: inout [String]) {
        guard display.unicodeScalars.contains(Self.superscriptAlef) else { return }

        var inserted = String.UnicodeScalarView()
        var replaced: [Unicode.Scalar] = []
        for scalar in display.unicodeScalars {
            guard scalar == Self.superscriptAlef else {
                inserted.append(scalar)
                replaced.append(scalar)
                continue
            }
            inserted.append(Self.alef)
            if let carrier = replaced.lastIndex(where: Self.isBaseLetter),
               Self.alefCarriers.contains(replaced[carrier]) {
                replaced[carrier] = Self.alef
            } else {
                replaced.append(Self.alef)
            }
        }
        var replacedView = String.UnicodeScalarView()
        replacedView.append(contentsOf: replaced)
        for variant in [String(inserted), String(replacedView)] {
            append(variant: variant, to: &forms)
        }
    }

    /// Variantes de siège de hamza : chaque siège non initial (ؤ ئ أ إ) est
    /// remplacé par chacun des supports ا/و/ي (produit cartésien, borné à
    /// 2 sièges — au-delà le mot est assez long pour que les trigrammes
    /// absorbent l'écart).
    private func appendHamzaSeatForms(display: String, to forms: inout [String]) {
        let scalars = Array(display.unicodeScalars)
        var seats: [Int] = []
        var seenBaseLetter = false
        for (position, scalar) in scalars.enumerated() {
            if Self.hamzaSeats.contains(scalar), seenBaseLetter {
                seats.append(position)
            }
            if Self.isBaseLetter(scalar) { seenBaseLetter = true }
        }
        guard !seats.isEmpty, seats.count <= 2 else { return }

        var combos: [[Unicode.Scalar]] = [[]]
        for _ in seats {
            combos = combos.flatMap { combo in Self.seatSupports.map { combo + [$0] } }
        }
        for combo in combos {
            var copy = scalars
            for (offset, position) in seats.enumerated() { copy[position] = combo[offset] }
            var view = String.UnicodeScalarView()
            view.append(contentsOf: copy)
            append(variant: String(view), to: &forms)
        }
    }

    private func append(variant: String, to forms: inout [String]) {
        let form = canonical(QuranSearchNormalizer.tokens(variant).joined())
        if !form.isEmpty, !forms.contains(form) { forms.append(form) }
    }

    // MARK: - Privé

    private static let superscriptAlef: Unicode.Scalar = "\u{0670}"
    private static let alef: Unicode.Scalar = "\u{0627}"
    /// و, ي, ى — supports graphiques d'un alef suscrit.
    private static let alefCarriers: Set<Unicode.Scalar> = ["\u{0648}", "\u{064A}", "\u{0649}"]
    /// أ إ ؤ ئ — hamza portée par un support (le siège varie selon la voyelle).
    private static let hamzaSeats: Set<Unicode.Scalar> = ["\u{0623}", "\u{0625}", "\u{0624}", "\u{0626}"]
    /// Supports que la dictée peut écrire à la place : ا, و, ي.
    private static let seatSupports: [Unicode.Scalar] = ["\u{0627}", "\u{0648}", "\u{064A}"]

    private static func isBaseLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x0621...0x064A).contains(Int(scalar.value)) || scalar == "\u{0671}"
    }

    private nonisolated struct EquivalenceFile: Decodable {
        let pairs: [[String]]
    }
}
