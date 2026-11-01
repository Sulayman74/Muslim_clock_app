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

    // MARK: - Fusion / scission (artefacts de la dictée)

    @Test func mergedWordsAreStillMatched() {
        // La dictée colle « يا أيها » en « ياأيها » : deux mots de référence,
        // un mot entendu — aucun des deux ne doit être compté faux.
        let baqara = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 2, ayahTexts: [
            21: "يَا أَيُّهَا النَّاسُ اعْبُدُوا رَبَّكُمُ",
        ])
        let result = align(baqara, "ياأيها الناس اعبدوا ربكم")
        #expect(result.items.count == baqara.words.count)
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.accuracy == 1)
        // Les deux premiers mots partagent le même mot entendu.
        #expect(result.items[0].heard == result.items[1].heard)
    }

    @Test func splitWordIsStillMatched() {
        // La dictée coupe « ولم » en « و لم ».
        let result = align(Self.ikhlas, "قل هو الله احد الله الصمد لم يلد و لم يولد ولم يكن له كفوا احد")
        #expect(result.items.count == Self.ikhlas.words.count)
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.accuracy == 1)
        let glued = result.items.first { $0.reference?.normalized == "ولم" }
        #expect(glued?.heard?.text == "و لم")
    }

    @Test func fusionNeverHidesARealSubstitution() {
        // « الصمد » remplacé par deux mots sans rapport : pas de recollage artificiel.
        let result = align(Self.ikhlas, "قل هو الله احد الله شمس قمر لم يلد ولم يولد ولم يكن له كفوا احد")
        #expect(result.items.contains { $0.kind == .substituted || $0.kind == .inserted })
        #expect(result.accuracy < 1)
        #expect(!result.items.contains { $0.reference?.normalized == "الصمد" && $0.kind == .matched })
    }

    @Test func splitTokenKeepsUnionOfTimeRanges() {
        let transcript = RecitationTranscript.fromSegments([
            ("قل هو الله احد الله الصمد لم يلد", 0.0...4.0),
            ("و", 4.5...4.7),
            ("لم يولد ولم يكن له كفوا احد", 4.8...8.0),
        ])
        let result = RecitationAligner.align(reference: Self.ikhlas, transcript: transcript, equivalences: .empty)
        let glued = result.items.first { $0.reference?.normalized == "ولم" && $0.reference?.ayah == 3 }
        #expect(glued?.kind == .matched)
        #expect(glued?.heard?.timeRange?.lowerBound == 4.5)
        #expect(result.hesitations.isEmpty)
    }

    // MARK: - Indices de vocabulaire (calibrage de l'écoute)

    @Test func recognitionHintsAreDictationFormsLongestFirst() {
        let hints = Self.fatihaStart.recognitionHints
        // Graphie de dictée : harakât retirés, hamzas et alef suscrit traités comme la dictée les écrit.
        #expect(hints.contains("الرحمن"))
        #expect(hints.contains("الحمد"))
        #expect(!hints.contains { $0.unicodeScalars.contains("\u{064E}") })
        // Dédoublonné (« الله » apparaît deux fois dans la référence) et les plus longs d'abord.
        #expect(hints.filter { $0 == "الله" }.count == 1)
        #expect(hints.first?.count == hints.map(\.count).max())
        #expect(hints.count <= RecitationReference.maxRecognitionHints)
    }

    @Test func recognitionHintsAreCappedAtOneHundred() {
        var texts: [Int: String] = [:]
        for ayah in 1...20 {
            texts[ayah] = (1...8).map { "كلمة\(ayah)\($0)" }.joined(separator: " ")
        }
        let reference = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 2, ayahTexts: texts)
        #expect(reference.recognitionHints.count == RecitationReference.maxRecognitionHints)
    }

    @Test func dictationFormKeepsHamzaButDropsMarks() {
        #expect(QuranSearchNormalizer.dictationForm("أَحَدٌ") == "أحد")
        #expect(QuranSearchNormalizer.dictationForm("ٱلْحَمْدُ") == "الحمد")
        #expect(QuranSearchNormalizer.dictationForm("يُنفِقُونَۖ") == "ينفقون")
        #expect(QuranSearchNormalizer.dictationForm("الرَّحْمَٰنِ") == "الرحمن")
        // Contrairement à `tokens`, la graphie n'est pas unifiée.
        #expect(QuranSearchNormalizer.dictationForm("مُؤْمِنِينَ") == "مؤمنين")
        #expect(QuranSearchNormalizer.tokens("مُؤْمِنِينَ") == ["مومنين"])
    }

    // MARK: - Calibration : formes du récitateur (deuxième référence)

    /// Al-Anfal 1 (extrait) : ce que le moteur a réellement produit sur
    /// l'utilisatrice — et, par hypothèse, sur le récitateur.
    private static let anfal = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 8, ayahTexts: [
        1: "فَاتَّقُوا اللَّهَ وَأَصْلِحُوا ذَاتَ بَيْنِكُمْ وَأَطِيعُوا اللَّهَ وَرَسُولَهُ",
    ])

    @Test func reciterFormsMakeEngineArtifactsExactMatches() {
        // Le moteur rend « فاتقوا » → « فتق » et « وأصلحوا » → « واصلح » chez le
        // récitateur : reproduire ces formes, c'est réciter comme lui → JUSTE.
        let calibration = RecitationCalibration(
            unjudgeable: [AyahWordKey(ayah: 1, index: 5)],   // وأطيعوا avalé chez le récitateur
            reciterForms: [AyahWordKey(ayah: 1, index: 0): "فتق", AyahWordKey(ayah: 1, index: 2): "واصلح"]
        )
        let result = RecitationAligner.align(
            reference: Self.anfal,
            transcript: .fromPlainText("فتق الله وأصلح ذات بينكم الله ورسوله"),
            calibration: calibration
        )
        let kinds = result.items.compactMap { $0.reference != nil ? $0.kind : nil }
        #expect(kinds == [.matched, .matched, .matched, .matched, .matched, .unverifiable, .matched, .matched])
        #expect(result.accuracy == 1)
    }

    @Test func reciterFormIsPositionSpecific() {
        // La forme « فتق » n'est acceptée qu'à SA position : ailleurs, « فتق »
        // reste jugé normalement.
        let calibration = RecitationCalibration(reciterForms: [AyahWordKey(ayah: 1, index: 0): "فتق"])
        let result = RecitationAligner.align(
            reference: Self.anfal,
            transcript: .fromPlainText("فتق الله فتق ذات بينكم وأطيعوا الله ورسوله"),
            calibration: calibration
        )
        #expect(result.items[0].kind == .matched)
        #expect(result.items[2].kind != .matched)   // « وأصلحوا » remplacé par « فتق »
    }

    @Test func calibrationRecordClassifiesReciterAlignment() {
        // Alignement « récitateur vs texte » simulé : فتق (approx. squelette),
        // واصلح (approx.), وأطيعوا omis.
        let alignment = align(Self.anfal, "فتق الله وأصلح ذات بينكم الله ورسوله")
        let record = RecitationCalibrator.record(from: alignment, wordCount: Self.anfal.words.count)
        #expect(record.missed == [5])
        #expect(record.forms["0"] == "فتق")
        #expect(record.forms["2"] == "واصلح")
        #expect(record.forms.count == 2)

        var calibration = RecitationCalibration()
        calibration.merge(record, ayah: 1)
        #expect(calibration.unjudgeable == [AyahWordKey(ayah: 1, index: 5)])
        #expect(calibration.reciterForms[AyahWordKey(ayah: 1, index: 0)] == "فتق")
    }

    @Test func calibrationRecordRefusesAnUnusableEngine() {
        // Plus de la moitié des mots ratés sur l'audio parfait → verset inutilisable.
        let alignment = align(Self.anfal, "زيت شمس قمر")
        let record = RecitationCalibrator.record(from: alignment, wordCount: Self.anfal.words.count)
        #expect(record.unusable)
        #expect(record.missed.isEmpty)
        #expect(record.forms.isEmpty)

        var calibration = RecitationCalibration()
        calibration.merge(record, ayah: 1)
        #expect(calibration.unusableAyahs == [1])
        #expect(calibration.unjudgeable.isEmpty)
    }

    @Test func unusableAyahBecomesUnverifiableInsteadOfRed() {
        // Le moteur n'entend rien de fiable sur ce verset chez le récitateur :
        // les erreurs de l'utilisateur y deviennent grises, les mots justes restent blancs.
        var calibration = RecitationCalibration(status: .ready)
        calibration.unusableAyahs = [1]
        let result = RecitationAligner.align(
            reference: Self.anfal,
            transcript: .fromPlainText("فاتقوا الله زيت ذات بينكم الله ورسوله"),
            calibration: calibration
        )
        #expect(!result.items.contains { $0.kind == .omitted || $0.kind == .substituted })
        #expect(result.items.contains { $0.kind == .unverifiable })
        #expect(result.items.first?.kind == .matched)
        #expect(result.accuracy == 1)
    }

    // MARK: - Calibration (mots non vérifiables)

    @Test func unjudgeableWordIsForgivenAndLeavesTheDenominator() {
        // « الصمد » (v.2, index 1) omis, mais le moteur le rate aussi chez le
        // récitateur → non vérifiable, score 100 % sur le reste.
        let result = align(Self.ikhlas, "قل هو الله احد الله لم يلد ولم يولد ولم يكن له كفوا احد")
            .applyingUnjudgeable([AyahWordKey(ayah: 2, index: 1)])
        #expect(result.items.filter { $0.kind == .unverifiable }.count == 1)
        #expect(!result.items.contains { $0.kind == .omitted })
        #expect(result.accuracy == 1)
        #expect(result.hasUnverifiableWords)
        // Le coach n'a plus rien à signaler.
        #expect(RecitationCoach.tips(for: result, reference: Self.ikhlas).map(\.kind) == [.perfect])
    }

    @Test func calibrationNeverUpgradesAMatchedOrUnrelatedWord() {
        // Mot juste + clé calibrée dessus : il reste « matched ».
        let perfect = align(Self.ikhlas, Self.ikhlasText)
            .applyingUnjudgeable([AyahWordKey(ayah: 1, index: 0)])
        #expect(perfect.items.allSatisfy { $0.kind == .matched })
        #expect(perfect.accuracy == 1)

        // Vraie omission sur un mot NON calibré : toujours signalée.
        let result = align(Self.ikhlas, "قل هو الله احد الله لم يلد ولم يولد ولم يكن له كفوا احد")
            .applyingUnjudgeable([AyahWordKey(ayah: 4, index: 2)])
        #expect(result.items.contains { $0.kind == .omitted && $0.reference?.normalized == "الصمد" })
        #expect(result.accuracy < 1)
    }

    @Test func unjudgeableWordsLeaveProgressDenominator() {
        // Omission pardonnée → l'essai est enregistré à 100 % pour ce verset.
        let alignment = align(Self.ikhlas, "قل هو الله احد الله لم يلد ولم يولد ولم يكن له كفوا احد")
            .applyingUnjudgeable([AyahWordKey(ayah: 2, index: 1)])
        var progress = RecitationProgress()
        progress.record(alignment: alignment, reference: Self.ikhlas)
        let key = RecitationProgress.key(riwaya: .hafs, surah: 112, ayah: 2)
        #expect(progress.records[key]?.bestAccuracy == 1)
        #expect(progress.records[key]?.weakWordIndexes.isEmpty == true)
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

    // MARK: - Squelette consonantique (voyelles longues avalées)

    @Test func swallowedLongVowelsAreApproximateNotSubstituted() {
        // Cas réel (Al-Anfal 1) : « فَاتَّقُوا » entendu « فتق » — le moteur
        // avale les madd. Même squelette ف-ت-ق → approximatif, pas « autre mot ».
        let anfal = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 8, ayahTexts: [
            1: "فَاتَّقُوا اللَّهَ وَأَصْلِحُوا ذَاتَ بَيْنِكُمْ",
        ])
        let result = align(anfal, "فتق الله وأصلح ذات بينكم")
        #expect(result.items.first?.kind == .approximate)
        #expect(!result.items.contains { $0.kind == .substituted })
        // « وأصلحوا » entendu « وأصلح » : squelette وصلح == وصلح → approximatif aussi.
        #expect(result.items.filter { $0.kind == .approximate }.count == 2)
    }

    @Test func skeletonSecondChanceNeverReachesMatched() {
        // Vraie différence de voyelle longue : reste signalée (jaune, pas blanc).
        let score = RecitationAligner.similarity("فاتقوا", "فتق")
        #expect(score < RecitationAligner.matchThreshold)
        let kind = align(
            RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 8, ayahTexts: [1: "فَاتَّقُوا اللَّهَ"]),
            "فتق الله"
        ).items.first?.kind
        #expect(kind == .approximate)
    }

    @Test func shortWordsGetNoSkeletonSecondChance() {
        // قل / قال : trop courts pour la deuxième chance (5 lettres minimum) —
        // on ne rapproche pas deux mots-outils différents.
        let reference = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 112, ayahTexts: [
            1: "قُلْ هُوَ اللَّهُ أَحَدٌ",
        ])
        let result = align(reference, "قال هو الله احد")
        #expect(result.items.first?.kind != .matched)
    }

    @Test func consonantSkeletonStripsLongVowelsExceptFirst() {
        #expect(RecitationAligner.consonantSkeleton("فاتقوا") == "فتق")
        #expect(RecitationAligner.consonantSkeleton("واصلحوا") == "وصلح")
        #expect(RecitationAligner.consonantSkeleton("والرسول") == "ولرسل")
        // La première lettre est conservée même si c'est ا/و/ي.
        #expect(RecitationAligner.consonantSkeleton("ايات") == "ات")
    }

    // MARK: - Troncature (préfixe/suffixe avalé par le moteur)

    @Test func swallowedAffixIsApproximateNotSubstituted() {
        // Cas réels (Al-Anfal 7) : « يُحِقَّ » entendu « حق », « أَنَّهَا » entendu « أن ».
        let anfal7 = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 8, ayahTexts: [
            7: "أَنَّهَا لَكُمْ وَيُرِيدُ اللَّهُ أَنْ يُحِقَّ الْحَقَّ",
        ])
        let result = align(anfal7, "أن لكم ويريد الله أن حق الحق")
        let byWord = Dictionary(uniqueKeysWithValues: result.items.compactMap { item in
            item.reference.map { ($0.normalized, item.kind) }
        })
        #expect(byWord["انها"] == .approximate)
        #expect(byWord["يحق"] == .approximate)
        #expect(!result.items.contains { $0.kind == .substituted })
    }

    @Test func truncationRequiresContiguousHalf() {
        // « الشوكة » entendu « شة » : lettres non contiguës → reste « autre mot ».
        #expect(!RecitationAligner.isTruncation(of: ["الشوكه"], heard: "شه"))
        // Trop court côté entendu (1 lettre) ou référence trop courte.
        #expect(!RecitationAligner.isTruncation(of: ["يحق"], heard: "ق"))
        #expect(!RecitationAligner.isTruncation(of: ["ان"], heard: "ا"))
        // Moins de la moitié couverte.
        #expect(!RecitationAligner.isTruncation(of: ["الكافرين"], heard: "ين"))
        // Jamais dans l'autre sens : un mot entendu plus long reste jugé.
        #expect(!RecitationAligner.isTruncation(of: ["حق"], heard: "يحق"))
        // Cas valides.
        #expect(RecitationAligner.isTruncation(of: ["يحق"], heard: "حق"))
        #expect(RecitationAligner.isTruncation(of: ["انها"], heard: "ان"))
    }

    // MARK: - Choix entre hypothèses du moteur

    @Test func alternativeWithMoreExpectedWordsIsPreferred() {
        // Cas réel (Al-Anfal 1) : la 1ʳᵉ hypothèse avale « وأطيعوا » en liaison
        // avec « الله » ; une alternative le contient → on la retient.
        let expected: Set<String> = ["واصلحوا", "ذات", "بينكم", "واطيعوا", "الله", "ورسوله"]
        let texts = ["وأصلحوا ذات بينكم الله ورسوله", "وأصلحوا ذات بينكم وأطيعوا الله ورسوله"]
        #expect(RecitationTranscriber.preferredCandidateIndex(texts: texts, expected: expected) == 1)
    }

    @Test func engineChoiceWinsTiesAndWhenNothingIsExpected() {
        let expected: Set<String> = ["الله"]
        // Égalité : la préférence du moteur (index 0) l'emporte.
        #expect(RecitationTranscriber.preferredCandidateIndex(texts: ["الله اكبر", "الله اعلم"], expected: expected) == 0)
        // Rien d'attendu ou une seule hypothèse : index 0.
        #expect(RecitationTranscriber.preferredCandidateIndex(texts: ["a", "b"], expected: []) == 0)
        #expect(RecitationTranscriber.preferredCandidateIndex(texts: ["a"], expected: expected) == 0)
        // Une alternative hors sujet ne gagne jamais.
        #expect(RecitationTranscriber.preferredCandidateIndex(texts: ["الله", "الطقس جميل"], expected: expected) == 0)
    }

    // MARK: - Sièges de hamza

    @Test func hamzaSeatVariantIsMatched() {
        // Cas réel (Luqman 4) : « وَيُؤْتُونَ » transcrit « ويأتون » par la
        // dictée (siège de hamza choisi d'après la voyelle brève, non jugée).
        let luqman = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 31, ayahTexts: [
            4: "الَّذِينَ يُقِيمُونَ الصَّلَاةَ وَيُؤْتُونَ الزَّكَاةَ وَهُمْ بِالْآخِرَةِ هُمْ يُوقِنُونَ",
        ])
        let result = align(luqman, "الذين يقيمون الصلاة ويأتون الزكاة وهم بالآخرة هم يوقنون")
        #expect(result.items.allSatisfy { $0.kind == .matched })
        #expect(result.accuracy == 1)
    }

    @Test func hamzaSeatFormsCoverAllSupports() {
        let table = RecitationEquivalences.empty
        let forms = table.referenceForms(display: "وَيُؤْتُونَ", normalized: "ويوتون")
        #expect(forms.contains("ويوتون"))
        #expect(forms.contains("وياتون"))
        #expect(forms.contains("وييتون"))
    }

    @Test func initialHamzaIsNotExpanded() {
        // أحد : la hamza initiale est déjà unifiée (أ → ا) — pas de variantes
        // qui transformeraient احد en وحد/يحد.
        let forms = RecitationEquivalences.empty.referenceForms(display: "أَحَدٌ", normalized: "احد")
        #expect(forms == ["احد"])
    }

    @Test func hamzaSeatVariantsNeverMatchADifferentWord() {
        // « ويعملون » à la place de « ويؤتون » reste une substitution.
        let luqman = RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 31, ayahTexts: [
            4: "وَيُؤْتُونَ الزَّكَاةَ",
        ])
        let result = align(luqman, "ويعملون الزكاه")
        #expect(result.items.first?.kind == .substituted)
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
