//
//  RecitationProgress.swift
//  Muslim Clock — Correcteur de récitation (phase 4 : socle)
//
//  Suivi par verset des essais de récitation (UserDefaults "recitation_progress").
//  Indépendant des modules Hafs (plan Coran, khatma) : le correcteur n'y écrit
//  jamais, et ses clés portent la riwaya et SA numérotation.
//

import Foundation
import os

nonisolated struct AyahPracticeRecord: Codable, Equatable, Sendable {
    var attempts: Int
    var bestAccuracy: Double
    var lastDate: Date
    /// `ReferenceWord.index` des mots ratés (omis, substitués, approximatifs)
    /// au DERNIER essai.
    var weakWordIndexes: [Int]
}

extension AyahPracticeRecord {
    /// Tolérant : `weakWordIndexes` absent (ancien format) → liste vide.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try container.decode(Int.self, forKey: .attempts)
        bestAccuracy = try container.decode(Double.self, forKey: .bestAccuracy)
        lastDate = try container.decode(Date.self, forKey: .lastDate)
        weakWordIndexes = try container.decodeIfPresent([Int].self, forKey: .weakWordIndexes) ?? []
    }
}

nonisolated struct RecitationProgress: Codable, Equatable {

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "RecitationProgress")

    /// Clé `"riwaya:sourate:verset"`.
    var records: [String: AyahPracticeRecord]

    init(records: [String: AyahPracticeRecord] = [:]) {
        self.records = records
    }

    static func key(riwaya: Riwaya, surah: Int, ayah: Int) -> String {
        "\(riwaya.rawValue):\(surah):\(ayah)"
    }

    /// Enregistre un essai pour chaque verset de la référence.
    ///
    /// Un essai à confiance faible (`isLowConfidence`) n'est PAS compté : on ne
    /// pénalise pas l'utilisateur pour un micro mal placé. La précision d'un
    /// verset suit la même formule que `RecitationAlignment.accuracy`,
    /// restreinte à ses mots.
    mutating func record(alignment: RecitationAlignment, reference: RecitationReference, on date: Date = .now) {
        guard !alignment.isLowConfidence else { return }
        for ayah in reference.ayahRange {
            // Les mots non vérifiables (calibration récitateur) sortent du
            // dénominateur : on ne pénalise pas une surdité du moteur.
            let ayahItems = alignment.items.filter { $0.reference?.ayah == ayah && $0.kind != .unverifiable }
            guard !ayahItems.isEmpty else { continue }
            let matched = ayahItems.filter { $0.kind == .matched }.count
            let approximate = ayahItems.filter { $0.kind == .approximate }.count
            let accuracy = (Double(matched) + 0.5 * Double(approximate)) / Double(ayahItems.count)
            let weak = ayahItems
                .filter { [.omitted, .substituted, .approximate].contains($0.kind) }
                .compactMap(\.reference?.index)
                .sorted()

            let key = Self.key(riwaya: reference.riwaya, surah: reference.surah, ayah: ayah)
            var entry = records[key] ?? AyahPracticeRecord(attempts: 0, bestAccuracy: 0, lastDate: date, weakWordIndexes: [])
            entry.attempts += 1
            entry.bestAccuracy = max(entry.bestAccuracy, accuracy)
            entry.lastDate = date
            entry.weakWordIndexes = weak
            records[key] = entry
        }
    }

    /// Clés des versets jamais réussis au seuil, dans l'ordre riwaya → sourate → verset.
    func versesToRework(threshold: Double = 0.8) -> [String] {
        records
            .filter { $0.value.bestAccuracy < threshold }
            .keys
            .sorted { Self.sortKey($0) < Self.sortKey($1) }
    }

    private static func sortKey(_ key: String) -> (Int, Int, Int) {
        let parts = key.split(separator: ":")
        guard parts.count == 3,
              let riwaya = Riwaya(rawValue: String(parts[0])),
              let order = Riwaya.allCases.firstIndex(of: riwaya),
              let surah = Int(parts[1]), let ayah = Int(parts[2]) else {
            return (Int.max, Int.max, Int.max)
        }
        return (order, surah, ayah)
    }

    // MARK: - Décodage tolérant

    private enum CodingKeys: String, CodingKey { case records }

    /// Une entrée illisible est ignorée (et loggée) au lieu de faire échouer
    /// tout le décodage — on ne perd pas l'historique pour un verset corrompu.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lossy = try container.decodeIfPresent([String: LossyRecord].self, forKey: .records) ?? [:]
        var records: [String: AyahPracticeRecord] = [:]
        for (key, entry) in lossy {
            if let record = entry.record {
                records[key] = record
            } else {
                Self.logger.error("Entrée de progression illisible ignorée : \(key, privacy: .public)")
            }
        }
        self.records = records
    }

    private nonisolated struct LossyRecord: Decodable {
        let record: AyahPracticeRecord?

        init(from decoder: Decoder) throws {
            record = try? AyahPracticeRecord(from: decoder)
        }
    }
}

// MARK: - Persistance

enum RecitationProgressStore {

    static let storageKey = "recitation_progress"

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "RecitationProgress")

    static func load(from defaults: UserDefaults = .standard) -> RecitationProgress {
        guard let data = defaults.data(forKey: storageKey) else { return RecitationProgress() }
        do {
            return try JSONDecoder().decode(RecitationProgress.self, from: data)
        } catch {
            logger.error("recitation_progress illisible, progression réinitialisée : \(error.localizedDescription, privacy: .public)")
            return RecitationProgress()
        }
    }

    static func save(_ progress: RecitationProgress, to defaults: UserDefaults = .standard) {
        do {
            defaults.set(try JSONEncoder().encode(progress), forKey: storageKey)
        } catch {
            logger.error("Échec d'encodage de recitation_progress : \(error.localizedDescription, privacy: .public)")
        }
    }
}
