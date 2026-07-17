//
//  TravelDistance.swift
//  Muslim Clock — Mode voyage (Safar)
//
//  Logique PURE de détection de voyage : à partir d'une position courante et d'une
//  ancre « domicile », dérive un statut. Aucun I/O, aucun état, aucune dépendance
//  CoreLocation runtime → 100 % testable hors-ligne (pattern QiblaMath / IlmMath).
//
//  ⚠️ Fiqh : ce statut ne fait que *suggérer*. Le mode voyage réel est piloté par
//  l'intention de l'utilisateur (toggle persisté), jamais par le GPS seul.
//

import Foundation
import CoreLocation

/// Statut de voyage dérivé d'une position et d'une ancre domicile.
enum TravelStatus: Equatable, Sendable {
    /// Pas encore d'ancre connue (premier lancement, avant le 1er fix).
    case unknown
    /// Dans le rayon de résidence.
    case atHome
    /// Au-delà du seuil : distance à l'ancre, en mètres.
    case traveling(meters: Double)
}

enum TravelDistance {

    /// Seuil de *masâfat al-qasr* par défaut (≈ 4 burud). Constante nommée, ajustable —
    /// le khilâf situe la distance de voyage autour de 83–89 km.
    static let defaultThreshold = Measurement(value: 83, unit: UnitLength.kilometers)

    /// Distance orthodromique (Haversine) entre deux coordonnées, en mètres.
    /// Pure et déterministe → vérifiable en test sans simulateur ni CoreLocation.
    static func greatCircleMeters(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> Double {
        let earthRadius = 6_371_000.0
        let phi1 = a.latitude * .pi / 180
        let phi2 = b.latitude * .pi / 180
        let dPhi = (b.latitude - a.latitude) * .pi / 180
        let dLambda = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dPhi / 2) * sin(dPhi / 2)
            + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Évalue le statut de voyage et renvoie l'ancre domicile à persister.
    ///
    /// Règle du « glissement / gel » : tant que l'on reste sous le seuil, l'ancre
    /// suit la position courante (zone de vie). Dès que le seuil est franchi, l'ancre
    /// est **figée** au dernier point sous le seuil et l'on est déclaré « en voyage »
    /// relativement à ce point. Au retour sous le seuil, l'ancre se remet à jour.
    ///
    /// - Parameters:
    ///   - current: position courante.
    ///   - home: ancre domicile connue, ou `nil` au tout premier fix.
    ///   - threshold: seuil de voyage (défaut : `defaultThreshold`).
    /// - Returns: `status` dérivé + `nextAnchor` à réécrire dans le store.
    static func evaluate(
        current: CLLocationCoordinate2D,
        home: CLLocationCoordinate2D?,
        threshold: Measurement<UnitLength> = defaultThreshold
    ) -> (status: TravelStatus, nextAnchor: CLLocationCoordinate2D) {
        guard let home else { return (.unknown, current) }
        let distance = greatCircleMeters(current, home)
        if distance < threshold.converted(to: .meters).value {
            return (.atHome, current)          // l'ancre glisse avec l'utilisateur
        }
        return (.traveling(meters: distance), home)   // ancre gelée
    }
}
