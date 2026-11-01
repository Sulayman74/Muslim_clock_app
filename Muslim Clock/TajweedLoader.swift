//
//  TajweedLoader.swift
//  Muslim Clock — Correcteur de récitation, couleurs tajwid (affichage)
//
//  Charge l'édition `quran-tajweed` (api.alquran.cloud, même hôte que le
//  verset du jour) par sourate, via RemoteJSONLoader : réseau puis cache
//  Documents. Le texte est canonique : l'absence d'expiration du cache est
//  ici un avantage. Hafs uniquement (numérotation koufi de l'édition).
//

import Foundation
import os

@MainActor
enum TajweedLoader {

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "Tajweed")
    /// Sourates déjà décodées (segments par verset), pour la session.
    private static var memory: [Int: [Int: [TajweedRun]]] = [:]

    /// Segments colorés des versets demandés. Dictionnaire vide si la riwaya
    /// n'est pas Hafs ou si la sourate est indisponible (hors-ligne sans cache).
    static func runs(riwaya: Riwaya, surah: Int, ayahRange: ClosedRange<Int>) async -> [Int: [TajweedRun]] {
        guard riwaya == .hafs else { return [:] }
        let all = await surahRuns(surah)
        return all.filter { ayahRange.contains($0.key) }
    }

    private static func surahRuns(_ surah: Int) async -> [Int: [TajweedRun]] {
        if let cached = memory[surah] { return cached }
        guard let response = await RemoteJSONLoader.load(
            filename: "quran-tajweed-\(surah).json",
            remoteURL: "https://api.alquran.cloud/v1/surah/\(surah)/quran-tajweed",
            type: TajweedSurahResponse.self,
            timeout: 15.0
        ) else {
            logger.notice("Tajwid sourate \(surah) indisponible (réseau et cache) — texte sans couleurs.")
            return [:]
        }
        var result: [Int: [TajweedRun]] = [:]
        for ayah in response.data.ayahs {
            var runs = TajweedParser.runs(from: ayah.text)
            // L'édition colle la basmala au verset 1 (sauf Fâtiha et at-Tawba).
            if ayah.numberInSurah == 1, surah != 1, surah != 9 {
                runs = TajweedParser.strippingLeadingBasmala(runs)
            }
            result[ayah.numberInSurah] = runs
        }
        memory[surah] = result
        return result
    }
}

// MARK: - Schéma de la réponse

nonisolated struct TajweedSurahResponse: Codable, Sendable {
    nonisolated struct Payload: Codable, Sendable {
        let ayahs: [Ayah]
    }
    nonisolated struct Ayah: Codable, Sendable {
        let numberInSurah: Int
        let text: String
    }
    let data: Payload
}
