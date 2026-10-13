//
//  WeeklyReviewPlannerTests.swift
//  Muslim ClockTests
//
//  Composition de la révision hebdomadaire (WeeklyReviewPlanner), semaines ISO
//  (QuizWeek), état de session (QuizSession) et créneaux du rappel hebdo.
//

import Testing
import Foundation
@testable import Muslim_Clock

// MARK: - Fixtures

private func question(_ id: String, topic: String, lesson: String? = nil, correct: Int = 0) -> QuizQuestion {
    QuizQuestion(
        id: id, topicId: topic, lessonId: lesson, kind: .masala, format: .mcq, difficulty: 1,
        promptFr: id, promptAr: id,
        choices: [QuizChoice(fr: "a", ar: "a"), QuizChoice(fr: "b", ar: "b"), QuizChoice(fr: "c", ar: "c")],
        correctIndex: correct, explanationFr: "e", explanationAr: nil,
        dalil: [QuizDalil(kind: .quran, ref: "1:1", grading: nil)], scholarRef: nil
    )
}

private let topics = [
    QuizTopic(id: "aq1", domain: .aqidah, titleFr: "", titleAr: "", trackId: nil),
    QuizTopic(id: "aq2", domain: .aqidah, titleFr: "", titleAr: "", trackId: nil),
    QuizTopic(id: "fq1", domain: .fiqh, titleFr: "", titleAr: "", trackId: nil),
]

/// 20 questions par thème ; les questions `aq1` sont liées aux leçons `l0…l19`.
private let pool: [QuizQuestion] = topics.flatMap { topic in
    (0..<20).map { i in
        question("\(topic.id)_\(i)", topic: topic.id, lesson: topic.id == "aq1" ? "l\(i)" : nil)
    }
}

private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso) ?? .distantPast
}

struct WeeklyReviewPlannerTests {

    @Test func returnsRequestedSizeWithoutDuplicates() {
        let session = WeeklyReviewPlanner.build(
            questions: pool, topics: topics, progress: QuizProgress(), dueLessonIDs: [],
            weekKey: "2026-W42", weekNumber: 42, size: 10
        )
        #expect(session.count == 10)
        #expect(Set(session.map(\.id)).count == 10)
    }

    @Test func isDeterministicForTheSameWeek() {
        let a = WeeklyReviewPlanner.build(questions: pool, topics: topics, progress: QuizProgress(),
                                          dueLessonIDs: ["l1", "l2"], weekKey: "2026-W42", weekNumber: 42)
        let b = WeeklyReviewPlanner.build(questions: pool, topics: topics, progress: QuizProgress(),
                                          dueLessonIDs: ["l1", "l2"], weekKey: "2026-W42", weekNumber: 42)
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test func differsFromOneWeekToTheNext() {
        let a = WeeklyReviewPlanner.build(questions: pool, topics: topics, progress: QuizProgress(),
                                          dueLessonIDs: [], weekKey: "2026-W42", weekNumber: 42)
        let b = WeeklyReviewPlanner.build(questions: pool, topics: topics, progress: QuizProgress(),
                                          dueLessonIDs: [], weekKey: "2026-W43", weekNumber: 43)
        #expect(a.map(\.id) != b.map(\.id))
    }

    @Test func halfOfTheSessionComesFromDueLessons() {
        let due = Set((0..<20).map { "l\($0)" })
        let session = WeeklyReviewPlanner.build(
            questions: pool, topics: topics, progress: QuizProgress(), dueLessonIDs: due,
            weekKey: "2026-W42", weekNumber: 42, size: 10
        )
        let fromDue = session.filter { $0.lessonId.map(due.contains) ?? false }
        #expect(fromDue.count >= 5)
    }

    @Test func recentMistakesAreIncludedButOldOnesAreNot() {
        let now = date("2026-10-15T12:00:00Z")
        var progress = QuizProgress()
        progress.recordAnswer(questionID: "fq1_3", correct: false, on: now.addingTimeInterval(-3 * 86_400))
        progress.recordAnswer(questionID: "fq1_4", correct: false, on: now.addingTimeInterval(-3 * 86_400))
        progress.recordAnswer(questionID: "fq1_5", correct: false, on: now.addingTimeInterval(-60 * 86_400))
        // Les questions fq1 ne sont dans aucun thème de rotation : elles ne peuvent
        // venir que du seau « erreurs récentes » (2 places sur 10).
        let session = WeeklyReviewPlanner.build(
            questions: pool.filter { $0.topicId != "fq1" } + pool.filter { ["fq1_3", "fq1_4", "fq1_5"].contains($0.id) },
            topics: topics.filter { $0.id != "fq1" },
            progress: progress, dueLessonIDs: [], weekKey: "2026-W42", weekNumber: 42, size: 10, now: now
        )
        let ids = Set(session.map(\.id))
        #expect(ids.contains("fq1_3"))
        #expect(ids.contains("fq1_4"))
    }

    @Test func fillsFromComplementWhenBucketsAreEmpty() {
        let small = Array(pool.prefix(4))
        let session = WeeklyReviewPlanner.build(
            questions: small, topics: [], progress: QuizProgress(), dueLessonIDs: [],
            weekKey: "2026-W42", weekNumber: 42, size: 10
        )
        #expect(session.count == 4)
    }

    @Test func emptyInputsGiveEmptySession() {
        #expect(WeeklyReviewPlanner.build(questions: [], topics: topics, progress: QuizProgress(),
                                          dueLessonIDs: [], weekKey: "k", weekNumber: 1).isEmpty)
        #expect(WeeklyReviewPlanner.build(questions: pool, topics: topics, progress: QuizProgress(),
                                          dueLessonIDs: [], weekKey: "k", weekNumber: 1, size: 0).isEmpty)
    }

    @Test func rotationPicksOneTopicPerDomain() {
        let w42 = WeeklyReviewPlanner.rotationTopicIDs(topics: topics, weekNumber: 42)
        let w43 = WeeklyReviewPlanner.rotationTopicIDs(topics: topics, weekNumber: 43)
        #expect(w42 == ["aq1", "fq1"])
        #expect(w43 == ["aq2", "fq1"])
    }

    @Test func stableSeedIsStable() {
        #expect(WeeklyReviewPlanner.stableSeed("2026-W42") == WeeklyReviewPlanner.stableSeed("2026-W42"))
        #expect(WeeklyReviewPlanner.stableSeed("2026-W42") != WeeklyReviewPlanner.stableSeed("2026-W43"))
        // Valeur de référence FNV-1a 64 bits de la chaîne vide.
        #expect(WeeklyReviewPlanner.stableSeed("") == 0xcbf2_9ce4_8422_2325)
    }
}

// MARK: - Semaines ISO

struct QuizWeekTests {

    @Test func isoWeekKeyHandlesYearBoundary() {
        // Le 1er janvier 2027 (vendredi) appartient à la semaine 53 de 2026.
        #expect(QuizWeek.key(for: date("2027-01-01T12:00:00Z")) == "2026-W53")
        #expect(QuizWeek.key(for: date("2026-10-13T12:00:00Z")) == "2026-W42")
    }

    @Test func streakCountsCurrentWeekOnlyWhenPassed() {
        let now = date("2026-10-15T12:00:00Z")   // semaine 42
        let passed = WeeklySessionResult(score: 8, total: 10, date: now)
        let failed = WeeklySessionResult(score: 5, total: 10, date: now)

        #expect(QuizWeek.streak(sessions: ["2026-W41": passed, "2026-W40": passed], now: now) == 2)
        #expect(QuizWeek.streak(sessions: ["2026-W42": passed, "2026-W41": passed], now: now) == 2)
        #expect(QuizWeek.streak(sessions: ["2026-W41": failed, "2026-W40": passed], now: now) == 0)
        #expect(QuizWeek.streak(sessions: [:], now: now) == 0)
    }

    @Test func passThresholdIsSeventyPercent() {
        #expect(WeeklySessionResult(score: 7, total: 10, date: .now).isPassed)
        #expect(!WeeklySessionResult(score: 6, total: 10, date: .now).isPassed)
        #expect(!WeeklySessionResult(score: 0, total: 0, date: .now).isPassed)
    }
}

// MARK: - Session

struct QuizSessionTests {

    @Test func answeringLocksTheChoiceAndScores() {
        var session = QuizSession(mode: .weekly, questions: [question("q1", topic: "t", correct: 1),
                                                             question("q2", topic: "t", correct: 0)])
        #expect(session.select(1)?.correct == true)
        #expect(session.select(0) == nil)            // verrouillé
        #expect(session.score == 1)
        session.advance()
        #expect(session.current?.id == "q2")
        #expect(session.select(2)?.correct == false)
        #expect(session.mistakes.map(\.id) == ["q2"])
        session.advance()
        #expect(session.isFinished)
        #expect(session.current == nil)
    }

    @Test func cannotAdvanceWithoutAnswering() {
        var session = QuizSession(mode: .topic("t"), questions: [question("q1", topic: "t")])
        session.advance()
        #expect(session.current?.id == "q1")
        #expect(!session.isFinished)
    }

    @Test func outOfRangeChoiceIsIgnored() {
        var session = QuizSession(mode: .weekly, questions: [question("q1", topic: "t")])
        #expect(session.select(9) == nil)
        #expect(!session.isAnswered)
    }

    @Test func emptySessionIsImmediatelyFinished() {
        #expect(QuizSession(mode: .weekly, questions: []).isFinished)
    }
}

// MARK: - Rappel hebdo

struct IlmWeeklyReminderTests {

    @Test func schedulesThisWeekAndNextWhenNotDone() {
        // Mardi 13 octobre 2026, rappel le vendredi à 18 h.
        let now = date("2026-10-13T10:00:00Z")
        let dates = IlmWeeklyReminderScheduler.fireDates(weekday: 6, hour: 18, currentWeekDone: false, now: now)
        #expect(dates.count == 2)
        #expect(QuizWeek.key(for: dates[0]) == "2026-W42")
        #expect(QuizWeek.key(for: dates[1]) == "2026-W43")
    }

    @Test func skipsThisWeekWhenSessionDone() {
        let now = date("2026-10-13T10:00:00Z")
        let dates = IlmWeeklyReminderScheduler.fireDates(weekday: 6, hour: 18, currentWeekDone: true, now: now)
        #expect(dates.count == 1)
        #expect(QuizWeek.key(for: dates[0]) == "2026-W43")
    }

    @Test func estimatedMinutesRoundsUp() {
        #expect(IlmWeeklyReminderScheduler.estimatedMinutes(questionCount: 10) == 6)
        #expect(IlmWeeklyReminderScheduler.estimatedMinutes(questionCount: 1) == 1)
        #expect(IlmWeeklyReminderScheduler.estimatedMinutes(questionCount: 0) == 1)
    }
}
