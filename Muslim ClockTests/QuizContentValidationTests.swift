//
//  QuizContentValidationTests.swift
//  Muslim ClockTests
//
//  Garde-fou éditorial sur le VRAI ilm_quiz.json du bundle : chaque question a
//  une preuve, des références valides, une bonne réponse dans les bornes, et
//  pointe vers un thème et une leçon existants. Plus les règles du validateur
//  et le pont Leitner du ViewModel.
//

import Testing
import Foundation
@testable import Muslim_Clock

@MainActor
struct QuizContentValidationTests {

    private func bundledContent() throws -> QuizContent {
        let url = try #require(Bundle.main.url(forResource: "ilm_quiz", withExtension: "json"))
        return try JSONDecoder().decode(QuizContent.self, from: Data(contentsOf: url))
    }

    @Test func bundledQuizIsEditoriallyValid() throws {
        let content = try bundledContent()
        let tracks = IlmContentLoader.shared.tracks
        let issues = QuizContentValidator.issues(
            in: content,
            lessonIDs: Set(tracks.flatMap { $0.lessons.map(\.id) }),
            trackIDs: Set(tracks.map(\.id))
        )
        #expect(issues.isEmpty, "\(issues.joined(separator: "\n"))")
        #expect(content.questions.count >= 100)
    }

    @Test func everyTopicHasQuestions() throws {
        let content = try bundledContent()
        for topic in content.topics {
            #expect(content.questions.contains { $0.topicId == topic.id }, "thème vide : \(topic.id)")
        }
    }

    @Test func loaderExposesAllBundledQuestions() throws {
        let content = try bundledContent()
        #expect(QuizContentLoader.shared.questions.count == content.questions.count)
    }

    // MARK: Validateur

    @Test func quranReferenceFormats() {
        #expect(QuizContentValidator.isValidQuranRef("40:60"))
        #expect(QuizContentValidator.isValidQuranRef("103:1-3"))
        #expect(QuizContentValidator.isValidQuranRef("2:255,256"))
        #expect(!QuizContentValidator.isValidQuranRef("115:1"))
        #expect(!QuizContentValidator.isValidQuranRef("2"))
        #expect(!QuizContentValidator.isValidQuranRef("2:0"))
        #expect(!QuizContentValidator.isValidQuranRef("al-Baqara:255"))
    }

    @Test func validatorReportsMissingDalilAndBadIndex() {
        let bad = QuizQuestion(
            id: "x", topicId: "t", lessonId: "unknown", kind: .masala, format: .trueFalse, difficulty: 5,
            promptFr: "p", promptAr: "p", choices: [QuizChoice(fr: "Vrai", ar: "صحيح")],
            correctIndex: 3, explanationFr: "e", explanationAr: nil, dalil: [], scholarRef: nil
        )
        let content = QuizContent(
            version: 1,
            topics: [QuizTopic(id: "t", domain: .fiqh, titleFr: "", titleAr: "", trackId: "nope")],
            questions: [bad]
        )
        let issues = QuizContentValidator.issues(in: content, lessonIDs: [], trackIDs: [])
        #expect(issues.contains { $0.contains("aucune preuve") })
        #expect(issues.contains { $0.contains("correctIndex") })
        #expect(issues.contains { $0.contains("vrai/faux") })
        #expect(issues.contains { $0.contains("leçon inconnue") })
        #expect(issues.contains { $0.contains("parcours inconnu") })
        #expect(issues.contains { $0.contains("difficulté") })
    }

    @Test func unknownQuestionFormatIsSkippedNotFatal() throws {
        let json = """
        {"version":2,"topics":[{"id":"t","domain":"aqidah","titleFr":"T","titleAr":"ت","trackId":null}],
         "questions":[
          {"id":"ok","topicId":"t","lessonId":null,"kind":"masala","format":"mcq","difficulty":1,
           "promptFr":"p","promptAr":"p","choices":[{"fr":"a","ar":"a"},{"fr":"b","ar":"b"},{"fr":"c","ar":"c"}],
           "correctIndex":0,"explanationFr":"e","dalil":[{"kind":"quran","ref":"1:1"}],"scholarRef":null},
          {"id":"future","topicId":"t","kind":"masala","format":"ordering","difficulty":1,
           "promptFr":"p","promptAr":"p","choices":[],"correctIndex":0,"explanationFr":"e","dalil":[]}
         ]}
        """
        let content = try JSONDecoder().decode(QuizContent.self, from: Data(json.utf8))
        #expect(content.questions.map(\.id) == ["ok"])
    }

    @Test func progressDecodingIsTolerant() throws {
        let legacy = #"{"answers":{"q1":{"correct":true,"date":0}}}"#
        let progress = try JSONDecoder().decode(QuizProgress.self, from: Data(legacy.utf8))
        #expect(progress.answers["q1"]?.attempts == 1)
        #expect(progress.weeklySessions.isEmpty)
        #expect(progress.plannedWeeks.isEmpty)
    }

    @Test func plannedWeeksAreBounded() {
        var progress = QuizProgress()
        for week in 1...12 {
            progress.storePlan(["q\(week)"], for: String(format: "2026-W%02d", week))
        }
        #expect(progress.plannedWeeks.count == 8)
        #expect(progress.plannedWeeks["2026-W12"] != nil)
        #expect(progress.plannedWeeks["2026-W01"] == nil)
    }

    // MARK: Pont Leitner

    @Test func wrongAnswerSendsCompletedLessonBackToBoxOne() {
        let keys = ["ilm_progress", IlmQuizStorage.progressKey, "ilm_plan"]
        let backup = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, backup) {
                if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        let ilm = IlmViewModel()
        ilm.completeLesson("usul3_09")
        ilm.gradeCard("usul3_09", outcome: .known)
        ilm.gradeCard("usul3_09", outcome: .known)
        #expect(ilm.progress.reviewBox["usul3_09"] == 3)

        let quiz = IlmQuizViewModel(ilm: ilm)
        let q = QuizQuestion(
            id: "bridge", topicId: "aqidah_usul3", lessonId: "usul3_09", kind: .dalil, format: .trueFalse,
            difficulty: 1, promptFr: "p", promptAr: "p",
            choices: [QuizChoice(fr: "Vrai", ar: "صحيح"), QuizChoice(fr: "Faux", ar: "خطأ")],
            correctIndex: 0, explanationFr: "e", explanationAr: nil,
            dalil: [QuizDalil(kind: .quran, ref: "40:60", grading: nil)], scholarRef: nil
        )
        #expect(quiz.answer(q, choiceIndex: 0))
        #expect(ilm.progress.reviewBox["usul3_09"] == 3)   // juste : Leitner intact
        #expect(!quiz.answer(q, choiceIndex: 1))
        #expect(ilm.progress.reviewBox["usul3_09"] == 1)   // faux : retour boîte 1

        // Leçon non acquise : une erreur ne l'inscrit pas en révision.
        let q2 = QuizQuestion(
            id: "bridge2", topicId: "aqidah_usul3", lessonId: "usul3_10", kind: .dalil, format: .trueFalse,
            difficulty: 1, promptFr: "p", promptAr: "p",
            choices: [QuizChoice(fr: "Vrai", ar: "صحيح"), QuizChoice(fr: "Faux", ar: "خطأ")],
            correctIndex: 0, explanationFr: "e", explanationAr: nil,
            dalil: [QuizDalil(kind: .quran, ref: "40:60", grading: nil)], scholarRef: nil
        )
        quiz.answer(q2, choiceIndex: 1)
        #expect(ilm.progress.reviewBox["usul3_10"] == nil)
    }

    @Test func weeklyResultKeepsBestScore() {
        let keys = ["ilm_progress", IlmQuizStorage.progressKey, "ilm_plan"]
        let backup = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, backup) {
                if let value { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        let quiz = IlmQuizViewModel(ilm: IlmViewModel())
        quiz.finishWeeklySession(score: 8, total: 10)
        quiz.finishWeeklySession(score: 6, total: 10)
        #expect(quiz.thisWeekResult?.score == 8)
        quiz.finishWeeklySession(score: 10, total: 10)
        #expect(quiz.thisWeekResult?.score == 10)
    }
}
