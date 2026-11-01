//
//  WatchIslamicSeasonTests.swift
//  WatchExtension Watch AppTests
//
//  Teste la logique pure `WatchIslamicSeason.current(for:)` : mapping mois hégirien
//  → bannière (label, icône, mois sacré, Eid), et la priorité mois spécial > vendredi.
//  Les dates sont construites via le calendrier Umm al-Qura pour cibler chaque mois.
//

import Testing
import Foundation
@testable import WatchExtension_Watch_App

struct WatchIslamicSeasonTests {

    /// Date grégorienne correspondant au couple (mois, jour) hégirien donné.
    private func hijri(month: Int, day: Int, year: Int = 1447) -> Date {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Mois nommés

    @Test func ramadanIsLabelledAndNotSacred() {
        let s = WatchIslamicSeason.current(for: hijri(month: 9, day: 10))
        #expect(s.hijriMonth == 9)
        #expect(s.labelAr == "رمضان مبارك")
        #expect(s.isSacredMonth == false)
        #expect(s.isEid == false)
        #expect(s.hasBanner)
    }

    @Test func sacredMonthsAreFlagged() {
        for month in [1, 7, 11] {
            let s = WatchIslamicSeason.current(for: hijri(month: month, day: 5))
            #expect(s.isSacredMonth, "Le mois \(month) devrait être sacré")
            #expect(s.labelAr == "شهر حرام")
        }
    }

    // MARK: - Les deux Eid

    @Test func eidAlFitrIsFirstOfShawwal() {
        let s = WatchIslamicSeason.current(for: hijri(month: 10, day: 1))
        #expect(s.isEid)
        #expect(s.labelAr == "عيد الفطر المبارك")
        #expect(s.isSacredMonth == false)

        // Le 2 Chawwal n'est plus l'Eid (mois ordinaire, pas de bannière).
        let after = WatchIslamicSeason.current(for: hijri(month: 10, day: 2))
        #expect(after.isEid == false)
        #expect(after.hasBanner == false)
    }

    @Test func eidAlAdhaWindowInDhulHijja() {
        let eid = WatchIslamicSeason.current(for: hijri(month: 12, day: 10))
        #expect(eid.isEid)
        #expect(eid.isSacredMonth)               // Dhou al-Hijja est un mois sacré
        #expect(eid.labelAr == "عيد الأضحى المبارك")

        let ordinary = WatchIslamicSeason.current(for: hijri(month: 12, day: 20))
        #expect(ordinary.isEid == false)
        #expect(ordinary.isSacredMonth)
        #expect(ordinary.labelAr == "شهر حرام")
    }

    // MARK: - Vendredi vs mois spécial

    @Test func specialMonthOverridesFriday() {
        // Un vendredi en Ramadan reste étiqueté « Ramadan », pas « vendredi ».
        let friday = fridayInHijriMonth(9)
        let s = WatchIslamicSeason.current(for: friday)
        #expect(s.isFriday)
        #expect(s.labelAr == "رمضان مبارك")
    }

    @Test func ordinaryFridayFallsBackToJumuahBanner() {
        let friday = fridayInHijriMonth(2) // Safar : mois ordinaire
        let s = WatchIslamicSeason.current(for: friday)
        #expect(s.isFriday)
        #expect(s.labelAr == "يوم الجمعة")
    }

    @Test func ordinaryNonFridayHasNoBanner() {
        let day = nonFridayInHijriMonth(2)
        let s = WatchIslamicSeason.current(for: day)
        #expect(s.labelAr.isEmpty)
        #expect(s.hasBanner == false)
    }

    // MARK: - Helpers date

    /// Premier vendredi (weekday grégorien 6) tombant dans le mois hégirien donné.
    private func fridayInHijriMonth(_ month: Int) -> Date {
        let hcal = Calendar(identifier: .islamicUmmAlQura)
        let gcal = Calendar.current
        var day = hijri(month: month, day: 2)
        for _ in 0..<40 {
            if gcal.component(.weekday, from: day) == 6,
               hcal.component(.month, from: day) == month {
                return day
            }
            day = gcal.date(byAdding: .day, value: 1, to: day)!
        }
        return day
    }

    /// Premier jour non-vendredi dans le mois hégirien donné.
    private func nonFridayInHijriMonth(_ month: Int) -> Date {
        let gcal = Calendar.current
        var day = hijri(month: month, day: 2)
        for _ in 0..<7 {
            if gcal.component(.weekday, from: day) != 6 { return day }
            day = gcal.date(byAdding: .day, value: 1, to: day)!
        }
        return day
    }
}
