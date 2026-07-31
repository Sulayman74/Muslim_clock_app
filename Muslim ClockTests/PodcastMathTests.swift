//
//  PodcastMathTests.swift
//  Muslim ClockTests
//
//  Tests des fonctions pures du lecteur audio (PodcastMath) :
//  progression, navigation épisode, décodage/migration des positions de reprise.
//

import Testing
import Foundation
@testable import Muslim_Clock

struct PodcastMathTests {

    // MARK: - seriesProgress

    @Test func seriesProgressZeroWhenEmpty() {
        #expect(PodcastMath.seriesProgress(playedURLs: ["a"], episodeURLs: []) == 0)
    }

    @Test func seriesProgressCountsOnlyEpisodesInList() {
        // "z" est lu mais n'appartient pas à la série → ignoré.
        let played: Set<String> = ["a", "z"]
        let progress = PodcastMath.seriesProgress(playedURLs: played, episodeURLs: ["a", "b", "c", "d"])
        #expect(abs(progress - 0.25) < 0.0001)
    }

    @Test func seriesProgressFullWhenAllPlayed() {
        let played: Set<String> = ["a", "b"]
        #expect(PodcastMath.seriesProgress(playedURLs: played, episodeURLs: ["a", "b"]) == 1.0)
    }

    @Test func seriesProgressZeroWhenNothingPlayed() {
        #expect(PodcastMath.seriesProgress(playedURLs: [], episodeURLs: ["a", "b"]) == 0)
    }

    // MARK: - nextIndex / previousIndex

    @Test func nextIndexWithinBounds() {
        #expect(PodcastMath.nextIndex(after: 0, count: 3) == 1)
        #expect(PodcastMath.nextIndex(after: 1, count: 3) == 2)
    }

    @Test func nextIndexNilAtEndOrInvalid() {
        #expect(PodcastMath.nextIndex(after: 2, count: 3) == nil) // dernier
        #expect(PodcastMath.nextIndex(after: -1, count: 3) == nil) // invalide
        #expect(PodcastMath.nextIndex(after: 0, count: 0) == nil) // vide
    }

    @Test func previousIndexWithinBounds() {
        #expect(PodcastMath.previousIndex(before: 2, count: 3) == 1)
        #expect(PodcastMath.previousIndex(before: 1, count: 3) == 0)
    }

    @Test func previousIndexNilAtStartOrInvalid() {
        #expect(PodcastMath.previousIndex(before: 0, count: 3) == nil) // premier
        #expect(PodcastMath.previousIndex(before: 5, count: 3) == nil) // hors borne
    }

    // MARK: - decodeResumePositions

    @Test func decodeReturnsEmptyForNil() {
        #expect(PodcastMath.decodeResumePositions(from: nil).isEmpty)
    }

    @Test func decodeReturnsEmptyForGarbage() {
        let garbage = Data("not json".utf8)
        #expect(PodcastMath.decodeResumePositions(from: garbage).isEmpty)
    }

    @Test func decodeRoundTripsNewFormat() {
        let positions = ["https://a.mp3": 12.5, "https://b.mp3": 300.0]
        let data = PodcastMath.encodeResumePositions(positions)
        let decoded = PodcastMath.decodeResumePositions(from: data)
        #expect(decoded == positions)
    }

    @Test func decodeMigratesLegacyBookmark() {
        // Ancien format prod : un seul `ResumeBookmark` encodé. On fournit le JSON
        // verbatim plutôt que de ré-encoder `ResumeBookmark` (dont la conformance
        // Codable est main-actor-isolée), ce qui garde le test nonisolated.
        let json = Data(#"{"episodeURL":"https://old.mp3","position":42,"episodeTitle":"Ancien"}"#.utf8)
        let decoded = PodcastMath.decodeResumePositions(from: json)
        #expect(decoded == ["https://old.mp3": 42.0])
    }

    // MARK: - resumeTarget

    @Test func resumeTargetNilWhenNoLastPlayed() {
        #expect(PodcastMath.resumeTarget(lastPlayedURL: nil, positions: ["a": 100]) == nil)
    }

    @Test func resumeTargetNilWhenUrlAbsentFromPositions() {
        #expect(PodcastMath.resumeTarget(lastPlayedURL: "a", positions: ["b": 100]) == nil)
    }

    @Test func resumeTargetNilWhenBelowMinimum() {
        // Position sous le seuil (5 s) → pas de reprise significative.
        #expect(PodcastMath.resumeTarget(lastPlayedURL: "a", positions: ["a": 3]) == nil)
    }

    @Test func resumeTargetReturnsUrlAndPositionWhenValid() {
        let target = PodcastMath.resumeTarget(lastPlayedURL: "a", positions: ["a": 120.5, "b": 10])
        #expect(target?.url == "a")
        #expect(target?.position == 120.5)
    }

    // MARK: - episodeMatches

    @Test func episodeMatchesEmptyQueryMatchesEverything() {
        #expect(PodcastMath.episodeMatches(title: "Sourate Al-Fatiha", query: ""))
    }

    @Test func episodeMatchesIsCaseAndDiacriticInsensitive() {
        // "hadith" doit matcher "Hadîth" (casse + accent).
        #expect(PodcastMath.episodeMatches(title: "Explication du Hadîth", query: "hadith"))
    }

    @Test func episodeMatchesArabicIgnoringHarakat() {
        // Requête sans harakât doit matcher un titre vocalisé.
        #expect(PodcastMath.episodeMatches(title: "سُورَة", query: "سورة"))
    }

    @Test func episodeMatchesReturnsFalseWhenNoSubstring() {
        #expect(!PodcastMath.episodeMatches(title: "Sourate Al-Baqara", query: "Kahf"))
    }
}
