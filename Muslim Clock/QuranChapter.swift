//
//  QuranChapter.swift
//  Muslim Clock — module Quran Library
//
//  Modèles Codable mappant exactement le schéma `risan/quran-json@3.1.2` via jsDelivr.
//  Schéma validé par fetch live (cf. AUDIT_QURAN_INTEGRATION.md §3).
//

import Foundation

// MARK: - Index racine (114 sourates)

/// Entrée de l'index racine `chapters/fr/index.json`.
///
/// Sert à afficher la liste des 114 sourates sans avoir besoin de fetch chaque
/// sourate individuellement (poids ~23 KB pour toute la liste).
struct QuranChapterIndex: Codable, Identifiable, Hashable {
    /// Numéro de la sourate (1…114).
    let id: Int
    /// Nom arabe court (ex: `"الفاتحة"`).
    let name: String
    /// Translittération latine (ex: `"Al-Fatihah"`).
    let transliteration: String
    /// Traduction française du nom (ex: `"L'ouverture"`). `nil` si endpoint sans trad.
    let translation: String?
    /// Type révélation : `"meccan"` ou `"medinan"`.
    let type: String
    /// Nombre total de versets dans la sourate.
    let totalVerses: Int
    /// URL absolue jsDelivr vers la sourate FR (présent dans `index.json` uniquement).
    let link: String?

    enum CodingKeys: String, CodingKey {
        case id, name, transliteration, translation, type, link
        case totalVerses = "total_verses"
    }

    /// `true` si sourate révélée à La Mecque (avant l'Hégire).
    var isMeccan: Bool { type.lowercased() == "meccan" }
}

// MARK: - Sourate complète

/// Sourate complète avec ses versets — endpoint `chapters/fr/{id}.json` ou `chapters/{id}.json`.
struct QuranChapter: Codable, Identifiable {
    let id: Int
    let name: String
    let transliteration: String
    let translation: String?
    let type: String
    let totalVerses: Int
    let verses: [QuranAyah]

    enum CodingKeys: String, CodingKey {
        case id, name, transliteration, translation, type, verses
        case totalVerses = "total_verses"
    }

    var isMeccan: Bool { type.lowercased() == "meccan" }

    /// Indique si l'app doit afficher manuellement la Basmala au-dessus du verset 1.
    ///
    /// La Basmala n'est PAS un verset distinct dans `risan/quran-json` (sauf Fatiha où
    /// elle est verset 1). Pour les sourates 2-114 sauf 9 (At-Tawba), il faut l'afficher
    /// manuellement en tête de la sourate.
    var shouldDisplayBismillah: Bool {
        // At-Tawba (sourate 9) ne commence pas par la Basmala — exception unique.
        // Al-Fatiha (sourate 1) intègre déjà la Basmala comme verset 1 — pas besoin de la rajouter.
        id != 1 && id != 9
    }
}

// MARK: - Verset

/// Un verset du Coran — texte Uthmani + translittération + traduction optionnelle.
struct QuranAyah: Codable, Identifiable, Hashable {
    /// Numéro du verset dans la sourate (1...totalVerses).
    let id: Int
    /// Texte arabe Uthmani avec diacritiques, tanwin ouverts normalisés (cf. `normalizingOpenTanwin`).
    let text: String
    /// Traduction française. `nil` si endpoint sans traduction.
    let translation: String?
    /// Translittération latine (style alquran.cloud, ASCII brut).
    let transliteration: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text).normalizingOpenTanwin
        translation = try container.decodeIfPresent(String.self, forKey: .translation)
        transliteration = try container.decode(String.self, forKey: .transliteration)
    }
}

private extension String {
    /// Remappe les tanwin ouverts (idghâm/ikhfâ) hérités du jeu KFGQPC Hafs — encodage
    /// utilisé par `quran-json` — vers les codepoints Unicode modernes U+08F0–U+08F2,
    /// les seuls couverts correctement par la police AmiriQuran.
    ///
    /// Sans ce remappage, U+065E (absent du cmap de la police) force CoreText à rendre
    /// la lettre porteuse + son tanwin en GeezaPro dans un run séparé, ce qui casse la
    /// liaison des lettres (ex. le ي de عُمۡيٞ) et déforme le tanwin.
    ///
    /// Opère sur les scalaires Unicode : ces signes sont combinants, donc jamais
    /// isolés dans un `Character` (grappe de graphèmes) — un `map` sur `Character`
    /// ne les verrait pas.
    var normalizingOpenTanwin: String {
        let mapping: [Unicode.Scalar: Unicode.Scalar] = [
            "\u{0657}": "\u{08F0}",  // fathatan ouvert (هُدٗى)
            "\u{065E}": "\u{08F1}",  // dammatan ouvert (قَدِيرٞ)
            "\u{0656}": "\u{08F2}",  // kasratan ouvert (يَوۡمَئِذٖ)
        ]
        guard unicodeScalars.contains(where: { mapping[$0] != nil }) else { return self }
        var result = String.UnicodeScalarView()
        for scalar in unicodeScalars {
            result.append(mapping[scalar] ?? scalar)
        }
        return String(result)
    }
}

// MARK: - Constantes

enum QuranConstants {
    /// Texte de la Basmala (à afficher en tête des sourates 2-114 sauf 9).
    static let bismillah = "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ"

    /// Translittération de la Basmala.
    static let bismillahTransliteration = "Bismi Allahi alrrahmani alrraheemi"

    /// Traduction française de la Basmala.
    static let bismillahFrench = "Au nom d'Allah, le Tout Miséricordieux, le Très Miséricordieux"

    /// Total de sourates dans le Mushaf.
    static let totalChapters = 114

    /// Total de pages dans le Mushaf Madinah standard.
    static let totalMadinahPages = 604
}
