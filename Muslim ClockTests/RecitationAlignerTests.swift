//
//  RecitationAlignerTests.swift
//  Muslim ClockTests
//
//  Tests de l'aligneur de récitation (Needleman-Wunsch + trigrammes), du
//  coach et des données de riwaya bundlées.
//

import Foundation
import Testing
@testable import Muslim_Clock

struct RecitationAlignerTests {

    // MARK: - Fixtures

    private static let ikhlas = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 112, ayahTexts: [
        1: "قُلْ هُوَ اللَّهُ أَحَدٌ",
        2: "اللَّهُ الصَّمَدُ",
        3: "لَمْ يَلِدْ وَلَمْ يُولَدْ",
        4: "وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ",
    ])

    private static let fatihaStart = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 1, ayahTexts: [
        1: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        2: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
    ])

    /// Ar-Rahman 13–16 : le refrain revient en 13 et 16.
    private static let rahmanRefrain = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 55, ayahTexts: [
        13: "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ",
        14: "خَلَقَ الْإِنْسَانَ مِنْ صَلْصَالٍ كَالْفَخَّارِ",
        15: "وَخَلَقَ الْجَانَّ مِنْ مَارِجٍ مِنْ نَارٍ",
        16: "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ",
    ])

    private static let ikhlasText = "قل هو الله احد الله الصمد لم يلد ولم يولد ولم يكن له كفوا احد"

    private func align(_ reference: RecitationReference, _ text: String) -> RecitationAlignment {
        RecitationAligner.align(reference: reference,
                                transcript: .fromPlainText(text),
                                equivalences: .empty)
    }

    private func kinds(_ alignment: RecitationAlignment) -> [AlignedWordKind] {
        alignment.items.map(\.kind)
    }

    // MARK: - Récitation parfaite

    @Test func perfectRecitationMatchesEveryWord() {
        let result = align(Self.ikhlas, Self.ikhlasText)
        #expect(result.items.count == Self.ikhlas.words.count)
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.accuracy == 1)
        #expect(!result.isLowConfidence)
        #expect(result.hesitations.isEmpty)
    }

    @Test func referenceWordsSkipPauseMarksAndIndexFromZero() {
        let reference = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 2, ayahTexts: [
            2: "ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِلْمُتَّقِينَ",
        ])
        #expect(reference.words.map(\.normalized) == ["ذلك", "الكتاب", "لا", "ريب", "فيه", "هدي", "للمتقين"])
        #expect(reference.words.map(\.index) == Array(0..<7))
        #expect(reference.ayahRange == 2...2)
    }

    // MARK: - Erreurs de mots

    @Test func omissionIsDetected() {
        // « الصمد » oublié.
        let result = align(Self.ikhlas, "قل هو الله احد الله لم يلد ولم يولد ولم يكن له كفوا احد")
        let omitted = result.items.filter { $0.kind == .omitted }
        #expect(omitted.count == 1)
        #expect(omitted.first?.reference?.normalized == "الصمد")
        #expect(omitted.first?.reference?.ayah == 2)
        #expect(omitted.first?.heard == nil)
        #expect(abs(result.accuracy - 14.0 / 15.0) < 0.0001)
    }

    @Test func substitutionIsDetected() {
        // « يولد » remplacé par « يكتب » (aucun trigramme commun hors bord).
        let result = align(Self.ikhlas, "قل هو الله احد الله الصمد لم يلد ولم يكتب ولم يكن له كفوا احد")
        let substituted = result.items.filter { $0.kind == .substituted }
        #expect(substituted.count == 1)
        #expect(substituted.first?.reference?.normalized == "يولد")
        #expect(substituted.first?.heard?.normalized == "يكتب")
        #expect(result.items.count == Self.ikhlas.words.count)
    }

    @Test func closeWordIsApproximate() {
        // « كفوا » prononcé « كفو » : proche sans être identique.
        let score = RecitationAligner.similarity("كفوا", "كفو")
        #expect(score >= RecitationAligner.approximateThreshold && score < RecitationAligner.matchThreshold)
        let result = align(Self.ikhlas, "قل هو الله احد الله الصمد لم يلد ولم يولد ولم يكن له كفو احد")
        #expect(result.items.filter { $0.kind == .approximate }.map(\.reference?.normalized) == ["كفوا"])
        #expect(abs(result.accuracy - 14.5 / 15.0) < 0.0001)
    }

    @Test func insertionIsDetected() {
        // « سبحان » ajouté au milieu.
        let result = align(Self.ikhlas, "قل هو الله احد سبحان الله الصمد لم يلد ولم يولد ولم يكن له كفوا احد")
        let inserted = result.items.filter { $0.kind == .inserted }
        #expect(inserted.count == 1)
        #expect(inserted.first?.heard?.normalized == "سبحان")
        #expect(inserted.first?.reference == nil)
        #expect(result.accuracy == 1)
    }

    @Test func repetitionIsDetected() {
        // « لم يلد » repris deux fois.
        let result = align(Self.ikhlas, "قل هو الله احد الله الصمد لم يلد لم يلد ولم يولد ولم يكن له كفوا احد")
        let repeated = result.items.filter { $0.kind == .repeated }
        #expect(repeated.map(\.heard?.normalized) == ["لم", "يلد"])
        #expect(!result.items.contains { $0.kind == .inserted })
        #expect(result.accuracy == 1)
    }

    // MARK: - Basmala et ta'awwudh

    @Test func leadingBasmalaIsIgnoredOutsideFatiha() {
        let result = align(Self.ikhlas, "بسم الله الرحمن الرحيم " + Self.ikhlasText)
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.heardCount == Self.ikhlas.words.count)
    }

    @Test func leadingTaawwudhAndBasmalaAreIgnored() {
        let result = align(Self.ikhlas, "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم " + Self.ikhlasText)
        #expect(result.items.allSatisfy { $0.kind == .matched })
    }

    @Test func basmalaIsKeptWhenItIsTheFirstVerse() {
        let result = align(Self.fatihaStart, "بسم الله الرحمن الرحيم الحمد لله رب العالمين")
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.items.first?.reference?.ayah == 1)
    }

    @Test func basmalaBeforeAtTawbaIsReported() {
        let tawba = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 9, ayahTexts: [
            1: "بَرَاءَةٌ مِنَ اللَّهِ وَرَسُولِهِ إِلَى الَّذِينَ عَاهَدْتُمْ مِنَ الْمُشْرِكِينَ",
        ])
        let result = align(tawba, "بسم الله الرحمن الرحيم براءه من الله ورسوله الي الذين عاهدتم من المشركين")
        #expect(result.items.prefix(4).allSatisfy { $0.kind == .inserted })
        #expect(result.items.dropFirst(4).allSatisfy { $0.kind == .matched })
    }

    // MARK: - Versets identiques

    @Test func identicalVersesKeepTheirOwnNumbers() {
        let full = "فبأي آلاء ربكما تكذبان خلق الإنسان من صلصال كالفخار وخلق الجان من مارج من نار فبأي آلاء ربكما تكذبان"
        let perfect = align(Self.rahmanRefrain, full)
        #expect(perfect.items.allSatisfy { $0.kind == .matched })
        #expect(perfect.items.compactMap(\.reference?.ayah) == Self.rahmanRefrain.words.map(\.ayah))

        // Versets 14–15 sautés : les omissions leur sont attribuées, pas au refrain.
        let skipped = align(Self.rahmanRefrain, "فبأي آلاء ربكما تكذبان فبأي آلاء ربكما تكذبان")
        let omittedAyahs = Set(skipped.items.filter { $0.kind == .omitted }.compactMap(\.reference?.ayah))
        #expect(omittedAyahs == [14, 15])
        #expect(skipped.items.filter { $0.kind == .matched }.compactMap(\.reference?.ayah) == [13, 13, 13, 13, 16, 16, 16, 16])
    }

    // MARK: - Confiance

    @Test func tooFewHeardWordsIsLowConfidence() {
        let result = align(Self.ikhlas, "قل هو")
        #expect(result.heardCount == 2)
        #expect(result.isLowConfidence)
    }

    @Test func unrelatedSpeechIsLowConfidence() {
        let result = align(Self.ikhlas, "اليوم الطقس جميل جدا في المدينه")
        #expect(result.accuracy < 0.3)
        #expect(result.isLowConfidence)
        let tips = RecitationCoach.tips(for: result, reference: Self.ikhlas)
        #expect(tips.map(\.kind) == [.lowConfidence])
    }

    @Test func emptyTranscriptIsLowConfidence() {
        let result = align(Self.ikhlas, "")
        #expect(result.items.allSatisfy { $0.kind == .omitted })
        #expect(result.accuracy == 0)
        #expect(result.isLowConfidence)
    }

    // MARK: - Hésitations

    @Test func pauseInsideVerseIsAHesitation() {
        // Ayah 1 d'un trait, pause de 5 s après « لم » (ayah 3, mot 0), puis la suite.
        let transcript = RecitationTranscript.fromSegments([
            ("قل هو الله احد", 0.0...2.0),
            ("الله الصمد", 3.0...4.0),     // pause 1 s entre versets : rien
            ("لم", 4.5...5.0),
            ("يلد ولم يولد", 10.0...12.0), // pause 5 s au milieu du verset 3
            ("ولم يكن له كفوا احد", 16.0...19.0), // pause 4 s mais entre versets 3 et 4
        ])
        let result = RecitationAligner.align(reference: Self.ikhlas, transcript: transcript, equivalences: .empty)
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.hesitations.count == 1)
        #expect(result.hesitations.first?.ayah == 3)
        #expect(result.hesitations.first?.afterWordIndex == 0)
        #expect(abs((result.hesitations.first?.gap ?? 0) - 5.0) < 0.0001)

        let tips = RecitationCoach.tips(for: result, reference: Self.ikhlas)
        #expect(tips.map(\.kind) == [.hesitation])
        #expect(tips.first?.ayah == 3)
    }

    @Test func segmentDurationIsSpreadOverWords() {
        let transcript = RecitationTranscript.fromSegments([("قل هو", 0.0...4.0)])
        #expect(transcript.tokens.count == 2)
        #expect(transcript.tokens[0].timeRange == 0.0...2.0)
        #expect(transcript.tokens[1].timeRange == 2.0...4.0)
    }

    @Test func plainTextHasNoTimestampsNoHesitation() {
        let result = align(Self.ikhlas, Self.ikhlasText)
        #expect(result.items.allSatisfy { $0.heard?.timeRange == nil })
        #expect(result.hesitations.isEmpty)
    }

    // MARK: - Coach

    @Test func coachReportsErrorsInReadingOrder() {
        // « هو » omis (v.1), « يولد » → « يكتب » (v.3).
        let result = align(Self.ikhlas, "قل الله احد الله الصمد لم يلد ولم يكتب ولم يكن له كفوا احد")
        let tips = RecitationCoach.tips(for: result, reference: Self.ikhlas)
        #expect(tips.map(\.kind) == [.omitted, .substituted])
        #expect(tips.map(\.ayah) == [1, 3])
        #expect(tips.map(\.id) == [0, 1])
    }

    @Test func coachGroupsConsecutiveOmissions() {
        // Verset 4 entier oublié → un seul conseil.
        let result = align(Self.ikhlas, "قل هو الله احد الله الصمد لم يلد ولم يولد")
        let tips = RecitationCoach.tips(for: result, reference: Self.ikhlas)
        #expect(tips.map(\.kind) == [.omitted])
        #expect(tips.first?.ayah == 4)
        #expect(tips.first?.wordIndex == 0)
    }

    @Test func coachCapsTheNumberOfTips() {
        // Un mot sur deux remplacé par un mot sans rapport.
        let result = align(Self.ikhlas, "قل زيت الله شمس الله قمر لم بحر ولم نهر ولم جبل له كفوا احد")
        let tips = RecitationCoach.tips(for: result, reference: Self.ikhlas)
        #expect(tips.count == RecitationCoach.maxTips)
    }

    @Test func coachCongratulatesAPerfectRecitation() {
        let result = align(Self.ikhlas, Self.ikhlasText)
        #expect(RecitationCoach.tips(for: result, reference: Self.ikhlas).map(\.kind) == [.perfect])
    }

    // MARK: - Équivalences de graphie

    @Test func equivalenceTableHandlesProclitics() {
        let table = RecitationEquivalences(pairs: [("اليل", "الليل")])
        #expect(table.canonical("اليل") == "الليل")
        #expect(table.canonical("واليل") == "والليل")
        #expect(table.canonical("والليل") == "والليل")
    }

    @Test func uthmaniSuperscriptAlefMatchesDictation() {
        // Graphie KFGQPC Warsh (rasm uthmani) contre dictée imla'i.
        let warsh = RecitationReferenceLoader.makeReference(riwaya: .warsh, surah: 2, ayahTexts: [
            2: "اَ۬لذِينَ يُومِنُونَ بِالْغَيْبِ وَيُقِيمُونَ اَ۬لصَّلَوٰةَ وَمِمَّا رَزَقْنَٰهُمْ يُنفِقُونَۖ",
        ])
        let result = align(warsh, "الذين يؤمنون بالغيب ويقيمون الصلاة ومما رزقناهم ينفقون")
        #expect(result.items.allSatisfy { $0.kind == .matched })
    }

    @Test func realRiwayaDifferenceIsStillReported() {
        // Warsh lit « مَلِكِ » : réciter « مالك » (Hafs) n'est pas un simple écart de graphie.
        let warsh = RecitationReferenceLoader.makeReference(riwaya: .warsh, surah: 1, ayahTexts: [
            3: "مَلِكِ يَوْمِ اِ۬لدِّينِۖ",
        ])
        let result = RecitationAligner.align(reference: warsh, transcript: .fromPlainText("مالك يوم الدين"))
        #expect(result.items.first?.kind != .matched)
    }

    // MARK: - Données bundlées

    @Test func bundledEquivalencesLoad() {
        #expect(RecitationEquivalences.bundled.canonical("السراط") == "الصراط")
        #expect(RecitationEquivalences.bundled.canonical("بالصراط") == "بالصراط")
    }

    @MainActor
    @Test func bundledRiwayatLoadInTheirOwnNumbering() async throws {
        #expect(RecitationReferenceLoader.availableRiwayat() == Riwaya.allCases)
        for riwaya in Riwaya.allCases {
            let names = await RecitationReferenceLoader.surahNames(riwaya: riwaya)
            #expect(names.count == 114)
            var total = 0
            for surah in 1...114 {
                total += await RecitationReferenceLoader.ayahCount(surah: surah, riwaya: riwaya) ?? 0
            }
            #expect(total == riwaya.totalAyahs)
        }
        // Warsh : la Fatiha commence à « الحمد » (basmala non comptée).
        let warsh = try await RecitationReferenceLoader.load(riwaya: .warsh, surah: 1, ayahRange: 1...7)
        #expect(warsh.words.first?.normalized == "الحمد")
        #expect(warsh.ayahTexts.count == 7)
    }

    @MainActor
    @Test func loaderRejectsOversizedAndInvalidRanges() async {
        await #expect(throws: RecitationReferenceError.rangeTooLarge(count: 21, maximum: 20)) {
            _ = try await RecitationReferenceLoader.load(riwaya: .hafs, surah: 2, ayahRange: 1...21)
        }
        await #expect(throws: RecitationReferenceError.ayahRangeInvalid(1...5, ayahCount: 4)) {
            _ = try await RecitationReferenceLoader.load(riwaya: .hafs, surah: 112, ayahRange: 1...5)
        }
        await #expect(throws: RecitationReferenceError.surahNotFound(115)) {
            _ = try await RecitationReferenceLoader.load(riwaya: .hafs, surah: 115, ayahRange: 1...1)
        }
    }
}
