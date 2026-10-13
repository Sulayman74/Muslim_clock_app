//
//  RecitationCoach.swift
//  Muslim Clock — Correcteur de récitation (phase 4 : socle)
//
//  Transforme un alignement en conseils courts, à partir de templates
//  localisés (V1, aucun LLM). Le disclaimer « un mot non signalé n'est pas
//  forcément juste » est affiché par l'UI, pas ici.
//

import Foundation

nonisolated enum RecitationCoach {

    static let maxTips = 5

    /// Conseils pour un alignement, dans l'ordre de lecture.
    ///
    /// Confiance faible → un seul conseil `.lowConfidence` (on ne liste pas
    /// d'erreurs qu'on n'a peut-être pas entendues). Aucune erreur → un seul
    /// `.perfect`. Sinon au plus `maxTips` conseils, choisis par gravité
    /// (omission > substitution > hésitation > répétition > ajout) puis
    /// remis dans l'ordre du texte. Les mots consécutifs de même nature dans
    /// un même verset sont regroupés en un seul conseil.
    static func tips(for alignment: RecitationAlignment, reference: RecitationReference) -> [CoachTip] {
        if alignment.isLowConfidence {
            return [CoachTip(id: 0, kind: .lowConfidence, ayah: nil, wordIndex: nil,
                             textFr: String(localized: "Je n'ai pas bien entendu ta récitation. Rapproche-toi du micro, dans un endroit calme, puis réessaie."))]
        }

        let issues = wordIssues(in: alignment.items, reference: reference)
            + hesitationIssues(alignment)
        guard !issues.isEmpty else {
            let allExact = alignment.items.allSatisfy { $0.kind == .matched }
            let text = allExact
                ? String(localized: "Aucune erreur de mot détectée. Continue ainsi !")
                : String(localized: "Aucune erreur nette détectée, mais certains mots ont été reconnus de façon approximative. Réécoute-les pour t'en assurer.")
            return [CoachTip(id: 0, kind: .perfect, ayah: nil, wordIndex: nil, textFr: text)]
        }

        return issues
            .sorted { ($0.priority, $0.position) < ($1.priority, $1.position) }
            .prefix(maxTips)
            .sorted { $0.position < $1.position }
            .enumerated()
            .map { CoachTip(id: $0.offset, kind: $0.element.kind, ayah: $0.element.ayah,
                            wordIndex: $0.element.wordIndex, textFr: $0.element.text) }
    }

    // MARK: - Privé

    private struct Issue {
        let kind: CoachTipKind
        let ayah: Int?
        let wordIndex: Int?
        let text: String
        /// Ordre dans le texte (position dans `items`).
        let position: Double

        var priority: Int {
            switch kind {
            case .omitted: 0
            case .substituted: 1
            case .hesitation: 2
            case .repeated: 3
            default: 4
            }
        }
    }

    /// Regroupe les suites de mots de même nature (omis, répétés, ajoutés)
    /// dans un même verset ; une substitution reste un conseil par mot.
    private static func wordIssues(in items: [AlignedWord], reference: RecitationReference) -> [Issue] {
        var issues: [Issue] = []
        var currentAyah = reference.ayahRange.lowerBound
        var position = 0
        while position < items.count {
            let item = items[position]
            if let ayah = item.reference?.ayah { currentAyah = ayah }
            switch item.kind {
            case .matched, .approximate:
                position += 1
            case .substituted:
                if let expected = item.reference, let heard = item.heard {
                    issues.append(Issue(kind: .substituted, ayah: expected.ayah, wordIndex: expected.index,
                                        text: String(localized: "Verset \(expected.ayah) : « \(heard.text) » a été entendu à la place de « \(expected.display) ». Vérifie ce mot dans le texte."),
                                        position: Double(position)))
                }
                position += 1
            case .omitted, .inserted, .repeated:
                let ayah = currentAyah
                var run = [item]
                while position + run.count < items.count {
                    let next = items[position + run.count]
                    guard next.kind == item.kind, (next.reference?.ayah ?? ayah) == ayah else { break }
                    run.append(next)
                }
                issues.append(runIssue(run, ayah: ayah, position: position))
                position += run.count
            }
        }
        return issues
    }

    private static func runIssue(_ run: [AlignedWord], ayah: Int, position: Int) -> Issue {
        let kind = run[0].kind
        switch kind {
        case .omitted:
            let words = run.compactMap(\.reference?.display).joined(separator: " ")
            let text = run.count == 1
                ? String(localized: "Verset \(ayah) : le mot « \(words) » n'a pas été entendu. Réécoute le récitateur puis réessaie.")
                : String(localized: "Verset \(ayah) : le passage « \(words) » n'a pas été entendu. Réécoute le récitateur puis réessaie.")
            return Issue(kind: .omitted, ayah: ayah, wordIndex: run[0].reference?.index,
                         text: text, position: Double(position))
        case .repeated:
            let words = run.compactMap(\.heard?.text).joined(separator: " ")
            return Issue(kind: .repeated, ayah: ayah, wordIndex: nil,
                         text: String(localized: "Verset \(ayah) : « \(words) » a été répété. Essaie d'enchaîner sans revenir en arrière."),
                         position: Double(position))
        default:
            let words = run.compactMap(\.heard?.text).joined(separator: " ")
            return Issue(kind: .inserted, ayah: ayah, wordIndex: nil,
                         text: String(localized: "Verset \(ayah) : « \(words) » a été entendu en trop. Vérifie que ce mot fait bien partie du passage."),
                         position: Double(position))
        }
    }

    private static func hesitationIssues(_ alignment: RecitationAlignment) -> [Issue] {
        alignment.hesitations.compactMap { hesitation in
            guard let position = alignment.items.firstIndex(where: {
                $0.reference?.ayah == hesitation.ayah && $0.reference?.index == hesitation.afterWordIndex
            }), let word = alignment.items[position].reference else { return nil }
            let seconds = Int(hesitation.gap.rounded())
            return Issue(kind: .hesitation, ayah: hesitation.ayah, wordIndex: hesitation.afterWordIndex,
                         text: String(localized: "Verset \(hesitation.ayah) : pause de \(seconds) s après « \(word.display) ». Revois l'enchaînement de ce passage."),
                         // +0,5 : juste après le mot concerné, avant le suivant.
                         position: Double(position) + 0.5)
        }
    }
}
