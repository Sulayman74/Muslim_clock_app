//
//  RecitationModels.swift
//  Muslim Clock — Correcteur de récitation (phase 4 : socle)
//
//  Modèles de domaine purs : riwaya, texte de référence, transcription
//  entendue, résultat d'alignement, conseils. Aucune I/O ici — le chargement
//  vit dans RecitationReferenceLoader, le calcul dans RecitationAligner.
//

import Foundation

// MARK: - Riwaya

/// Transmission (riwaya) dans laquelle l'utilisateur récite.
///
/// Chaque riwaya a SA numérotation : Hafs suit le comptage koufi (6 236
/// versets), Warsh et Qaloun le comptage madani (6 214). Le correcteur
/// travaille toujours dans la numérotation de la riwaya choisie.
nonisolated enum Riwaya: String, CaseIterable, Identifiable, Codable, Sendable {
    case hafs, warsh, qaloun

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hafs: String(localized: "Hafs ʿan ʿÂsim")
        case .warsh: String(localized: "Warsh ʿan Nâfiʿ")
        case .qaloun: String(localized: "Qâlûn ʿan Nâfiʿ")
        }
    }

    var labelArabic: String {
        switch self {
        case .hafs: "حفص عن عاصم"
        case .warsh: "ورش عن نافع"
        case .qaloun: "قالون عن نافع"
        }
    }

    var totalAyahs: Int {
        switch self {
        case .hafs: 6_236
        case .warsh, .qaloun: 6_214
        }
    }

    /// Nom (sans extension) du corpus JSON bundlé — schéma compact
    /// `{s:[{c,n,e,v:[{i,t}]}]}` commun aux trois riwayat.
    var corpusResourceName: String {
        switch self {
        case .hafs: "quran-search-corpus"
        case .warsh: "quran-warsh"
        case .qaloun: "quran-qaloun"
        }
    }
}

// MARK: - Référence

/// Un mot du texte de référence.
nonisolated struct ReferenceWord: Equatable, Sendable {
    let ayah: Int
    /// Position du mot dans son verset, à partir de 0 (signes de pause exclus).
    let index: Int
    /// Graphie vocalisée, telle qu'affichée.
    let display: String
    /// Squelette `QuranSearchNormalizer` (sans harakât, hamzas unifiées).
    let normalized: String
}

/// Passage de référence (une sourate, une plage de versets) découpé en mots.
nonisolated struct RecitationReference: Equatable, Sendable {
    let riwaya: Riwaya
    let surah: Int
    let ayahRange: ClosedRange<Int>
    let words: [ReferenceWord]
    /// Texte complet de chaque verset (affichage).
    let ayahTexts: [Int: String]
}

// MARK: - Transcription

/// Un mot entendu par le moteur de reconnaissance.
nonisolated struct HeardToken: Equatable, Sendable {
    let text: String
    let normalized: String
    let timeRange: ClosedRange<TimeInterval>?
    let confidence: Double?
}

/// Transcription d'une récitation, en mots normalisés.
nonisolated struct RecitationTranscript: Equatable, Sendable {
    let tokens: [HeardToken]

    /// Transcription sans horodatage (ex. `SFSpeechRecognizer`).
    static func fromPlainText(_ text: String) -> RecitationTranscript {
        RecitationTranscript(tokens: words(in: text).map {
            HeardToken(text: $0.text, normalized: $0.normalized, timeRange: nil, confidence: nil)
        })
    }

    /// Transcription horodatée par segment (ex. `SpeechAnalyzer`).
    ///
    /// Le moteur ne date que des segments : la durée d'un segment est répartie
    /// sur ses mots au prorata de leur longueur normalisée. Les pauses entre
    /// segments sont donc préservées, celles à l'intérieur d'un segment non.
    static func fromSegments(_ segments: [(text: String, range: ClosedRange<TimeInterval>?)]) -> RecitationTranscript {
        var tokens: [HeardToken] = []
        for segment in segments {
            let segmentWords = words(in: segment.text)
            guard let range = segment.range else {
                tokens += segmentWords.map {
                    HeardToken(text: $0.text, normalized: $0.normalized, timeRange: nil, confidence: nil)
                }
                continue
            }
            let totalLength = Double(segmentWords.reduce(0) { $0 + $1.normalized.count })
            let duration = range.upperBound - range.lowerBound
            var elapsed = 0.0
            for word in segmentWords {
                let share = totalLength > 0 ? Double(word.normalized.count) / totalLength : 0
                let start = range.lowerBound + elapsed * duration
                elapsed += share
                let end = range.lowerBound + elapsed * duration
                tokens.append(HeardToken(text: word.text, normalized: word.normalized,
                                         timeRange: start...max(start, end), confidence: nil))
            }
        }
        return RecitationTranscript(tokens: tokens)
    }

    /// Découpe en mots normalisés non vides ; `text` garde le mot brut quand
    /// il ne donne qu'un seul token (cas normal).
    private static func words(in text: String) -> [(text: String, normalized: String)] {
        text.split(whereSeparator: \.isWhitespace).flatMap { chunk -> [(text: String, normalized: String)] in
            let normalized = QuranSearchNormalizer.tokens(String(chunk))
            if normalized.count == 1, let only = normalized.first { return [(String(chunk), only)] }
            return normalized.map { ($0, $0) }
        }
    }
}

// MARK: - Alignement

nonisolated enum AlignedWordKind: String, Sendable, Codable {
    case matched, approximate, omitted, substituted, inserted, repeated
}

/// Une case de l'alignement : mot de référence et/ou mot entendu.
///
/// `omitted` → `heard == nil` ; `inserted`/`repeated` → `reference == nil` ;
/// les autres portent les deux.
nonisolated struct AlignedWord: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: AlignedWordKind
    let reference: ReferenceWord?
    let heard: HeardToken?
}

/// Pause anormale au milieu d'un verset (nécessite des horodatages).
nonisolated struct Hesitation: Equatable, Sendable {
    let ayah: Int
    /// `ReferenceWord.index` du dernier mot prononcé avant la pause.
    let afterWordIndex: Int
    let gap: TimeInterval
}

nonisolated struct RecitationAlignment: Equatable, Sendable {
    /// Sous ce nombre de mots entendus, on ne juge pas.
    static let minimumHeardCount = 3
    /// Sous cette précision, on suppose un problème d'écoute plutôt que des erreurs.
    static let minimumTrustedAccuracy = 0.3

    let items: [AlignedWord]
    /// (matched + 0,5 × approximate) / nombre de mots de référence, ∈ [0, 1].
    let accuracy: Double
    let hesitations: [Hesitation]
    /// Mots entendus pris en compte (préambule basmala/ta'awwudh retiré).
    let heardCount: Int

    /// Règle produit : « je n'ai pas bien entendu » plutôt qu'une liste d'erreurs.
    var isLowConfidence: Bool {
        heardCount < Self.minimumHeardCount || accuracy < Self.minimumTrustedAccuracy
    }
}

// MARK: - Conseils

nonisolated enum CoachTipKind: String, Sendable {
    case omitted, substituted, inserted, repeated, hesitation, lowConfidence, perfect
}

nonisolated struct CoachTip: Identifiable, Equatable, Sendable {
    let id: Int
    let kind: CoachTipKind
    let ayah: Int?
    let wordIndex: Int?
    let textFr: String
}
