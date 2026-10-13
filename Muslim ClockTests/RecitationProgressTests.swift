//
//  RecitationProgressTests.swift
//  Muslim ClockTests
//
//  Tests du suivi de progression de la récitation (par verset, par riwaya).
//

import Foundation
import Testing
@testable import Muslim_Clock

struct RecitationProgressTests {

    private static let ikhlas = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 112, ayahTexts: [
        1: "قُلْ هُوَ اللَّهُ أَحَدٌ",
        2: "اللَّهُ الصَّمَدُ",
    ])

    private static let day1 = Date(timeIntervalSince1970: 1_800_000_000)
    private static let day2 = Date(timeIntervalSince1970: 1_800_086_400)

    private func alignment(_ text: String) -> RecitationAlignment {
        RecitationAligner.align(reference: Self.ikhlas, transcript: .fromPlainText(text), equivalences: .empty)
    }

    private var key1: String { RecitationProgress.key(riwaya: .hafs, surah: 112, ayah: 1) }
    private var key2: String { RecitationProgress.key(riwaya: .hafs, surah: 112, ayah: 2) }

    // MARK: - Enregistrement

    @Test func keyEncodesRiwayaSurahAndAyah() {
        #expect(RecitationProgress.key(riwaya: .warsh, surah: 2, ayah: 255) == "warsh:2:255")
    }

    @Test func recordsOneAttemptPerAyah() {
        var progress = RecitationProgress()
        // « هو » omis au verset 1, verset 2 parfait.
        progress.record(alignment: alignment("قل الله احد الله الصمد"), reference: Self.ikhlas, on: Self.day1)

        #expect(progress.records.count == 2)
        #expect(progress.records[key1]?.attempts == 1)
        #expect(progress.records[key1]?.bestAccuracy == 0.75)
        #expect(progress.records[key1]?.weakWordIndexes == [1])
        #expect(progress.records[key1]?.lastDate == Self.day1)
        #expect(progress.records[key2]?.bestAccuracy == 1)
        #expect(progress.records[key2]?.weakWordIndexes == [])
    }

    @Test func keepsBestAccuracyAndLatestWeakWords() {
        var progress = RecitationProgress()
        progress.record(alignment: alignment("قل هو الله احد الله الصمد"), reference: Self.ikhlas, on: Self.day1)
        progress.record(alignment: alignment("قل الله احد الله الصمد"), reference: Self.ikhlas, on: Self.day2)

        let record = progress.records[key1]
        #expect(record?.attempts == 2)
        #expect(record?.bestAccuracy == 1)       // meilleur essai conservé
        #expect(record?.weakWordIndexes == [1])  // état du dernier essai
        #expect(record?.lastDate == Self.day2)
    }

    @Test func lowConfidenceAttemptIsNotRecorded() {
        var progress = RecitationProgress()
        progress.record(alignment: alignment("قل"), reference: Self.ikhlas, on: Self.day1)
        #expect(progress.records.isEmpty)
    }

    // MARK: - Versets à retravailler

    @Test func versesToReworkAreBelowThresholdInMushafOrder() {
        let record = { (accuracy: Double) in
            AyahPracticeRecord(attempts: 1, bestAccuracy: accuracy, lastDate: Self.day1, weakWordIndexes: [])
        }
        let progress = RecitationProgress(records: [
            "warsh:1:2": record(0.5),
            "hafs:2:10": record(0.2),
            "hafs:2:9": record(0.79),
            "hafs:1:1": record(0.8),   // pile au seuil : acquis
            "hafs:112:1": record(1),
        ])
        #expect(progress.versesToRework() == ["hafs:2:9", "hafs:2:10", "warsh:1:2"])
        #expect(progress.versesToRework(threshold: 0.4) == ["hafs:2:10"])
    }

    // MARK: - Persistance

    @MainActor
    @Test func storeRoundTrips() throws {
        let suite = "RecitationProgressTests.roundTrip"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var progress = RecitationProgress()
        progress.record(alignment: alignment("قل الله احد الله الصمد"), reference: Self.ikhlas, on: Self.day1)
        RecitationProgressStore.save(progress, to: defaults)

        #expect(RecitationProgressStore.load(from: defaults) == progress)
    }

    @MainActor
    @Test func storeReturnsEmptyProgressWhenNothingSavedOrCorrupt() throws {
        let suite = "RecitationProgressTests.corrupt"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(RecitationProgressStore.load(from: defaults).records.isEmpty)
        defaults.set(Data("pas du json".utf8), forKey: RecitationProgressStore.storageKey)
        #expect(RecitationProgressStore.load(from: defaults).records.isEmpty)
    }

    @Test func decodingSkipsInvalidEntriesAndToleratesMissingWeakWords() throws {
        let json = """
        {"records": {
            "hafs:1:1": {"attempts": 2, "bestAccuracy": 0.9, "lastDate": 0, "weakWordIndexes": [3]},
            "hafs:1:2": {"attempts": 1, "bestAccuracy": 0.5, "lastDate": 0},
            "hafs:1:3": {"attempts": "beaucoup"},
            "hafs:1:4": 42
        }}
        """
        let progress = try JSONDecoder().decode(RecitationProgress.self, from: Data(json.utf8))
        #expect(progress.records.keys.sorted() == ["hafs:1:1", "hafs:1:2"])
        #expect(progress.records["hafs:1:1"]?.weakWordIndexes == [3])
        #expect(progress.records["hafs:1:2"]?.weakWordIndexes == [])
    }

    @Test func decodingToleratesMissingRecordsKey() throws {
        let progress = try JSONDecoder().decode(RecitationProgress.self, from: Data("{}".utf8))
        #expect(progress.records.isEmpty)
    }
}
