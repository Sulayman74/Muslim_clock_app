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
    /// En graphie uthmani, l'alef suscrit (U+0670) se lit « a » mais s'écrit
    /// selon trois logiques que la dictée (imla'i) rend différemment :
    /// - ignoré : عَلَىٰ → على ;
    /// - alef ajouté : ءَايَٰت → ايات, العٰلمين → العالمين ;
    /// - alef remplaçant son support و/ي/ى : الصلوٰة → الصلاه, ءاتيٰهم → اتاهم.
    /// On garde les trois ; l'aligneur retient la plus proche de ce qui est entendu.
    func referenceForms(display: String, normalized: String) -> [String] {
        var forms = [canonical(normalized)]
        guard display.unicodeScalars.contains(Self.superscriptAlef) else { return forms }

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
            let form = canonical(QuranSearchNormalizer.tokens(variant).joined())
            if !form.isEmpty, !forms.contains(form) { forms.append(form) }
        }
        return forms
    }

    // MARK: - Privé

    private static let superscriptAlef: Unicode.Scalar = "\u{0670}"
    private static let alef: Unicode.Scalar = "\u{0627}"
    /// و, ي, ى — supports graphiques d'un alef suscrit.
    private static let alefCarriers: Set<Unicode.Scalar> = ["\u{0648}", "\u{064A}", "\u{0649}"]

    private static func isBaseLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x0621...0x064A).contains(Int(scalar.value)) || scalar == "\u{0671}"
    }

    private nonisolated struct EquivalenceFile: Decodable {
        let pairs: [[String]]
    }
}
