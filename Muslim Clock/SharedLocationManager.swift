//
//  SharedLocationManager.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 31/03/2026.
//

import Foundation
import CoreLocation
import Combine

class SharedLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SharedLocationManager()
    
    private let manager = CLLocationManager()
    
    // 💡 Le @Published permet aux autres de "s'abonner" à ces changements
    @Published var currentLocation: CLLocation?

    /// Statut d'autorisation de localisation, publié pour l'UI (bannière si refusé).
    @Published var authorizationStatus: CLAuthorizationStatus

    /// True si l'accès à la localisation est refusé ou restreint : l'app ne peut
    /// pas calculer d'horaires tant que l'utilisateur n'ouvre pas les Réglages.
    var isAccessDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    override private init() {
        // `manager` a une valeur par défaut inline, donc déjà disponible ici.
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        // 🔥 FIX : on ne reçoit une update QUE si on a bougé de 500m au moins
        // → plus de faux positifs à cause du bruit GPS
        manager.distanceFilter = 500
    }

    func requestPermissionAndStart() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // On met à jour la variable publiée
        self.currentLocation = location

        // Optionnel : on peut arrêter le GPS une fois qu'on a la ville pour sauver la batterie
        // manager.stopUpdatingLocation()
    }

    /// Suit les changements d'autorisation. Si l'utilisateur vient d'accorder
    /// l'accès (depuis les Réglages ou la 1re demande), (re)démarre les updates.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
