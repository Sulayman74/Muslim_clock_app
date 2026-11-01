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

extension RecitationReference {
    /// Plafond documenté par Apple pour `contextualStrings` (toutes étiquettes confondues).
    static let maxRecognitionHints = 100

    /// Indices de vocabulaire à donner au moteur de reconnaissance : les mots du
    /// passage en graphie de dictée, dédoublonnés, les plus longs d'abord (ce
    /// sont les mots rares, coraniques, que le modèle de dictée connaît le moins
    /// — les mots-outils courts n'ont pas besoin d'aide), plafonnés à 100.
    ///
    /// C'est le « calibrage de l'écoute » : sans ces indices, la dictée devine du
    /// vocabulaire moderne sur une récitation et casse des mots justes.
    var recognitionHints: [String] {
        var seen = Set<String>()
        var unique: [(order: Int, word: String)] = []
        for word in words {
            let plain = QuranSearchNormalizer.dictationForm(word.display)
            guard !plain.isEmpty, seen.insert(plain).inserted else { continue }
            unique.append((unique.count, plain))
        }
        return unique
            .sorted { ($0.word.count, -$0.order) > ($1.word.count, -$1.order) }
            .prefix(Self.maxRecognitionHints)
            .map(\.word)
    }
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
    /// Le moteur rate aussi ce mot sur la récitation PARFAITE du récitateur :
    /// on ne peut pas juger l'utilisateur dessus (cf. `RecitationCalibrator`).
    case unverifiable
}

/// Position d'un mot de référence (verset + index) — clé de calibration.
nonisolated struct AyahWordKey: Hashable, Sendable, Codable {
    let ayah: Int
    let index: Int
}

/// Ce que le moteur de reconnaissance fait du passage quand c'est le
/// RÉCITATEUR de référence qui le récite (cf. `RecitationCalibrator`).
///
/// - `reciterForms` : pour un mot que le moteur rend différemment mais de
///   façon reconnaissable (« وأصلحوا » → « واصلح », « فاتقوا » → « فتق »), la
///   forme qu'il produit. Un utilisateur dont le moteur produit la même forme
///   a récité comme le récitateur : le mot est **juste**, pas approximatif.
/// - `unjudgeable` : mots que le moteur rate complètement (omis ou remplacés
///   par autre chose) sur la récitation parfaite → non jugeables.
nonisolated struct RecitationCalibration: Equatable, Sendable {
    var status: RecitationCalibrationStatus = .notApplicable
    var unjudgeable: Set<AyahWordKey> = []
    var reciterForms: [AyahWordKey: String] = [:]
    /// Versets où le moteur rate plus de la moitié des mots du RÉCITATEUR :
    /// il n'y entend rien de fiable, on ne les note pas (tous non vérifiables).
    var unusableAyahs: Set<Int> = []
    /// Versets dont la calibration n'a pas pu être faite (réseau, audio, délai).
    var failedAyahs: Set<Int> = []

    static let none = RecitationCalibration()
    var isEmpty: Bool { unjudgeable.isEmpty && reciterForms.isEmpty && unusableAyahs.isEmpty }
}

/// Ce que la calibration a pu faire — affiché dans le résultat pour que
/// l'utilisateur sache si son score est calibré ou non.
nonisolated enum RecitationCalibrationStatus: Equatable, Sendable {
    /// Riwaya sans audio par verset (Warsh, Qaloun) : rien à calibrer.
    case notApplicable
    /// Aucune reconnaissance arabe locale capable de lire un fichier.
    case recognizerUnavailable
    /// Aucun verset n'a pu être calibré (réseau, audio, délai).
    case failed
    /// Au moins un verset calibré.
    case ready
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

    var hasUnverifiableWords: Bool {
        items.contains { $0.kind == .unverifiable }
    }

    /// Applique la calibration complète : mots non jugeables + versets où le
    /// moteur est inutilisable (tous leurs mots deviennent non vérifiables).
    func applying(_ calibration: RecitationCalibration) -> RecitationAlignment {
        var keys = calibration.unjudgeable
        for item in items {
            if let reference = item.reference, calibration.unusableAyahs.contains(reference.ayah) {
                keys.insert(AyahWordKey(ayah: reference.ayah, index: reference.index))
            }
        }
        return applyingUnjudgeable(keys)
    }

    /// Applique la calibration : les mots que le moteur rate AUSSI sur le
    /// récitateur deviennent `unverifiable` (jamais comptés faux) et sortent
    /// du dénominateur du score. Ne requalifie que les verdicts négatifs —
    /// un mot entendu juste reste juste ; la calibration ne sert qu'à pardonner.
    func applyingUnjudgeable(_ keys: Set<AyahWordKey>) -> RecitationAlignment {
        guard !keys.isEmpty else { return self }
        let adjusted = items.map { item -> AlignedWord in
            guard let reference = item.reference,
                  [.omitted, .substituted, .approximate].contains(item.kind),
                  keys.contains(AyahWordKey(ayah: reference.ayah, index: reference.index)) else {
                return item
            }
            return AlignedWord(id: item.id, kind: .unverifiable, reference: reference, heard: item.heard)
        }
        let judgeableRefs = adjusted.filter { $0.reference != nil && $0.kind != .unverifiable }.count
        let matched = adjusted.filter { $0.kind == .matched }.count
        let approximate = adjusted.filter { $0.kind == .approximate }.count
        let accuracy = judgeableRefs > 0
            ? (Double(matched) + 0.5 * Double(approximate)) / Double(judgeableRefs)
            : self.accuracy
        return RecitationAlignment(items: adjusted, accuracy: accuracy,
                                   hesitations: hesitations, heardCount: heardCount)
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
