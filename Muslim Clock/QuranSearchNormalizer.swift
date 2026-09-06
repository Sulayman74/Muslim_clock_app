//
//  QuranSearchNormalizer.swift
//  Muslim Clock — Spotlight du Coran (Phase 1)
//
//  Normalisation arabe pour la recherche de versets : réduit corpus ET requête
//  (tapée ou dictée) au même « squelette » — harakât et signes coraniques
//  retirés, variantes d'alef/hamza unifiées. Fonctions pures, testées.
//
//  Ne PAS fusionner avec `String.strippedTashkeel` (String+Search.swift) : ce
//  dernier a d'autres callers (adhkar, podcast) avec une sémantique plus douce.
//

import Foundation

nonisolated enum QuranSearchNormalizer {

    // MARK: - Tables de normalisation

    /// Scalaires supprimés : harakât/tanwin/shadda/sukun (U+064B–U+065F),
    /// alef suscrit (U+0670), tatwîl, signes coraniques de waqf/sajda
    /// (U+06D6–U+06ED), tanwin ouverts remappés (U+08F0–U+08F2), hamza isolée.
    private static let removed: Set<Unicode.Scalar> = {
        var set = Set<Unicode.Scalar>()
        for v in 0x064B...0x065F { set.insert(Unicode.Scalar(v)!) }
        for v in 0x06D6...0x06ED { set.insert(Unicode.Scalar(v)!) }
        for v in 0x08F0...0x08F2 { set.insert(Unicode.Scalar(v)!) }
        set.insert("\u{0670}") // alef suscrit (الرحمٰن → الرحمن)
        set.insert("\u{0640}") // tatwîl
        set.insert("\u{0621}") // hamza isolée ء
        set.insert("\u{FEFF}") // BOM
        return set
    }()

    /// Scalaires unifiés vers une forme canonique.
    private static let mapped: [Unicode.Scalar: Unicode.Scalar] = [
        "\u{0671}": "\u{0627}", // ٱ alef wasla → ا
        "\u{0622}": "\u{0627}", // آ → ا
        "\u{0623}": "\u{0627}", // أ → ا
        "\u{0625}": "\u{0627}", // إ → ا
        "\u{0649}": "\u{064A}", // ى alef maqsura → ي
        "\u{0629}": "\u{0647}", // ة ta marbuta → ه
        "\u{0624}": "\u{0648}", // ؤ → و
        "\u{0626}": "\u{064A}", // ئ → ي
    ]

    /// Lettres arabes conservées (bloc principal, après mapping).
    private static func isKeptLetter(_ s: Unicode.Scalar) -> Bool {
        (0x0621...0x064A).contains(Int(s.value))
    }

    // MARK: - API

    /// Réduit un texte arabe à son squelette de recherche : lettres unifiées
    /// séparées par des espaces simples. Tout scalaire non-lettre (ponctuation,
    /// chiffres, latin, marqueurs de verset ۞/۩) devient séparateur.
    ///
    /// Idempotente : `normalize(normalize(x)) == normalize(x)`.
    static func normalize(_ text: String) -> String {
        tokens(text).joined(separator: " ")
    }

    /// Mots normalisés non vides, dans l'ordre du texte.
    static func tokens(_ text: String) -> [String] {
        var words: [String] = []
        var current = String.UnicodeScalarView()

        func flush() {
            if !current.isEmpty {
                words.append(String(current))
                current = String.UnicodeScalarView()
            }
        }

        for scalar in text.unicodeScalars {
            if removed.contains(scalar) { continue }
            let canonical = mapped[scalar] ?? scalar
            if isKeptLetter(canonical) {
                current.append(canonical)
            } else {
                flush() // séparateur (espace, ponctuation, chiffre, latin…)
            }
        }
        flush()
        return words
    }

    /// Tokens normalisés de la Basmala — référence pour `strippingLeadingBasmala`.
    static let basmalaTokens = ["بسم", "الله", "الرحمن", "الرحيم"]

    /// Retire la Basmala en tête si (et seulement si) d'autres mots la suivent :
    /// les récitants la prononcent presque toujours avant le verset. Une requête
    /// qui n'est QUE la Basmala est conservée telle quelle (→ Fatiha 1:1).
    static func strippingLeadingBasmala(_ tokens: [String]) -> [String] {
        guard tokens.count > basmalaTokens.count,
              Array(tokens.prefix(basmalaTokens.count)) == basmalaTokens else {
            return tokens
        }
        return Array(tokens.dropFirst(basmalaTokens.count))
    }
}
