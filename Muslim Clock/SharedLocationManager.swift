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

    /// `true` pendant qu'un fix GPS à la demande est en cours (pull-to-refresh,
    /// ouverture d'app) → alimente l'état « Mise à jour de la position… ».
    @Published private(set) var isRefreshingLocation = false

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

    // MARK: - Fix GPS à la demande (pull-to-refresh, ouverture d'app)

    /// Continuations en attente d'un point frais (pull-to-refresh).
    /// Résumées à la 1ʳᵉ livraison GPS ou par le timeout — jamais deux fois.
    private var freshFixWaiters: [CheckedContinuation<Void, Never>] = []

    /// Demande un point GPS frais et attend sa livraison (≤ 6 s).
    ///
    /// `requestLocation()` ignore le `distanceFilter` et renvoie le meilleur point
    /// courant tout de suite : c'est ce qui permet au pull-to-refresh de rattraper
    /// un changement de ville. Le recalcul des horaires est déclenché
    /// automatiquement par l'abonnement de `PrayerTimesViewModel` à
    /// `currentLocation` — cette méthode ne fait qu'aller chercher le point.
    @MainActor
    func refreshLocation() async {
        guard !isAccessDenied else { return }
        isRefreshingLocation = true
        manager.requestLocation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            freshFixWaiters.append(continuation)
            // Filet anti-blocage : le pull-to-refresh ne doit jamais rester coincé.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.resumeFreshFixWaiters()
            }
        }
    }

    @MainActor
    private func resumeFreshFixWaiters() {
        isRefreshingLocation = false
        guard !freshFixWaiters.isEmpty else { return }
        let waiters = freshFixWaiters
        freshFixWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // On met à jour la variable publiée
        self.currentLocation = location

        // Débloque un éventuel pull-to-refresh en attente d'un point frais.
        Task { @MainActor [weak self] in self?.resumeFreshFixWaiters() }

        // Optionnel : on peut arrêter le GPS une fois qu'on a la ville pour sauver la batterie
        // manager.stopUpdatingLocation()
    }

    /// Un échec GPS ne doit pas laisser le pull-to-refresh tourner 6 s dans le vide.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.resumeFreshFixWaiters() }
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
