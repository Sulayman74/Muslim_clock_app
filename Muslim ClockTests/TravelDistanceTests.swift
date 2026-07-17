//
//  TravelDistanceTests.swift
//  Muslim ClockTests
//
//  Tests de la logique PURE du mode voyage : distance orthodromique + règle
//  d'ancre « glissement / gel ». Aucun simulateur ni CoreLocation runtime requis.
//

import Testing
import Foundation
import CoreLocation
@testable import Muslim_Clock

struct TravelDistanceTests {

    // Coordonnées de référence.
    private let paris     = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
    private let lyon      = CLLocationCoordinate2D(latitude: 45.7640, longitude: 4.8357)   // ~392 km
    private let mecca     = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)  // ~4340 km
    private var parisDrift: CLLocationCoordinate2D {                                        // ~1.5 km
        CLLocationCoordinate2D(latitude: 48.8700, longitude: 2.3522)
    }

    // MARK: - Haversine

    @Test func greatCircleParisLyonIsAround392km() {
        let km = TravelDistance.greatCircleMeters(paris, lyon) / 1000
        #expect(abs(km - 392) < 15)   // tolérance sphère vs ellipsoïde
    }

    @Test func greatCircleParisMeccaIsAround4340km() {
        let km = TravelDistance.greatCircleMeters(paris, mecca) / 1000
        #expect(abs(km - 4340) < 40)
    }

    @Test func greatCircleIsSymmetric() {
        let ab = TravelDistance.greatCircleMeters(paris, mecca)
        let ba = TravelDistance.greatCircleMeters(mecca, paris)
        #expect(abs(ab - ba) < 1e-6)
    }

    @Test func greatCircleZeroForSamePoint() {
        #expect(TravelDistance.greatCircleMeters(paris, paris) < 1e-6)
    }

    // MARK: - evaluate : règle d'ancre

    @Test func unknownWhenNoAnchorAndSeedsAnchor() {
        let r = TravelDistance.evaluate(current: paris, home: nil)
        #expect(r.status == .unknown)
        #expect(r.nextAnchor.latitude == paris.latitude)   // 1er fix → ancre = position
    }

    @Test func atHomeWhenWithinThresholdAndAnchorSlides() {
        let r = TravelDistance.evaluate(current: parisDrift, home: paris)
        #expect(r.status == .atHome)
        // Sous le seuil : l'ancre suit la position courante (zone de vie).
        #expect(r.nextAnchor.latitude == parisDrift.latitude)
    }

    @Test func travelingWhenBeyondThresholdAndAnchorFreezes() {
        let r = TravelDistance.evaluate(current: lyon, home: paris)
        guard case let .traveling(meters) = r.status else {
            Issue.record("Attendu .traveling, obtenu \(r.status)")
            return
        }
        #expect(meters / 1000 > 83)
        // Au-delà du seuil : l'ancre reste figée au domicile.
        #expect(r.nextAnchor.latitude == paris.latitude)
    }

    @Test func customThresholdChangesVerdict() {
        // Avec un seuil de 500 km, Paris↔Lyon (~392 km) reste « à la maison ».
        let big = Measurement(value: 500, unit: UnitLength.kilometers)
        let r = TravelDistance.evaluate(current: lyon, home: paris, threshold: big)
        #expect(r.status == .atHome)
    }

    // MARK: - Intégration moteur de suggestion

    @Test func activeMomentsIncludesTravelOnlyWhenTraveling() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let off = AdhkarSuggestion.activeMoments(
            now: base, prayerDates: [], fajr: nil, lastThirdOfNight: nil, isTraveling: false
        )
        let on = AdhkarSuggestion.activeMoments(
            now: base, prayerDates: [], fajr: nil, lastThirdOfNight: nil, isTraveling: true
        )
        #expect(!off.contains(AdhkarMoment.travel))
        #expect(on.contains(AdhkarMoment.travel))
    }
}
