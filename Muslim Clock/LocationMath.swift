//
//  LocationMath.swift
//  Muslim Clock
//
//  Décisions pures liées à la position : mouvement significatif (déclenche la
//  bannière de recalcul) et « même lieu » (garde-fou anti-recalcul).
//
//  Isolé de `PrayerTimesViewModel`/`SharedLocationManager` (CoreLocation, I/O)
//  pour être testable — même pattern que `IqamahMath`/`SmartSetupMath`.
//

import CoreLocation

nonisolated enum LocationMath {

    /// Au-delà de ce déplacement, on propose un recalcul manuel (bannière GPS).
    static let significantMoveThresholdMeters: CLLocationDistance = 15_000

    /// En deçà, on considère qu'on est « au même endroit » : le garde-fou
    /// anti-boucle saute alors le recalcul (jour + fuseau inchangés par ailleurs).
    static let samePlaceThresholdMeters: CLLocationDistance = 2_000

    /// `true` si l'utilisateur a suffisamment bougé pour justifier un recalcul manuel.
    static func isSignificantMove(
        from previous: CLLocation,
        to current: CLLocation,
        thresholdMeters: CLLocationDistance = significantMoveThresholdMeters
    ) -> Bool {
        previous.distance(from: current) > thresholdMeters
    }

    /// `true` si `current` est assez proche de `previous` pour être le « même lieu ».
    /// `previous == nil` (jamais calculé) ⇒ `false` : il faut calculer.
    static func isSamePlace(
        _ previous: CLLocation?,
        _ current: CLLocation,
        thresholdMeters: CLLocationDistance = samePlaceThresholdMeters
    ) -> Bool {
        guard let previous else { return false }
        return previous.distance(from: current) < thresholdMeters
    }
}
