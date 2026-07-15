//
//  QuranPlanMathTests.swift
//  Muslim ClockTests
//
//  Tests des fonctions pures du plan de lecture Quran (QuranPlanMath).
//

import Testing
import Foundation
@testable import Muslim_Clock

struct QuranPlanMathTests {

    /// Instant fixe hors période de changement DST, pour des tests déterministes.
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: daysBetween (inclusif, ≥ 1)

    @Test func daysBetweenSameInstantIsOne() {
        #expect(QuranPlanMath.daysBetween(base, base) == 1)
    }

    @Test func daysBetweenCountsInclusiveDays() {
        #expect(QuranPlanMath.daysBetween(base, base.addingTimeInterval(86_400)) == 2)
        #expect(QuranPlanMath.daysBetween(base, base.addingTimeInterval(6 * 86_400)) == 7)
    }

    @Test func daysBetweenNeverBelowOne() {
        // start > end → borné à 1.
        #expect(QuranPlanMath.daysBetween(base.addingTimeInterval(86_400), base) == 1)
    }

    // MARK: endDate

    @Test func endDateByDurationAddsDays() {
        let plan = QuranPlan(goalType: .byDuration, goalValue: 30, startDate: base)
        let expected = Calendar.current.date(byAdding: .day, value: 30, to: base)
        #expect(QuranPlanMath.endDate(of: plan) == expected)
    }

    @Test func endDateByDateReturnsTargetTimestamp() {
        let target = 2_000_000_000.0
        let plan = QuranPlan(goalType: .byDate, goalValue: target, startDate: base)
        #expect(QuranPlanMath.endDate(of: plan) == Date(timeIntervalSince1970: target))
    }

    @Test func endDateByPagesDerivesDurationFrom20PagesPerDay() {
        // 100 pages / 20 par jour = 5 jours.
        let plan = QuranPlan(goalType: .byPages, goalValue: 100, startDate: base)
        let expected = Calendar.current.date(byAdding: .day, value: 5, to: base)
        #expect(QuranPlanMath.endDate(of: plan) == expected)
    }

    // MARK: progress

    @Test func progressComputesActualAndPercent() {
        let plan = QuranPlan(
            goalType: .byDuration, goalValue: 10, startDate: base,
            startPage: 1, endPage: 100
        )
        let entry = ReadingEntry(date: base, pagesRead: 20, lastPageReached: 20)
        let p = QuranPlanMath.progress(for: plan, entries: [entry], now: base)

        #expect(p.totalPages == 100)
        #expect(p.pagesReadActual == 20)
        #expect(abs(p.percentComplete - 0.2) < 0.0001)
        #expect(p.pagesRemaining == 80)
    }

    @Test func progressIgnoresEntriesBeforePlanStart() {
        let plan = QuranPlan(
            goalType: .byDuration, goalValue: 10, startDate: base,
            startPage: 1, endPage: 100
        )
        let past = ReadingEntry(date: base.addingTimeInterval(-5 * 86_400), pagesRead: 50, lastPageReached: 50)
        let p = QuranPlanMath.progress(for: plan, entries: [past], now: base)
        #expect(p.pagesReadActual == 0)
    }

    // MARK: streak

    @Test func streakCountsConsecutiveDaysMeetingGoal() {
        let cal = Calendar.current
        guard let y1 = cal.date(byAdding: .day, value: -1, to: base),
              let y2 = cal.date(byAdding: .day, value: -2, to: base) else {
            Issue.record("date arithmetic failed")
            return
        }
        let entries = [
            ReadingEntry(date: y1, pagesRead: 20, lastPageReached: 0),
            ReadingEntry(date: y2, pagesRead: 25, lastPageReached: 0)
        ]
        #expect(QuranPlanMath.streak(entries: entries, pagesPerDayGoal: 20, now: base) == 2)
    }

    @Test func streakBreaksBelowGoal() {
        let cal = Calendar.current
        guard let y1 = cal.date(byAdding: .day, value: -1, to: base) else {
            Issue.record("date arithmetic failed")
            return
        }
        let entries = [ReadingEntry(date: y1, pagesRead: 10, lastPageReached: 0)]
        #expect(QuranPlanMath.streak(entries: entries, pagesPerDayGoal: 20, now: base) == 0)
    }
}
