//
//  ZoneTwoPlannerTests.swift
//  Muslim ClockTests
//
//  Garde-fou des cartes contextuelles de la zone « Pour aller plus loin ».
//

import Testing
@testable import Muslim_Clock

struct ZoneTwoPlannerTests {

    @Test func everythingShownUnderTheCap() {
        let plan = ZoneTwoPlanner.plan(candidates: [.wudu, .night])
        #expect(plan == [.wudu, .night])
    }

    @Test func fourCandidatesDropTheLeastUrgent() {
        // Nuit, 45 min avant Fajr, en voyage, avec une suggestion d'adhkar :
        // le voyage (permanent) cède la place aux cartes du moment.
        let plan = ZoneTwoPlanner.plan(candidates: [.wudu, .adhkarMoment, .night, .travel])
        #expect(plan.count == ZoneTwoPlanner.maxVisible)
        #expect(plan == [.wudu, .adhkarMoment, .night])
        #expect(!plan.contains(.travel))
    }

    @Test func priorityOrderIsWuduThenAdhkarThenNightThenTravel() {
        #expect(ZoneTwoPlanner.Card.wudu < .adhkarMoment)
        #expect(ZoneTwoPlanner.Card.adhkarMoment < .night)
        #expect(ZoneTwoPlanner.Card.night < .travel)
    }

    @Test func customCapAndEmptyInput() {
        #expect(ZoneTwoPlanner.plan(candidates: [.night, .travel, .wudu], maxVisible: 1) == [.wudu])
        #expect(ZoneTwoPlanner.plan(candidates: []).isEmpty)
        #expect(ZoneTwoPlanner.plan(candidates: [.travel], maxVisible: 0).isEmpty)
    }
}
