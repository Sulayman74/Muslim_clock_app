//
//  Tajweed.swift
//  Muslim Clock — Correcteur de récitation, couleurs tajwid (affichage)
//
//  Modèle et parser PURS du balisage de l'édition `quran-tajweed`
//  d'api.alquran.cloud : chaque segment annoté s'écrit `[x:id[texte]` où `x`
//  est la lettre de la règle. Texte et annotations arrivent ensemble : aucun
//  alignement à faire avec un autre corpus.
//
//  Usage : AFFICHAGE uniquement (texte de référence de la séance de
//  récitation). Le tajwid n'est jamais évalué — invariant du correcteur.
//

import Foundation
import SwiftUI

// MARK: - Règles

/// Lettre de règle de l'édition `quran-tajweed` (cf. alquran.cloud/tajweed-guide).
nonisolated enum TajweedRule: Character, Sendable, CaseIterable {
    case hamzatWasl = "h"
    case silent = "s"
    case lamShamsiyya = "l"
    case maddNormal = "n"
    case maddPermissible = "p"
    case maddNecessary = "m"
    case maddObligatory = "o"
    case qalqala = "q"
    case ikhfaShafawi = "c"
    case ikhfa = "f"
    case idghamShafawi = "w"
    case iqlab = "i"
    case idghamWithGhunna = "a"
    case idghamWithoutGhunna = "u"
    case idghamMutajanisayn = "d"
    case idghamMutaqaribayn = "b"
    case ghunna = "g"

    /// Famille affichée : 6 couleurs lisibles plutôt que 17 règles.
    var family: TajweedFamily {
        switch self {
        case .hamzatWasl, .silent, .lamShamsiyya: .silent
        case .maddNormal, .maddPermissible, .maddNecessary, .maddObligatory: .madd
        case .qalqala: .qalqala
        case .ikhfaShafawi, .ikhfa: .ikhfa
        case .iqlab: .iqlab
        case .idghamShafawi, .idghamWithGhunna, .idghamWithoutGhunna,
             .idghamMutajanisayn, .idghamMutaqaribayn, .ghunna: .ghunna
        }
    }
}

/// Famille de règles → une couleur, un libellé. Ordre = ordre de la légende.
nonisolated enum TajweedFamily: Int, Sendable, CaseIterable, Comparable {
    case madd, ghunna, qalqala, ikhfa, iqlab, silent

    nonisolated static func < (lhs: TajweedFamily, rhs: TajweedFamily) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .madd: String(localized: "Madd (allongement)")
        case .ghunna: String(localized: "Ghunna · Idghâm")
        case .qalqala: String(localized: "Qalqala")
        case .ikhfa: String(localized: "Ikhfâ'")
        case .iqlab: String(localized: "Iqlâb")
        case .silent: String(localized: "Lettres muettes")
        }
    }

    /// Palette pour fond sombre (séance de récitation sur `CosmicBackground`).
    var color: Color {
        switch self {
        case .madd: Color(red: 0.45, green: 0.66, blue: 1.0)
        case .ghunna: Color(red: 0.35, green: 0.85, blue: 0.55)
        case .qalqala: Color(red: 1.0, green: 0.42, blue: 0.42)
        case .ikhfa: Color(red: 0.78, green: 0.49, blue: 1.0)
        case .iqlab: Color(red: 0.15, green: 0.82, blue: 1.0)
        case .silent: Color.white.opacity(0.45)
        }
    }
}

// MARK: - Segments

/// Un segment de texte, annoté ou non.
nonisolated struct TajweedRun: Equatable, Sendable {
    let text: String
    let rule: TajweedRule?
}

extension Array where Element == TajweedRun {
    nonisolated var plainText: String { map(\.text).joined() }

    nonisolated var families: [TajweedFamily] {
        Array<TajweedFamily>(Set(compactMap { $0.rule?.family })).sorted()
    }
}

// MARK: - Parser

nonisolated enum TajweedParser {

    /// Découpe le balisage `[x:id[texte]` en segments. Tout ce qui n'est pas un
    /// marqueur reconnu est conservé tel quel (une lettre de règle inconnue
    /// donne un segment sans règle — le texte n'est jamais perdu).
    static func runs(from markup: String) -> [TajweedRun] {
        // SCALAIRES, pas Characters : dans `[p[ِي]`, le crochet et la kasra qui
        // le suit forment un seul graphème « [ِ » — un découpage en Characters
        // ne verrait jamais le « [ » (ni le « ] » collé à un sukûn).
        let scalars = Array(markup.unicodeScalars)
        var runs: [TajweedRun] = []
        var plain = String.UnicodeScalarView()
        var i = 0

        func flushPlain() {
            if !plain.isEmpty {
                runs.append(TajweedRun(text: String(plain), rule: nil))
                plain = String.UnicodeScalarView()
            }
        }

        while i < scalars.count {
            // Marqueur : "[" lettre-ASCII [":" chiffres] "[" … "]".
            // L'édition livre le plus souvent la forme courte `[l[ل]` ; la doc
            // montre `[h:9421[ٱ]` — l'identifiant est donc optionnel.
            if let marker = marker(in: scalars, at: i) {
                flushPlain()
                runs.append(TajweedRun(text: marker.text, rule: TajweedRule(rawValue: Character(marker.letter))))
                i = marker.end
            } else {
                plain.append(scalars[i])
                i += 1
            }
        }
        flushPlain()
        return attachingLeadingMarks(runs)
    }

    /// Un segment ne doit jamais commencer par un signe combinant (haraka,
    /// shadda, sukûn, madda…) : il appartient à la lettre qui le précède.
    /// L'édition coupe pourtant `رَّح[p[ِي]مِ` — la kasra de ح tombe dans le
    /// segment du madd. Un run de couleur qui scinde un graphème casse le
    /// rendu Core Text : on rattache ces signes au run précédent et on
    /// supprime les runs devenus vides.
    static func attachingLeadingMarks(_ runs: [TajweedRun]) -> [TajweedRun] {
        var result: [TajweedRun] = []
        for run in runs {
            var scalars = Array(run.text.unicodeScalars)
            if !result.isEmpty {
                var moved = String.UnicodeScalarView()
                while let first = scalars.first, isCombiningMark(first) {
                    moved.append(first)
                    scalars.removeFirst()
                }
                if !moved.isEmpty, let previous = result.popLast() {
                    result.append(TajweedRun(text: previous.text + String(moved), rule: previous.rule))
                }
            }
            guard !scalars.isEmpty else { continue }
            var view = String.UnicodeScalarView()
            view.append(contentsOf: scalars)
            result.append(TajweedRun(text: String(view), rule: run.rule))
        }
        return result
    }

    private static func isCombiningMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }

    /// Reconnaît un marqueur commençant en `start`. `end` = index après le `]`.
    private static func marker(in scalars: [Unicode.Scalar], at start: Int) -> (letter: Unicode.Scalar, text: String, end: Int)? {
        guard scalars[start] == "[", start + 1 < scalars.count else { return nil }
        let letter = scalars[start + 1]
        guard isASCIILetter(letter) else { return nil }
        var cursor = start + 2
        if cursor < scalars.count, scalars[cursor] == ":" {
            cursor += 1
            while cursor < scalars.count, ("0"..."9").contains(scalars[cursor]) { cursor += 1 }
        }
        guard cursor < scalars.count, scalars[cursor] == "[",
              let close = scalars[(cursor + 1)...].firstIndex(of: "]") else { return nil }
        var text = String.UnicodeScalarView()
        text.append(contentsOf: scalars[(cursor + 1)..<close])
        return (letter, String(text), close + 1)
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    /// Retire la basmala en tête des segments (l'édition la colle au verset 1
    /// de chaque sourate, sauf la Fâtiha et at-Tawba). Sans effet si absente.
    static func strippingLeadingBasmala(_ runs: [TajweedRun]) -> [TajweedRun] {
        let plain = runs.plainText
        let words = plain.split(whereSeparator: \.isWhitespace)
        let basmala = QuranSearchNormalizer.basmalaTokens
        guard words.count > basmala.count,
              words.prefix(basmala.count).map({ QuranSearchNormalizer.tokens(String($0)).joined() }) == basmala else {
            return runs
        }
        // Fin du 4ᵉ mot + blancs qui suivent. Compté en SCALAIRES : un marqueur
        // peut commencer par un signe combinant, qui fusionne deux graphèmes à
        // la jointure de deux segments — le compte en caractères dériverait.
        var cursor = words[basmala.count - 1].endIndex
        while cursor < plain.endIndex, plain[cursor].isWhitespace {
            cursor = plain.index(after: cursor)
        }
        let toDrop = plain.unicodeScalars.distance(from: plain.unicodeScalars.startIndex, to: cursor)
        return dropping(scalarCount: toDrop, from: runs)
    }

    private static func dropping(scalarCount: Int, from runs: [TajweedRun]) -> [TajweedRun] {
        var remaining = scalarCount
        var result: [TajweedRun] = []
        for run in runs {
            let count = run.text.unicodeScalars.count
            if remaining <= 0 {
                result.append(run)
            } else if count <= remaining {
                remaining -= count
            } else {
                result.append(TajweedRun(text: String(String.UnicodeScalarView(run.text.unicodeScalars.dropFirst(remaining))),
                                         rule: run.rule))
                remaining = 0
            }
        }
        return result
    }
}
