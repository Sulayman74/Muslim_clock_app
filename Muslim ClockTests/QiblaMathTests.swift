//
//  QiblaMathTests.swift
//  Muslim ClockTests
//
//  Tests des fonctions pures de la boussole Qiblah (CompassManager).
//  Azimuts de référence vérifiés contre Google Qibla Finder et la lib Adhan.
//

import Testing
@testable import Muslim_Clock

struct QiblaMathTests {

    // MARK: - Azimut Qibla (great-circle bearing, vrai nord)

    @Test func qiblaBearingParis() {
        let bearing = CompassManager.qiblaBearing(latitude: 48.8566, longitude: 2.3522)
        #expect(abs(bearing - 119.163) < 0.05)
    }

    @Test func qiblaBearingNewYork() {
        let bearing = CompassManager.qiblaBearing(latitude: 40.7128, longitude: -74.0060)
        #expect(abs(bearing - 58.482) < 0.05)
    }

    @Test func qiblaBearingJakarta() {
        let bearing = CompassManager.qiblaBearing(latitude: -6.2088, longitude: 106.8456)
        #expect(abs(bearing - 295.152) < 0.05)
    }

    @Test func qiblaBearingSydney() {
        let bearing = CompassManager.qiblaBearing(latitude: -33.8688, longitude: 151.2093)
        #expect(abs(bearing - 277.500) < 0.05)
    }

    /// Haute latitude, azimut proche du wrap 360/0 (Anchorage).
    @Test func qiblaBearingHighLatitudeNearNorth() {
        let bearing = CompassManager.qiblaBearing(latitude: 61.2181, longitude: -149.9003)
        #expect(abs(bearing - 350.883) < 0.05)
    }

    /// L'azimut est toujours normalisé dans [0, 360).
    @Test func qiblaBearingIsNormalized() {
        for (lat, lon) in [(90.0, 0.0), (-90.0, 0.0), (0.0, 180.0), (0.0, -180.0), (21.4225, 39.8262)] {
            let bearing = CompassManager.qiblaBearing(latitude: lat, longitude: lon)
            #expect(bearing >= 0 && bearing < 360)
        }
    }

    // MARK: - Delta angulaire le plus court

    @Test func shortestDeltaCrossesNorthForward() {
        #expect(CompassManager.shortestAngularDelta(from: 350, to: 10) == 20)
    }

    @Test func shortestDeltaCrossesNorthBackward() {
        #expect(CompassManager.shortestAngularDelta(from: 10, to: 350) == -20)
    }

    @Test func shortestDeltaHalfTurn() {
        #expect(abs(CompassManager.shortestAngularDelta(from: 0, to: 180)) == 180)
    }

    /// `current` peut être un angle cumulé non normalisé (cas de l'UI).
    @Test func shortestDeltaAcceptsUnnormalizedCurrent() {
        #expect(CompassManager.shortestAngularDelta(from: 730, to: 20) == 10)   // 730 ≡ 10°
        #expect(CompassManager.shortestAngularDelta(from: -30, to: 340) == 10)  // -30 ≡ 330°
    }

    @Test func shortestDeltaStaysInRange() {
        for current in stride(from: -720.0, through: 720.0, by: 37.0) {
            for target in stride(from: 0.0, to: 360.0, by: 23.0) {
                let delta = CompassManager.shortestAngularDelta(from: current, to: target)
                #expect(delta >= -180 && delta <= 180)
            }
        }
    }

    // MARK: - Paliers de proximité

    @Test func proximityLevelBands() {
        #expect(CompassManager.proximityLevel(forOffset: 0) == 4)
        #expect(CompassManager.proximityLevel(forOffset: 1.99) == 4)
        #expect(CompassManager.proximityLevel(forOffset: 2) == 3)
        #expect(CompassManager.proximityLevel(forOffset: 4.99) == 3)
        #expect(CompassManager.proximityLevel(forOffset: 5) == 2)
        #expect(CompassManager.proximityLevel(forOffset: 9.99) == 2)
        #expect(CompassManager.proximityLevel(forOffset: 10) == 1)
        #expect(CompassManager.proximityLevel(forOffset: 19.99) == 1)
        #expect(CompassManager.proximityLevel(forOffset: 20) == 0)
        #expect(CompassManager.proximityLevel(forOffset: 180) == 0)
    }
}
