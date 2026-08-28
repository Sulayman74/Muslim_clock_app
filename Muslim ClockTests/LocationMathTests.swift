//
//  LocationMathTests.swift
//  Muslim ClockTests
//
//  Tests des décisions pures de position (LocationMath) : mouvement significatif
//  (bannière de recalcul) et « même lieu » (garde-fou anti-recalcul).
//

import Testing
import CoreLocation
@testable import Muslim_Clock

struct LocationMathTests {

    // Paris, Lyon (~392 km), et un point à ~1 km de Paris.
    private let paris = CLLocation(latitude: 48.8566, longitude: 2.3522)
    private let lyon = CLLocation(latitude: 45.7640, longitude: 4.8357)
    private let nearParis = CLLocation(latitude: 48.8566, longitude: 2.3658) // ~1 km à l'est

    // MARK: - isSignificantMove (seuil 15 km)

    @Test func significantMoveTrueForDifferentCity() {
        #expect(LocationMath.isSignificantMove(from: paris, to: lyon))
    }

    @Test func significantMoveFalseForSmallMove() {
        #expect(!LocationMath.isSignificantMove(from: paris, to: nearParis))
    }

    @Test func significantMoveFalseAtSamePoint() {
        #expect(!LocationMath.isSignificantMove(from: paris, to: paris))
    }

    @Test func significantMoveRespectsCustomThreshold() {
        // Avec un seuil de 500 m, un déplacement de ~1 km devient significatif.
        #expect(LocationMath.isSignificantMove(from: paris, to: nearParis, thresholdMeters: 500))
    }

    // MARK: - isSamePlace (seuil 2 km)

    @Test func samePlaceTrueWithinThreshold() {
        // ~1 km < 2 km → même lieu.
        #expect(LocationMath.isSamePlace(paris, nearParis))
    }

    @Test func samePlaceFalseForDifferentCity() {
        #expect(!LocationMath.isSamePlace(paris, lyon))
    }

    @Test func samePlaceFalseWhenNoPreviousLocation() {
        // Jamais calculé → il faut calculer (pas « même lieu »).
        #expect(!LocationMath.isSamePlace(nil, paris))
    }

    @Test func samePlaceTrueAtExactSamePoint() {
        #expect(LocationMath.isSamePlace(paris, paris))
    }
}
