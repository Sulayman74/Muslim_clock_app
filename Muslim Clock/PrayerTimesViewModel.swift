import Foundation
import CoreLocation
import Combine
import Adhan
import WidgetKit
import SwiftUI

// 1. Modèle pour une carte de prière
struct DailyPrayer: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let isNext: Bool
}

@MainActor
class PrayerTimesViewModel: ObservableObject {
    @Published var nextPrayerName: String = "..."
    @Published var nextPrayerTime: String = "--:--"
    private var cancellables = Set<AnyCancellable>()
    @Published var isLoading: Bool = true
    // ⏰ MINUTEUR INTERNE
    private var exactTimer: Timer?
    
    @Published var nextPrayerDate: Date? = nil
    @Published var dailyPrayers: [DailyPrayer] = []
    
    // 1. LE GARDE-FOU
    var lastLocation: CLLocation?
    private var lastCalculationDate: Date? = nil
    
    // 2. LECTURE DES RÉGLAGES UTILISATEUR (SMART SETUP)
    @AppStorage("userFajrOffset") private var fajrOffset = 0
    @AppStorage("userCalculationMethod") private var calculationMethod = "UOIF (12°)"
    @AppStorage("userMaghribOffset") private var maghribOffset = 0
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var ishaFixedDuration = 90
    @AppStorage("userIshaOffset") private var ishaOffset = 0
    @AppStorage("userDhuhrOffset") private var dhuhrOffset = 0
    @AppStorage("userAsrOffset") private var asrOffset = 0

    
    init() {
        SharedLocationManager.shared.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                self?.calculatePrayers(for: newLocation)
            }
            .store(in: &cancellables)
        // 🚀 NOUVEAU : On vérifie si l'heure a tourné pendant que le téléphone était verrouillé
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                    .sink { [weak self] _ in
                        self?.checkIfPrayerTimePassed()
                    }
                    .store(in: &cancellables)
    }
    // Fonction qui force le recalcul si on a dépassé l'heure
        private func checkIfPrayerTimePassed() {
            guard let targetDate = nextPrayerDate else { return }
            if Date() >= targetDate {
                self.forceRecalculation()
            }
        }
    // NOUVEAU : Fonction pour forcer le recalcul si l'utilisateur change un réglage
    func forceRecalculation() {
        self.lastCalculationDate = nil
        if let loc = self.lastLocation {
            calculatePrayers(for: loc)
        }
    }
    
    func calculatePrayers(for location: CLLocation) {
        let now = Date()
        
        // LE GARDE-FOU ANTI-BOUCLE
        let isSameDay = Calendar.current.isDate(now, inSameDayAs: lastCalculationDate ?? Date.distantPast)
        let isSamePlace = (lastLocation?.distance(from: location) ?? .infinity) < 2000
        
        if isSameDay && isSamePlace && !self.dailyPrayers.isEmpty {
            return
        }
        
        self.lastLocation = location
        self.lastCalculationDate = now
        
        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // ⚙️ APPLICATION DE LA MÉTHODE (ANGLES)
        var params: CalculationParameters
        
        switch calculationMethod {
        case "UOIF (12°)":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 12
            params.ishaAngle = 12
        case "ISNA (15°)":
            params = CalculationMethod.northAmerica.params
        case "Mosquée de Paris":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 18
            params.ishaAngle = 18
        default: // "Ligue Islamique (18°)"
            params = CalculationMethod.muslimWorldLeague.params
        }
        
        params.madhab = .shafi
        
        // 🎛️ APPLICATION DU TEMKINE ET DU LISSAGE
        params.adjustments.fajr = fajrOffset
        params.adjustments.dhuhr = dhuhrOffset
        params.adjustments.asr = asrOffset
        params.adjustments.maghrib = maghribOffset
        
        if isIshaFixed {
            params.ishaInterval = ishaFixedDuration
            params.adjustments.isha = maghribOffset
        } else {
            params.adjustments.isha = ishaOffset
        }
        
        let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        if let prayerTimesToday = PrayerTimes(coordinates: coordinates, date: todayComponents, calculationParameters: params) {
            updateNextPrayer(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)
            self.isLoading = false
        }
        //  📅 NOUVEAU : PLANIFICATION SUR 14 JOURS POUR LES NOTIFICATIONS
                schedule14DaysNotifications(coordinates: coordinates, params: params)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // ✅ SYNCHRONISATION VERS SHARED USERDEFAULTS
        // Le widget lit ces valeurs pour appliquer la même logique
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        let shared = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
        shared?.set(location.coordinate.latitude, forKey: "saved_latitude")
        shared?.set(location.coordinate.longitude, forKey: "saved_longitude")
        
        // Réglages de calcul
        shared?.set(calculationMethod, forKey: "w_calculationMethod")
        shared?.set(fajrOffset, forKey: "w_fajrOffset")
        shared?.set(dhuhrOffset, forKey: "w_dhuhrOffset")
        shared?.set(asrOffset, forKey: "w_asrOffset")
        shared?.set(maghribOffset, forKey: "w_maghribOffset")
        shared?.set(isIshaFixed, forKey: "w_isIshaFixed")
        shared?.set(ishaFixedDuration, forKey: "w_ishaFixedDuration")
        shared?.set(ishaOffset, forKey: "w_ishaOffset")

        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func updateNextPrayer(prayerTimesToday: PrayerTimes, coordinates: Coordinates, params: CalculationParameters) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let currentNext = prayerTimesToday.nextPrayer()
        
        self.dailyPrayers = [
            DailyPrayer(name: "Fajr", time: formatter.string(from: prayerTimesToday.fajr), isNext: currentNext == .fajr),
            DailyPrayer(name: "Dhuhr", time: formatter.string(from: prayerTimesToday.dhuhr), isNext: currentNext == .dhuhr),
            DailyPrayer(name: "Asr", time: formatter.string(from: prayerTimesToday.asr), isNext: currentNext == .asr),
            DailyPrayer(name: "Maghrib", time: formatter.string(from: prayerTimesToday.maghrib), isNext: currentNext == .maghrib),
            DailyPrayer(name: "Isha", time: formatter.string(from: prayerTimesToday.isha), isNext: currentNext == .isha)
        ]
        
        let prayerDatesToday: [Date] = [
            prayerTimesToday.fajr, prayerTimesToday.dhuhr, prayerTimesToday.asr,
            prayerTimesToday.maghrib, prayerTimesToday.isha
        ]
        
        if let next = currentNext {
            let targetDate = prayerTimesToday.time(for: next)
            self.nextPrayerDate = targetDate
            self.nextPrayerName = getPrayerName(for: next)
            self.nextPrayerTime = formatter.string(from: targetDate)
        } else {
            fetchTomorrowsFajr(coordinates: coordinates, params: params, formatter: formatter)
        }
        scheduleExactTimer(for: self.nextPrayerDate)
    }
    
    // MARK: - 📅 PLANIFICATION 14 JOURS
        private func schedule14DaysNotifications(coordinates: Coordinates, params: CalculationParameters) {
            var allDates: [Date] = []
            var allNames: [String] = []
            let calendar = Calendar.current
            
            // Boucle sur les 14 prochains jours
            for i in 0..<14 {
                if let date = calendar.date(byAdding: .day, value: i, to: Date()) {
                    let comps = calendar.dateComponents([.year, .month, .day], from: date)
                    
                    if let p = PrayerTimes(coordinates: coordinates, date: comps, calculationParameters: params) {
                        let dayPrayers = [
                            ("Fajr", p.fajr), ("Dhuhr", p.dhuhr), ("Asr", p.asr),
                            ("Maghrib", p.maghrib), ("Isha", p.isha)
                        ]
                        
                        for (name, time) in dayPrayers {
                            // On n'ajoute que les prières qui ne sont pas encore passées
                            if time > Date() {
                                allDates.append(time)
                                allNames.append(name)
                            }
                        }
                    }
                }
            }
            
            // 🚀 Envoi de tout le calendrier au gestionnaire de notifications
            // Tu devras t'assurer que ton NotificationManager a une fonction "scheduleBatchNotifications" !
            NotificationManager.shared.scheduleBatchNotifications(names: allNames, dates: allDates)
        }
        
    private func fetchTomorrowsFajr(coordinates: Coordinates, params: CalculationParameters, formatter: DateFormatter) {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        let tomorrowComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        
        if let prayerTimesTomorrow = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) {
            self.nextPrayerDate = prayerTimesTomorrow.fajr
            self.nextPrayerName = "Fajr"
            self.nextPrayerTime = formatter.string(from: prayerTimesTomorrow.fajr)
            
            if let firstIndex = self.dailyPrayers.firstIndex(where: { $0.name == "Fajr" }) {
                self.dailyPrayers[firstIndex] = DailyPrayer(name: "Fajr", time: self.dailyPrayers[firstIndex].time, isNext: true)
            }
            
        }
    }
    
    private func getPrayerName(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "Fajr"
        case .sunrise: return "Chourouq"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
    
    private func scheduleExactTimer(for target: Date?) {
            // On annule l'ancien minuteur s'il y en a un
            exactTimer?.invalidate()
            guard let targetDate = target else { return }
            
            // On calcule combien de secondes il reste avant la prière
            let timeToWait = targetDate.timeIntervalSince(Date())
            
            if timeToWait > 0 {
                // On programme le minuteur (temps d'attente + 1 seconde de sécurité)
                exactTimer = Timer.scheduledTimer(withTimeInterval: timeToWait + 1.0, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        print("⏰ Bip Bip ! Heure de la prière atteinte, rafraîchissement visuel !")
                        self?.forceRecalculation()
                    }
                }
            }
        }
}
