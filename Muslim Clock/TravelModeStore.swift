//
//  TravelModeStore.swift
//  Muslim Clock — Mode voyage (Safar)
//
//  État du mode voyage. Sépare deux notions :
//   • L'INTENTION (le toggle utilisateur) → clé `TravelKeys.active` en @AppStorage,
//     lue directement par les vues (réactif, partagé, jamais de crash).
//   • L'OBSERVATION GPS (ce store) → `status` dérivé de la position, sert UNIQUEMENT
//     à *suggérer* l'activation. Ne bascule jamais l'intention tout seul.
//
//  @Observable (iOS 17) : pas de Combine neuf (cf. CLAUDE.md). @MainActor : mute l'UI.
//  Alimenté par l'unique sink de localisation existant (PrayerTimesViewModel) → aucun
//  nouvel abonnement CoreLocation, coût batterie nul.
//

import Foundation
import CoreLocation
import Observation

/// Clés du mode voyage (namespace dédié — hors `StorageKeys`, non partagé avec les extensions).
enum TravelKeys {
    /// Intention utilisateur : mode voyage activé. Lu en @AppStorage par les vues.
    static let active = "travel_mode_active"
    static let homeLat = "travel_home_lat"
    static let homeLon = "travel_home_lon"
}

@MainActor
@Observable
final class TravelModeStore {

    /// Statut géographique dérivé du GPS. Sert à *suggérer*, jamais à activer.
    private(set) var status: TravelStatus = .unknown

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Ancre domicile (persistée)

    private var homeAnchor: CLLocationCoordinate2D? {
        guard defaults.object(forKey: TravelKeys.homeLat) != nil else { return nil }
        return CLLocationCoordinate2D(
            latitude: defaults.double(forKey: TravelKeys.homeLat),
            longitude: defaults.double(forKey: TravelKeys.homeLon)
        )
    }

    private func persistAnchor(_ coordinate: CLLocationCoordinate2D) {
        defaults.set(coordinate.latitude, forKey: TravelKeys.homeLat)
        defaults.set(coordinate.longitude, forKey: TravelKeys.homeLon)
    }

    // MARK: - Dérivés pour l'UI

    /// True si le GPS estime que l'on voyage (indépendant de l'intention).
    var isTravelingByGPS: Bool {
        if case .traveling = status { return true }
        return false
    }

    /// Distance à l'ancre domicile en km si l'on voyage, sinon `nil`.
    var distanceFromHomeKm: Int? {
        if case let .traveling(meters) = status { return Int(meters / 1000) }
        return nil
    }

    /// True dès qu'une ancre domicile a été établie.
    var homeIsSet: Bool { homeAnchor != nil }

    // MARK: - Entrées

    /// Réévalue le statut à partir d'un fix. Appelée depuis l'unique sink de
    /// localisation existant → zéro nouvel abonnement CoreLocation.
    func update(with location: CLLocation) {
        let (newStatus, nextAnchor) = TravelDistance.evaluate(
            current: location.coordinate,
            home: homeAnchor
        )
        status = newStatus
        persistAnchor(nextAnchor)
    }

    /// Re-ancrage manuel (« Définir ce lieu comme domicile ») — gère le déménagement
    /// sans détection temporelle coûteuse. No-op si la position est inconnue.
    func markCurrentLocationAsHome() {
        guard let location = SharedLocationManager.shared.currentLocation else { return }
        persistAnchor(location.coordinate)
        status = .atHome
    }
}
