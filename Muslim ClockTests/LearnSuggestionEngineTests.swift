//
//  LearnSuggestionEngineTests.swift
//  Muslim Clock — tests du moteur de suggestion « En ce moment »
//

import Foundation
import Testing
@testable import Muslim_Clock

struct LearnSuggestionEngineTests {

    // Journée de référence : mardi 2026-10-13, horaires plausibles (Paris, octobre).
    private static let cal = Calendar.current

    private static func date(_ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: hour, minute: minute)) ?? .now
    }

    private static let fajr = date(6, 30)
    private static let dhuhr = date(13, 15)
    private static let maghrib = date(19, 0)
    private static let isha = date(20, 30)

    private static func input(
        now: Date,
        isFriday: Bool = false,
        dueReviewCount: Int = 0,
        nextLessonTitle: String? = nil,
        khatmaBalance: Int? = nil,
        hasReadToday: Bool = false,
        quizAvailable: Bool = false,
        weeklyQuizDone: Bool = false,
        recitationReworkCount: Int = 0
    ) -> LearnSuggestionInput {
        LearnSuggestionInput(
            now: now, fajr: fajr, dhuhr: dhuhr, maghrib: maghrib, isha: isha,
            isFriday: isFriday,
            dueReviewCount: dueReviewCount,
            nextLessonTitle: nextLessonTitle,
            khatmaBalance: khatmaBalance,
            hasReadToday: hasReadToday,
            quizAvailable: quizAvailable,
            weeklyQuizDone: weeklyQuizDone,
            recitationReworkCount: recitationReworkCount
        )
    }

    // MARK: - Fenêtres

    @Test func slotFollowsPrayerBoundaries() {
        #expect(LearnSuggestionEngine.slot(now: Self.date(5), fajr: Self.fajr, dhuhr: Self.dhuhr, maghrib: Self.maghrib, isha: Self.isha) == .night)
        #expect(LearnSuggestionEngine.slot(now: Self.date(9), fajr: Self.fajr, dhuhr: Self.dhuhr, maghrib: Self.maghrib, isha: Self.isha) == .morning)
        #expect(LearnSuggestionEngine.slot(now: Self.date(15), fajr: Self.fajr, dhuhr: Self.dhuhr, maghrib: Self.maghrib, isha: Self.isha) == .afternoon)
        #expect(LearnSuggestionEngine.slot(now: Self.date(19, 30), fajr: Self.fajr, dhuhr: Self.dhuhr, maghrib: Self.maghrib, isha: Self.isha) == .evening)
        #expect(LearnSuggestionEngine.slot(now: Self.date(22), fajr: Self.fajr, dhuhr: Self.dhuhr, maghrib: Self.maghrib, isha: Self.isha) == .night)
    }

    @Test func slotFallsBackToClockWithoutPrayers() {
        #expect(LearnSuggestionEngine.slot(now: Self.date(9)) == .morning)
        #expect(LearnSuggestionEngine.slot(now: Self.date(14)) == .afternoon)
        #expect(LearnSuggestionEngine.slot(now: Self.date(18)) == .evening)
        #expect(LearnSuggestionEngine.slot(now: Self.date(3)) == .night)
    }

    @Test func slotKeyFormat() {
        let key = LearnSuggestionEngine.slotKey(slot: .evening, now: Self.date(19, 30))
        #expect(key == "evening-2026-10-13")
    }

    // MARK: - Priorités

    @Test func fridayKahfBeatsEverythingDuringDay() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(9), isFriday: true,
            dueReviewCount: 4, khatmaBalance: -10,
            quizAvailable: true
        ))
        #expect(result.first == .kahf)
    }

    @Test func kahfNotSuggestedAtNight() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(23), isFriday: true
        ))
        #expect(!result.contains(.kahf))
    }

    @Test func dueCardsBeatKhatmaBacklog() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(15), dueReviewCount: 3, khatmaBalance: -5
        ))
        #expect(result.first == .reviewCards(count: 3))
        #expect(result.contains(.khatmaReading(pagesBehind: 5)))
    }

    @Test func khatmaBacklogBeatsPendingQuiz() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(15), khatmaBalance: -2, quizAvailable: true
        ))
        #expect(result.first == .khatmaReading(pagesBehind: 2))
        #expect(result.contains(.weeklyQuiz))
    }

    @Test func quizBoostedOnFridayAfterKahf() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(15), isFriday: true,
            khatmaBalance: -2, quizAvailable: true
        ))
        #expect(result.first == .kahf)
        #expect(result[1] == .weeklyQuiz)
    }

    @Test func doneQuizIsNeverSuggested() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(15), quizAvailable: true, weeklyQuizDone: true
        ))
        #expect(!result.contains(.weeklyQuiz))
    }

    @Test func eveningKhatmaOnlyWhenNotReadToday() {
        let notRead = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(19, 30), khatmaBalance: 1, hasReadToday: false
        ))
        #expect(notRead.first == .khatmaReading(pagesBehind: 0))

        let read = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(19, 30), khatmaBalance: 1, hasReadToday: true
        ))
        #expect(!read.contains(.khatmaReading(pagesBehind: 0)))

        // En journée, pas de rappel « pages du jour » (fenêtre du soir uniquement).
        let afternoon = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(15), khatmaBalance: 1, hasReadToday: false
        ))
        #expect(!afternoon.contains(.khatmaReading(pagesBehind: 0)))
    }

    @Test func lessonStrongerInMorningThanAfternoon() {
        let morning = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(9), nextLessonTitle: "La Hanîfiyya", recitationReworkCount: 2
        ))
        #expect(morning.first == .lessonOfDay(title: "La Hanîfiyya"))

        let evening = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(19, 30), nextLessonTitle: "La Hanîfiyya", recitationReworkCount: 2
        ))
        #expect(evening.first == .recitationRework(count: 2))
    }

    @Test func nightSurahsOnlyAtNightAndLast() {
        let night = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(22), recitationReworkCount: 1
        ))
        #expect(night.first == .recitationRework(count: 1))
        #expect(night.last == .nightSurahs)

        let day = LearnSuggestionEngine.suggestions(Self.input(now: Self.date(10)))
        #expect(!day.contains(.nightSurahs))
    }

    @Test func emptyWhenNothingApplies() {
        // Après-midi, aucun plan, rien de dû : pas de tâche inventée.
        let result = LearnSuggestionEngine.suggestions(Self.input(now: Self.date(15)))
        #expect(result.isEmpty)
    }

    @Test func noKhatmaSuggestionWithoutPlan() {
        let result = LearnSuggestionEngine.suggestions(Self.input(
            now: Self.date(19, 30), khatmaBalance: nil
        ))
        #expect(!result.contains { if case .khatmaReading = $0 { return true } else { return false } })
    }
}
