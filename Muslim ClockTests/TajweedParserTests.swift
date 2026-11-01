//
//  TajweedParserTests.swift
//  Muslim ClockTests
//
//  Parser du balisage `quran-tajweed` (api.alquran.cloud) et familles de règles.
//

import Foundation
import Testing
@testable import Muslim_Clock

struct TajweedParserTests {

    /// Fâtiha 1:2 telle que livrée par l'édition (extrait représentatif).
    private static let fatiha2 = "[h:1[ٱ]لْحَمْدُ لِلَّهِ رَبِّ [h:2[ٱ]لْعَ[n:3[ا]لَمِينَ"

    @Test func parsesAnnotatedSegmentsAndKeepsPlainText() {
        let runs = TajweedParser.runs(from: Self.fatiha2)
        #expect(runs.plainText == "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَالَمِينَ")
        #expect(runs.first == TajweedRun(text: "ٱ", rule: .hamzatWasl))
        #expect(runs.contains(TajweedRun(text: "ا", rule: .maddNormal)))
        #expect(runs.filter { $0.rule == nil }.count == 3)
    }

    @Test func parsesShortMarkersWithoutIdentifier() {
        // Forme réellement livrée par l'API (constatée sur l'appareil) : pas de « :id ».
        let runs = TajweedParser.runs(from: "بِسْمِ [l[ٱ]للَّهِ [h[ٱ][l[ل]رَّحْمَ[n[ـٰ]نِ")
        #expect(runs.plainText == "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ")
        #expect(runs.filter { $0.rule != nil }.count == 4)
        #expect(runs.contains(TajweedRun(text: "ل", rule: .lamShamsiyya)))
        #expect(runs.contains(TajweedRun(text: "ـٰ", rule: .maddNormal)))
        #expect(!runs.plainText.contains("["))
    }

    @Test func leadingCombiningMarksStayWithTheirLetter() {
        // Donnée réelle : `رَّح[p[ِي]مِ` — la kasra de ح ouvre le segment du madd.
        // Elle doit rester avec ح (run précédent), le madd ne colore que le ي.
        let runs = TajweedParser.runs(from: "رَّح[p[ِي]مِ")
        #expect(runs == [
            TajweedRun(text: "رَّحِ", rule: nil),
            TajweedRun(text: "ي", rule: .maddPermissible),
            TajweedRun(text: "مِ", rule: nil),
        ])
        #expect(runs.plainText == "رَّحِيمِ")
        // Aucun run ne commence par un signe combinant.
        #expect(runs.dropFirst().allSatisfy { run in
            run.text.unicodeScalars.first.map { $0.properties.generalCategory != .nonspacingMark } ?? true
        })
    }

    @Test func trailingMarkAfterSegmentIsAttachedToIt() {
        // Le sukûn qui suit `[q[ق]` appartient au ق coloré ; le run vide disparaît.
        let runs = TajweedParser.runs(from: "[q[ق]ْ هو")
        #expect(runs.first == TajweedRun(text: "قْ", rule: .qalqala))
        #expect(runs.plainText == "قْ هو")
        #expect(!runs.contains { $0.text.isEmpty })
    }

    @Test func arabicLetterAfterBracketIsNotAMarker() {
        // Un crochet suivi d'une lettre arabe n'est pas un marqueur de règle.
        let runs = TajweedParser.runs(from: "[ق[ل] هو")
        #expect(runs.plainText == "[ق[ل] هو")
    }

    @Test func unknownRuleLetterKeepsTextWithoutRule() {
        let runs = TajweedParser.runs(from: "قُ[z:9[لْ] هُوَ")
        #expect(runs.plainText == "قُلْ هُوَ")
        #expect(runs.contains(TajweedRun(text: "لْ", rule: nil)))
    }

    @Test func malformedBracketsAreLiteral() {
        // Pas de marqueur valide → texte conservé tel quel.
        let runs = TajweedParser.runs(from: "[x] [1:2[a] [h:1 text")
        #expect(runs.plainText == "[x] [1:2[a] [h:1 text")
        #expect(runs.allSatisfy { $0.rule == nil })
    }

    @Test func familiesAreGroupedAndOrdered() {
        let runs = TajweedParser.runs(from: "[q:1[ق] [n:2[ا] [f:3[ن] [h:4[ٱ] [a:5[ن]")
        #expect(runs.families == [.madd, .ghunna, .qalqala, .ikhfa, .silent])
        #expect(TajweedRule.maddObligatory.family == .madd)
        #expect(TajweedRule.idghamWithoutGhunna.family == .ghunna)
        #expect(TajweedRule.lamShamsiyya.family == .silent)
    }

    @Test func leadingBasmalaIsStrippedAcrossRuns() {
        // Verset 1 d'une sourate : la basmala est collée devant, avec des
        // marqueurs à cheval sur ses mots.
        let markup = "بِسْمِ [h:1[ٱ]للَّهِ [h:2[ٱ]لرَّحْمَ[n:3[ـٰ]نِ [h:4[ٱ]لرَّحِيمِ [h:5[ٱ]لْحَمْدُ لِلَّهِ"
        let stripped = TajweedParser.strippingLeadingBasmala(TajweedParser.runs(from: markup))
        #expect(stripped.plainText == "ٱلْحَمْدُ لِلَّهِ")
        #expect(stripped.first?.rule == .hamzatWasl)
    }

    @Test func basmalaAloneOrAbsentIsUntouched() {
        let alone = TajweedParser.runs(from: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
        #expect(TajweedParser.strippingLeadingBasmala(alone) == alone)
        let absent = TajweedParser.runs(from: Self.fatiha2)
        #expect(TajweedParser.strippingLeadingBasmala(absent) == absent)
    }
}
