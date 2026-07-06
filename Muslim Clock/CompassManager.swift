//
//  CompassManager.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//  Updated — Haptic progressif + proximityLevel
//

import Foundation
import CoreLocation
import CoreMotion
import Combine
import SwiftUI
import MapKit

class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Propriétés Publiques (@Published)
    @Published var userLocation: CLLocation?
    @Published var cityName: String = String(localized: "Recherche...")
    @Published var heading: Double = 0.0
    @Published var qiblaAngle: Double = 0.0
    @Published var isCorrectDirection = false
    @Published var angularOffset: Double = 180.0
    @Published var proximityLevel: Int = 0

    private let locationManager = CLLocationManager()

    /// `CMMotionManager` fournit `motion.heading` qui fusionne magnéto + gyro + accel
    /// côté iOS (filtre Kalman interne). Plus précis et plus rapide que le heading
    /// brut de `CLLocationManager` (qui n'inclut pas le gyro). Update 60Hz.
    private let motionManager = CMMotionManager()

    /// `true` si on consomme actuellement DeviceMotion (60Hz fusion).
    /// `false` si fallback CLLocationManager heading (capteur magnéto seul).
    @Published private(set) var usesMotionFusion: Bool = false

    /// `true` quand le cap est invalide ou trop imprécis (calibration requise).
    /// L'UI affiche alors une invite « mouvement en 8 » au lieu d'une aiguille figée.
    @Published private(set) var needsCalibration: Bool = false

    /// Compteur d'updates reçues — utilisé par l'overlay DEBUG pour afficher le taux.
    @Published private(set) var headingUpdateCount: Int = 0

    private static let meccaLatitude  = 21.4225 * Double.pi / 180
    private static let meccaLongitude = 39.8262 * Double.pi / 180

    /// Watchdog de bascule DeviceMotion → CLLocationManager (cf. `startMotionWatchdog`).
    private var motionWatchdogTask: Task<Void, Never>?

    /// Palier précédent pour ne pas re-trigger le même haptic en boucle
    private var lastHapticLevel: Int = 0
    private var cancellables = Set<AnyCancellable>()

    /// `true` dès qu'un reverse geocoding a réussi (ou échoué et abandonné).
    /// Évite la comparaison fragile à `String(localized: "Recherche...")`
    /// qui casse au changement de langue de l'app.
    private var cityFetched: Bool = false

    // MARK: - Feedback generators pré-instanciés (perf + latency)
    //
    // Les `UIImpactFeedbackGenerator` sont coûteux à allouer. Les garder en
    // propriétés évite l'instantiation à chaque palier de proximité atteint.
    #if os(iOS)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let successNotification = UINotificationFeedbackGenerator()
    #endif

    // MARK: - Initialisation
    override init() {
        super.init()
        locationManager.delegate = self
        // Filtre noise capteur magnétique : ne reçoit une update que si delta ≥ 1°.
        // Réduit le jitter visible (boussole qui « tremble ») sans perte UX significative.
        locationManager.headingFilter = 1
        // On ne gère que le Heading ici (la position GPS vient de SharedLocationManager).

        SharedLocationManager.shared.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                Task { @MainActor in
                    guard let self else { return }
                    self.userLocation = location
                    self.qiblaAngle = Self.qiblaBearing(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    if !self.cityFetched {
                        self.cityName = await location.fetchCityName()
                        self.cityFetched = true
                    }
                }
            }
            .store(in: &cancellables)
    }

        func startCompass() {
            // Priorité : DeviceMotion (60Hz, gyro + magnéto fusionnés) si dispo.
            // Fallback : CLLocationManager heading (~10Hz, magnéto seul).
            //
            // Frame `.xTrueNorthZVertical` : cap référencé au VRAI nord (CoreMotion
            // applique la déclinaison magnétique en interne). Obligatoire car
            // `qiblaBearing` retourne un azimut géographique — un cap magnétique
            // décalerait l'aiguille de la déclinaison locale (~13° à New York).
            if motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
                motionManager.startDeviceMotionUpdates(
                    using: .xTrueNorthZVertical,
                    to: .main
                ) { [weak self] motion, _ in
                    guard let self, let motion else { return }
                    // `motion.heading` : -1 si invalide (calibration en cours), sinon 0-360°.
                    let h = motion.heading
                    guard h >= 0 else {
                        Task { @MainActor in self.needsCalibration = true }
                        return
                    }
                    Task { @MainActor in
                        self.needsCalibration = false
                        self.heading = h
                        self.headingUpdateCount &+= 1
                        self.checkAlignment()
                    }
                }
                usesMotionFusion = true
                startMotionWatchdog()
            } else {
                locationManager.startUpdatingHeading()
                usesMotionFusion = false
            }
        }

        func stopCompass() {
            motionWatchdogTask?.cancel()
            motionWatchdogTask = nil
            if usesMotionFusion {
                motionManager.stopDeviceMotionUpdates()
                usesMotionFusion = false
            } else {
                locationManager.stopUpdatingHeading()
            }
        }

        /// `.xTrueNorthZVertical` exige la localisation ET le réglage système
        /// « Étalonnage boussole » actifs. Si aucune frame valide n'arrive sous 2 s,
        /// on bascule sur le heading CLLocationManager, qui gère le vrai nord
        /// lui-même via `trueHeading`.
        private func startMotionWatchdog() {
            motionWatchdogTask?.cancel()
            let countAtStart = headingUpdateCount
            motionWatchdogTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, !Task.isCancelled else { return }
                guard self.usesMotionFusion, self.headingUpdateCount == countAtStart else { return }
                self.motionManager.stopDeviceMotionUpdates()
                self.locationManager.startUpdatingHeading()
                self.usesMotionFusion = false
            }
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
            lightHaptic.impactOccurred()
        case 2:
            mediumHaptic.impactOccurred()
        case 3:
            heavyHaptic.impactOccurred()
        case 4:
            rigidHaptic.prepare()
            rigidHaptic.impactOccurred(intensity: 1.0)
            successNotification.prepare()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 80_000_000)
                self?.successNotification.notificationOccurred(.success)
            }
        default:
            break
        }
        #endif
    }

    // MARK: - Délégué : Heading (fallback si DeviceMotion indisponible)
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let validHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        // `headingAccuracy` < 0 : capteur non calibré ; > 25° : trop imprécis
        // pour viser la Qibla (le palier « ALIGNÉ » fait ±2°).
        let poorAccuracy = newHeading.headingAccuracy < 0 || newHeading.headingAccuracy > 25

        Task { @MainActor in
            self.needsCalibration = poorAccuracy
            self.heading = validHeading
            self.headingUpdateCount &+= 1
            self.checkAlignment()
        }
    }

    // MARK: - Calcul Qiblah (fonctions pures, testables)

    /// Azimut orthodromique (great-circle initial bearing) vers la Kaaba,
    /// en degrés depuis le **vrai nord**, normalisé 0-360°.
    ///
    /// Même algorithme que Google Qibla Finder et la lib Adhan.
    static func qiblaBearing(latitude: Double, longitude: Double) -> Double {
        let latA = latitude * .pi / 180
        let lonA = longitude * .pi / 180

        let dLon = meccaLongitude - lonA
        let y = sin(dLon) * cos(meccaLatitude)
        let x = cos(latA) * sin(meccaLatitude) - sin(latA) * cos(meccaLatitude) * cos(dLon)
        let bearing = atan2(y, x)

        return (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Delta angulaire signé le plus court de `current` vers `target`,
    /// résultat dans [-180°, +180°]. `current` peut être non normalisé
    /// (angles cumulés de l'UI).
    static func shortestAngularDelta(from current: Double, to target: Double) -> Double {
        let currentNorm = ((current.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        var delta = target - currentNorm
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    /// Palier de proximité pour un écart angulaire donné (0-180°).
    /// 4 = ALIGNÉ (< 2°), 3 = très proche (< 5°), 2 = proche (< 10°),
    /// 1 = on s'approche (< 20°), 0 = loin.
    static func proximityLevel(forOffset offset: Double) -> Int {
        switch offset {
        case 0..<2:    return 4
        case 2..<5:    return 3
        case 5..<10:   return 2
        case 10..<20:  return 1
        default:       return 0
        }
    }

    /// Seuil supérieur (degrés) de chaque palier — pour l'hystérésis.
    private static let levelUpperBounds: [Int: Double] = [4: 2, 3: 5, 2: 10, 1: 20]
    /// On ne redescend de palier que si l'écart dépasse le seuil de 0,5°,
    /// pour éviter les re-déclenchements haptiques en oscillant sur une
    /// frontière (ex : 1,9° / 2,1° autour du palier ALIGNÉ).
    private static let hysteresisMargin: Double = 0.5

    // MARK: - Check Alignment + Haptic Progressif
    private func checkAlignment() {
        // Sans position, `qiblaAngle` vaut encore 0 (nord) : tout feedback
        // d'alignement serait mensonger.
        guard userLocation != nil else { return }

        // Écart angulaire le plus court (0-180°)
        let offset = abs(Self.shortestAngularDelta(from: heading, to: qiblaAngle))

        self.angularOffset = offset

        var newLevel = Self.proximityLevel(forOffset: offset)
        // Hystérésis à la descente uniquement
        if newLevel < proximityLevel,
           let bound = Self.levelUpperBounds[proximityLevel],
           offset < bound + Self.hysteresisMargin {
            newLevel = proximityLevel
        }

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
        guard let request = MKReverseGeocodingRequest(location: self) else {
            return "Local"
        }
        do {
            let mapItems = try await request.mapItems
            if let city = mapItems.first?.addressRepresentations?.cityName {
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

