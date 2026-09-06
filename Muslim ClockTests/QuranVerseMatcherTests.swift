//
//  QuranVerseMatcherTests.swift
//  Muslim ClockTests
//
//  Tests du moteur de recherche de versets (index inversé + trigrammes) sur
//  une fixture représentative : Fatiha, refrain répété d'Ar-Rahman, Ikhlas,
//  et un fragment de verset long (Ayat al-Kursi).
//

import Testing
@testable import Muslim_Clock

struct QuranVerseMatcherTests {

    /// Mini-corpus : textes imla'i vocalisés comme dans le corpus bundlé.
    private static let fixture: [(ref: QuranVerseRef, text: String)] = [
        (QuranVerseRef(sura: 1, ayah: 1), "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"),
        (QuranVerseRef(sura: 1, ayah: 2), "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ"),
        (QuranVerseRef(sura: 1, ayah: 5), "إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ"),
        (QuranVerseRef(sura: 1, ayah: 6), "اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ"),
        // Ayat al-Kursi (extrait long)
        (QuranVerseRef(sura: 2, ayah: 255), "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ"),
        // Refrain d'Ar-Rahman — 3 occurrences dans la fixture
        (QuranVerseRef(sura: 55, ayah: 13), "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ"),
        (QuranVerseRef(sura: 55, ayah: 16), "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ"),
        (QuranVerseRef(sura: 55, ayah: 18), "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ"),
        (QuranVerseRef(sura: 112, ayah: 1), "قُلْ هُوَ اللَّهُ أَحَدٌ"),
        (QuranVerseRef(sura: 112, ayah: 2), "اللَّهُ الصَّمَدُ"),
    ]

    private let index = QuranVerseIndex(verses: fixture)

    // MARK: - Matching exact

    @Test func exactQueryFindsVerse() {
        let matches = index.match(query: "الحمد لله رب العالمين")
        #expect(matches.first?.ref == QuranVerseRef(sura: 1, ayah: 2))
        #expect(QuranVerseIndex.isConfident(matches))
    }

    @Test func vocalizedQueryFindsSameVerse() {
        // Requête AVEC harakât (copiée d'un mushaf) → même résultat.
        let matches = index.match(query: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ")
        #expect(matches.first?.ref == QuranVerseRef(sura: 1, ayah: 2))
    }

    // MARK: - Tolérance aux fautes

    @Test func typoStillMatchesViaTrigrams() {
        // « العلمين » sans le premier alef (faute/ASR fréquente)
        let matches = index.match(query: "الحمد لله رب العلمين")
        #expect(matches.first?.ref == QuranVerseRef(sura: 1, ayah: 2))
    }

    // MARK: - Fragments

    @Test func fragmentOfLongVerseMatches() {
        let matches = index.match(query: "لا تأخذه سنة ولا نوم")
        #expect(matches.first?.ref == QuranVerseRef(sura: 2, ayah: 255))
        #expect(QuranVerseIndex.isConfident(matches))
    }

    // MARK: - Occurrences groupées

    @Test func repeatedVerseGroupsOccurrences() throws {
        let matches = index.match(query: "فبأي آلاء ربكما تكذبان")
        // Le refrain domine largement (score 1.0) — des candidats faibles
        // peuvent suivre (partage du mot normalisé « الا »), c'est voulu.
        let match = try #require(matches.first)
        #expect(match.occurrences.count == 3)
        #expect(match.ref == QuranVerseRef(sura: 55, ayah: 13)) // 1re occurrence
        #expect(match.occurrences.contains(QuranVerseRef(sura: 55, ayah: 18)))
        #expect(QuranVerseIndex.isConfident(matches))
        // Le refrain n'apparaît qu'UNE fois (pas 3 lignes pour le même texte).
        #expect(matches.filter { $0.occurrences.count == 3 }.count == 1)
    }

    // MARK: - Basmala

    @Test func basmalaAloneReturnsFatiha() {
        let matches = index.match(query: "بسم الله الرحمن الرحيم")
        #expect(matches.first?.ref == QuranVerseRef(sura: 1, ayah: 1))
    }

    @Test func basmalaPrefixIsIgnored() {
        let matches = index.match(query: "بسم الله الرحمن الرحيم قل هو الله احد")
        #expect(matches.first?.ref == QuranVerseRef(sura: 112, ayah: 1))
    }

    // MARK: - Garde-fous

    @Test func shortQueryReturnsNothing() {
        #expect(index.match(query: "قل هو").isEmpty)
        #expect(index.match(query: "").isEmpty)
        #expect(index.match(query: "hello world abc").isEmpty)
    }

    @Test func unrelatedQueryIsNotConfident() {
        // Mots existants mais dispersés — pas de verset contenant tout.
        let matches = index.match(query: "الحمد الصمد المستقيم")
        #expect(!QuranVerseIndex.isConfident(matches))
    }

    @Test func limitIsRespected() {
        let matches = index.match(query: "الله الحمد لله رب", limit: 2)
        #expect(matches.count <= 2)
    }
}
