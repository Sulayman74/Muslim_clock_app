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
    
    override private init() {
        super.init()
        manager.delegate = self
        // Précision à 3km près (suffisant pour les prières, économise la batterie)
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
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
}
