//
//  CompassManager.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//  Updated — Haptic progressif + proximityLevel
//

import Foundation
import CoreLocation
import Combine
import MapKit
import SwiftUI

class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Propriétés Publiques (@Published)
    @Published var userLocation: CLLocation?
    @Published var cityName: String = "Recherche..."
    @Published var heading: Double = 0.0
    @Published var qiblaAngle: Double = 0.0
    @Published var isCorrectDirection = false
    
    /// Écart angulaire absolu avec la Qiblah (0° = parfaitement aligné)
    @Published var angularOffset: Double = 180.0
    
    /// Niveau de proximité 0→4 (4 = aligné, 0 = loin)
    /// Utilisé par la View pour piloter l'animation de la Kaaba et le glow
    @Published var proximityLevel: Int = 0

    // MARK: - Propriétés Privées
    private let locationManager = CLLocationManager()
    
    private let meccaLatitude  = 21.4225 * .pi / 180
    private let meccaLongitude = 39.8262 * .pi / 180
    
    /// Palier précédent pour ne pas re-trigger le même haptic en boucle
    private var lastHapticLevel: Int = 0

    // MARK: - Initialisation
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    // MARK: - Start / Stop
    func startCompass() {
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()
    }
    
    func stopCompass() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Haptic Progressif
    
    /// 4 paliers d'intensité croissante :
    /// - Level 1 (< 20°) : light
    /// - Level 2 (< 10°) : medium
    /// - Level 3 (< 5°)  : heavy → on sent qu'on brûle
    /// - Level 4 (< 2°)  : rigid + notification success → ALIGNÉ !
    private func triggerProgressiveHaptic(level: Int) {
        #if os(iOS)
        // On ne re-déclenche que quand on MONTE de palier
        guard level > lastHapticLevel else {
            lastHapticLevel = level
            return
        }
        lastHapticLevel = level
        
        switch level {
        case 1:
            let g = UIImpactFeedbackGenerator(style: .light)
            g.impactOccurred()
        case 2:
            let g = UIImpactFeedbackGenerator(style: .medium)
            g.impactOccurred()
        case 3:
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.impactOccurred()
        case 4:
            // Double haptic pour marquer le lock
            let g = UIImpactFeedbackGenerator(style: .rigid)
            g.impactOccurred(intensity: 1.0)
            // Petit délai puis notification "success"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                let n = UINotificationFeedbackGenerator()
                n.notificationOccurred(.success)
            }
        default:
            break
        }
        #endif
    }

    // MARK: - Délégué : Heading
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let validHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        
        Task { @MainActor in
            self.heading = validHeading
            self.checkAlignment()
        }
    }

    // MARK: - Délégué : Location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let calculatedAngle = calculateQiblaAngle(for: location)
        
        Task { @MainActor in
            self.userLocation = location
            self.qiblaAngle = calculatedAngle
            
            if self.cityName == "Recherche..." {
                self.cityName = await location.fetchCityName()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ [CompassManager] Erreur GPS : \(error.localizedDescription)")
    }

    // MARK: - Calcul Qiblah
    private func calculateQiblaAngle(for location: CLLocation) -> Double {
        let latA = location.coordinate.latitude * .pi / 180
        let lonA = location.coordinate.longitude * .pi / 180
        
        let dLon = meccaLongitude - lonA
        let y = sin(dLon) * cos(meccaLatitude)
        let x = cos(latA) * sin(meccaLatitude) - sin(latA) * cos(meccaLatitude) * cos(dLon)
        let bearing = atan2(y, x)
        
        return (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Check Alignment + Haptic Progressif
    private func checkAlignment() {
        // Écart angulaire le plus court (0-180°)
        let rawDiff = (qiblaAngle - heading + 360).truncatingRemainder(dividingBy: 360)
        let offset = rawDiff > 180 ? 360 - rawDiff : rawDiff
        
        self.angularOffset = offset
        
        // Calcul du palier de proximité
        let newLevel: Int
        switch offset {
        case 0..<2:    newLevel = 4  // ALIGNÉ
        case 2..<5:    newLevel = 3  // Très proche
        case 5..<10:   newLevel = 2  // Proche
        case 10..<20:  newLevel = 1  // On s'approche
        default:       newLevel = 0  // Loin
        }
        
        let _wasAligned = isCorrectDirection
        let nowAligned = newLevel == 4
        
        self.proximityLevel = newLevel
        self.isCorrectDirection = nowAligned
        
        // Déclenche le haptic quand on MONTE de palier
        triggerProgressiveHaptic(level: newLevel)
        
        // Reset le compteur haptic quand on sort complètement (pour pouvoir re-trigger)
        if newLevel == 0 {
            lastHapticLevel = 0
        }
    }
}

// MARK: - Reverse Geocoding
extension CLLocation {
    func fetchCityName() async -> String {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(self)
            if let city = placemarks.first?.locality {
                return city
            } else {
                return "Local"
            }
        } catch {
            print("❌ [Geocoding] ERREUR : \(error.localizedDescription)")
            return "Local"
        }
    }
}
