//
//  AdhkarModuleTests.swift
//  Muslim ClockTests
//
//  Tests des fonctions pures du module Livret d'invocations :
//  normalisation de recherche, moteur de suggestion contextuelle, filtrage.
//

import Testing
import Foundation
@testable import Muslim_Clock

// MARK: - Fabriques de test

private func makeDhikr(
    id: Int,
    text: String = "",
    arabic: String = "",
    source: String = "",
    benefit: String = "",
    authenticity: String? = "sahih"
) -> Dhikr {
    Dhikr(
        id: id, text: text, arabic: arabic, source: source, repeat: 1,
        timing: nil, prayer: nil, repeatFajrMaghrib: nil,
        benefit: benefit, authenticity: authenticity
    ) // note: `repeat` label géré par le compilateur via l'init mémberwise
}

private func makeCategory(
    id: String,
    moments: [String],
    titleFr: String = "",
    titleAr: String = "",
    adhkar: [Dhikr]
) -> AdhkarCategory {
    AdhkarCategory(
        id: id, titleAr: titleAr, titleFr: titleFr,
        icon: "star", moments: moments, adhkar: adhkar
    )
}

// MARK: - Normalisation de recherche

struct StringSearchTests {

    @Test func foldingRemovesFrenchAccentsAndCase() {
        #expect("Prière".searchFoldedFr == "priere")
        #expect("CONSULTATION".searchFoldedFr == "consultation")
        #expect("À TABLE".searchFoldedFr == "a table")
    }

    @Test func strippedTashkeelRemovesHarakat() {
        // Texte vocalisé → squelette consonantique.
        #expect("الْحَمْدُ".strippedTashkeel == "الحمد")
        #expect("لِلَّهِ".strippedTashkeel == "لله")
    }

    @Test func strippedTashkeelIsIdempotent() {
        let bare = "الحمد لله"
        #expect(bare.strippedTashkeel == bare)
    }
}

// MARK: - Recherche / filtrage

struct AdhkarSearchTests {

    @Test func matchesFrenchIgnoringAccents() {
        let cats = [makeCategory(id: "a", moments: [], adhkar: [
            makeDhikr(id: 1, text: "La prière est lumière")
        ])]
        let r = AdhkarSearch.filter(cats, query: "priere", authenticity: nil)
        #expect(r.count == 1)
        #expect(r[0].adhkar.map(\.id) == [1])
    }

    @Test func matchesArabicIgnoringHarakat() {
        let cats = [makeCategory(id: "a", moments: [], adhkar: [
            makeDhikr(id: 1, arabic: "الْحَمْدُ لِلَّهِ")
        ])]
        let r = AdhkarSearch.filter(cats, query: "الحمد", authenticity: nil)
        #expect(r.count == 1)
    }

    @Test func authenticityFilterExcludesOtherLevels() {
        let cats = [makeCategory(id: "a", moments: [], adhkar: [
            makeDhikr(id: 1, authenticity: "sahih"),
            makeDhikr(id: 2, authenticity: "hasan")
        ])]
        let r = AdhkarSearch.filter(cats, query: "", authenticity: "hasan")
        #expect(r.count == 1)
        #expect(r[0].adhkar.map(\.id) == [2])
    }

    @Test func emptyQueryAndNoFilterReturnsEverything() {
        let cats = [makeCategory(id: "a", moments: [], adhkar: [
            makeDhikr(id: 1), makeDhikr(id: 2)
        ])]
        let r = AdhkarSearch.filter(cats, query: "   ", authenticity: nil)
        #expect(r.count == 1)
        #expect(r[0].adhkar.count == 2)
    }

    @Test func titleMatchKeepsAllAdhkarOfCategory() {
        let cats = [makeCategory(id: "a", moments: [], titleFr: "Le voyage", adhkar: [
            makeDhikr(id: 1, text: "aaa"), makeDhikr(id: 2, text: "bbb")
        ])]
        let r = AdhkarSearch.filter(cats, query: "voyage", authenticity: nil)
        #expect(r.count == 1)
        #expect(r[0].adhkar.count == 2)
    }

    @Test func noMatchYieldsEmptyResult() {
        let cats = [makeCategory(id: "a", moments: [], titleFr: "Voyage", adhkar: [
            makeDhikr(id: 1, text: "xyz")
        ])]
        let r = AdhkarSearch.filter(cats, query: "zzznotfound", authenticity: nil)
        #expect(r.isEmpty)
    }
}

// MARK: - Suggestion contextuelle

struct AdhkarSuggestionTests {

    /// Instant fixe pour des tests déterministes (indépendants de l'horloge).
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func adhanResponseActiveAtPrayerTime() {
        let m = AdhkarSuggestion.activeMoments(
            now: base, prayerDates: [base], fajr: nil, lastThirdOfNight: nil
        )
        #expect(m.contains(AdhkarMoment.adhanResponse))
    }

    @Test func wuduAndMosqueBeforePrayerNotAtAdhan() {
        let now = base.addingTimeInterval(-10 * 60) // 10 min avant la prière
        let m = AdhkarSuggestion.activeMoments(
            now: now, prayerDates: [base], fajr: nil, lastThirdOfNight: nil
        )
        #expect(m.contains(AdhkarMoment.wudu))
        #expect(m.contains(AdhkarMoment.mosque))
        #expect(!m.contains(AdhkarMoment.adhanResponse)) // hors fenêtre ±5 min
    }

    @Test func qiyamAndWuduDuringLastThirdOfNight() {
        let fajr = base.addingTimeInterval(3600)
        let lastThird = base.addingTimeInterval(-3600)
        let m = AdhkarSuggestion.activeMoments(
            now: base, prayerDates: [], fajr: fajr, lastThirdOfNight: lastThird
        )
        #expect(m.contains(AdhkarMoment.qiyam))
        #expect(m.contains(AdhkarMoment.wudu))
    }

    @Test func wakeShortlyAfterFajr() {
        let now = base.addingTimeInterval(30 * 60)
        let m = AdhkarSuggestion.activeMoments(
            now: now, prayerDates: [], fajr: base, lastThirdOfNight: nil
        )
        #expect(m.contains(AdhkarMoment.wake))
    }

    @Test func suggestedKeepsOnlyMatchingCategories() {
        let cats = [
            makeCategory(id: "wudu", moments: ["wudu"], adhkar: [makeDhikr(id: 1)]),
            makeCategory(id: "eating", moments: ["eating"], adhkar: [makeDhikr(id: 2)])
        ]
        let now = base.addingTimeInterval(-10 * 60) // fenêtre ablutions
        let s = AdhkarSuggestion.suggested(
            from: cats, now: now, prayerDates: [base], fajr: nil, lastThirdOfNight: nil
        )
        #expect(s.map(\.id).contains("wudu"))
        #expect(!s.map(\.id).contains("eating"))
    }

    @Test func eventBasedCategoriesNeverAutoSuggested() {
        // `toilet`/`house`/`travel`… n'ont pas de déclencheur horaire.
        let cats = [makeCategory(id: "toilet", moments: ["toilet"], adhkar: [makeDhikr(id: 1)])]
        let s = AdhkarSuggestion.suggested(
            from: cats, now: base, prayerDates: [base], fajr: base, lastThirdOfNight: nil
        )
        #expect(s.isEmpty)
    }
}
