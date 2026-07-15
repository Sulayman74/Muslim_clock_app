//
//  IlmMathTests.swift
//  Muslim ClockTests
//
//  Tests des fonctions pures de progression du module ʿIlm (IlmMath).
//

import Testing
import Foundation
@testable import Muslim_Clock

// MARK: - Fixtures

private func lesson(_ id: String) -> IlmLesson {
    IlmLesson(id: id, title: id, arabic: "", text: "", source: nil, note: nil)
}

private func track(_ id: String, _ lessonIDs: [String]) -> IlmTrack {
    IlmTrack(id: id, title: id, titleArabic: "", author: "", lessons: lessonIDs.map(lesson))
}

struct IlmMathTests {

    // MARK: completedCount

    @Test func completedCountCountsOnlyCompletedLessons() {
        let t = track("t", ["a", "b", "c"])
        var p = IlmProgress()
        p.completedAt["a"] = .now
        p.completedAt["c"] = .now
        #expect(IlmMath.completedCount(in: t, progress: p) == 2)
    }

    @Test func completedCountZeroOnFreshProgress() {
        let t = track("t", ["a", "b"])
        #expect(IlmMath.completedCount(in: t, progress: IlmProgress()) == 0)
    }

    // MARK: nextLessonIndex

    @Test func nextLessonIndexIsFirstIncompleteInCanonicalOrder() {
        let t = track("t", ["a", "b", "c"])
        var p = IlmProgress()
        p.completedAt["a"] = .now
        #expect(IlmMath.nextLessonIndex(in: t, progress: p) == 1) // b
    }

    @Test func nextLessonIndexNilWhenTrackCompleted() {
        let t = track("t", ["a", "b"])
        var p = IlmProgress()
        p.completedAt["a"] = .now
        p.completedAt["b"] = .now
        #expect(IlmMath.nextLessonIndex(in: t, progress: p) == nil)
    }

    // MARK: reviewQueue

    @Test func reviewQueueKeepsOnlyDueCardsSortedByDate() {
        let t = track("t", ["a", "b", "c"])
        var p = IlmProgress()
        // a due depuis longtemps, c due récemment, b pas encore due.
        p.nextReviewAt["a"] = Date(timeIntervalSince1970: 1000)
        p.nextReviewAt["c"] = Date(timeIntervalSince1970: 4000)
        p.nextReviewAt["b"] = Date(timeIntervalSince1970: 9000)
        let now = Date(timeIntervalSince1970: 5000)
        let queue = IlmMath.reviewQueue(tracks: [t], progress: p, now: now)
        // a et c sont dues (≤ now), triées de la plus ancienne à la plus récente.
        #expect(queue.map(\.lesson.id) == ["a", "c"])
    }

    @Test func reviewQueueEmptyWhenNothingDue() {
        let t = track("t", ["a"])
        var p = IlmProgress()
        p.nextReviewAt["a"] = Date(timeIntervalSince1970: 9000)
        let queue = IlmMath.reviewQueue(tracks: [t], progress: p, now: Date(timeIntervalSince1970: 1000))
        #expect(queue.isEmpty)
    }

    // MARK: summary

    @Test func summaryReportsCompletionPercentAndNextIndex() {
        let t = track("t", ["a", "b", "c", "d"])
        var p = IlmProgress()
        p.completedAt["a"] = .now
        p.completedAt["b"] = .now
        let plan = IlmPlan(trackID: "t", startDate: .now, lessonsPerWeek: 7)
        let s = IlmMath.summary(track: t, plan: plan, progress: p)
        #expect(s.totalLessons == 4)
        #expect(s.completedLessons == 2)
        #expect(s.nextLessonIndex == 2) // c
        #expect(abs(s.percentComplete - 0.5) < 0.0001)
    }

    @Test func summaryOfCompletedTrackHasNoNextLessonNorEndDate() {
        let t = track("t", ["a", "b"])
        var p = IlmProgress()
        p.completedAt["a"] = .now
        p.completedAt["b"] = .now
        let plan = IlmPlan(trackID: "t", startDate: .now, lessonsPerWeek: 3)
        let s = IlmMath.summary(track: t, plan: plan, progress: p)
        #expect(s.nextLessonIndex == nil)
        #expect(s.estimatedEndDate == nil)
        #expect(abs(s.percentComplete - 1.0) < 0.0001)
    }

    // MARK: weekStreak

    @Test func weekStreakZeroWithNoCompletions() {
        #expect(IlmMath.weekStreak(completionDates: [], lessonsPerWeekGoal: 3, now: .now) == 0)
    }
}
