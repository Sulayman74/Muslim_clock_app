import Foundation
import CoreLocation
import Combine
import Adhan

// 1. On crée un modèle pour une carte de prière
struct DailyPrayer: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let isNext: Bool // Pour surligner la prochaine prière !
}

@MainActor
class PrayerTimesViewModel: ObservableObject {
    @Published var nextPrayerName: String = "..."
    @Published var nextPrayerTime: String = "--:--"
    private var cancellables = Set<AnyCancellable>()
    @Published var isLoading: Bool = true
    
    // LA NOUVEAUTÉ : On stocke la date exacte (Objectif)
    @Published var nextPrayerDate: Date? = nil
    
    @Published var dailyPrayers: [DailyPrayer] = []
    private var lastLocation: CLLocation?
    init() {
            // Dès que le GPS trouve une nouvelle ville, ça déclenche le calcul !
            SharedLocationManager.shared.$currentLocation
                .compactMap { $0 } // Ignore les valeurs nil
                .sink { [weak self] newLocation in
                    self?.calculatePrayers(for: newLocation)
                }
                .store(in: &cancellables)
        }
    
    func calculatePrayers(for location: CLLocation) {
        self.lastLocation = location
        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        var params = CalculationMethod.muslimWorldLeague.params
        params.madhab = .shafi
        
        let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        if let prayerTimesToday = PrayerTimes(coordinates: coordinates, date: todayComponents, calculationParameters: params) {
                    updateNextPrayer(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)
                    self.isLoading = false
                }
        let sharedDefaults = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
        sharedDefaults?.set(location.coordinate.latitude, forKey: "saved_latitude")
        sharedDefaults?.set(location.coordinate.longitude, forKey: "saved_longitude")
    }
    
    private func updateNextPrayer(prayerTimesToday: PrayerTimes, coordinates: Coordinates, params: CalculationParameters) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            
            let currentNext = prayerTimesToday.nextPrayer()
            
            // 1. On prépare l'affichage de la liste pour AUJOURD'HUI
            self.dailyPrayers = [
                DailyPrayer(name: "Fajr", time: formatter.string(from: prayerTimesToday.fajr), isNext: currentNext == .fajr),
                DailyPrayer(name: "Dhuhr", time: formatter.string(from: prayerTimesToday.dhuhr), isNext: currentNext == .dhuhr),
                DailyPrayer(name: "Asr", time: formatter.string(from: prayerTimesToday.asr), isNext: currentNext == .asr),
                DailyPrayer(name: "Maghrib", time: formatter.string(from: prayerTimesToday.maghrib), isNext: currentNext == .maghrib),
                DailyPrayer(name: "Isha", time: formatter.string(from: prayerTimesToday.isha), isNext: currentNext == .isha)
            ]
            
            // Notifications pour aujourd'hui
            let prayerDatesToday: [Date] = [
                prayerTimesToday.fajr, prayerTimesToday.dhuhr, prayerTimesToday.asr,
                prayerTimesToday.maghrib, prayerTimesToday.isha
            ]
            NotificationManager.shared.schedulePrayerNotifications(prayers: self.dailyPrayers, prayerDates: prayerDatesToday)
            
            // 2. LA MAGIE DU WRAP-AROUND : On détermine la VRAIE prochaine prière
            if let next = currentNext {
                // Il reste une prière aujourd'hui
                let targetDate = prayerTimesToday.time(for: next)
                self.nextPrayerDate = targetDate
                self.nextPrayerName = getPrayerName(for: next)
                self.nextPrayerTime = formatter.string(from: targetDate)
            } else {
                // On a passé l'Isha. On doit chercher le Fajr de DEMAIN.
                fetchTomorrowsFajr(coordinates: coordinates, params: params, formatter: formatter)
            }
        }
        
    // NOUVELLE MÉTHODE : Va chercher le Fajr de demain
        private func fetchTomorrowsFajr(coordinates: Coordinates, params: CalculationParameters, formatter: DateFormatter) {
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
            let tomorrowComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            
            if let prayerTimesTomorrow = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) {
                
                // La prochaine prière est le Fajr de demain
                self.nextPrayerDate = prayerTimesTomorrow.fajr
                self.nextPrayerName = "Fajr"
                self.nextPrayerTime = formatter.string(from: prayerTimesTomorrow.fajr)
                
                // Optionnel : On peut forcer l'highlight sur le Fajr dans la liste d'aujourd'hui
                // pour montrer qu'on a "bouclé" la journée.
                if let firstIndex = self.dailyPrayers.firstIndex(where: { $0.name == "Fajr" }) {
                    self.dailyPrayers[firstIndex] = DailyPrayer(name: "Fajr", time: self.dailyPrayers[firstIndex].time, isNext: true)
                }
                
                // On programme la notification pour le Fajr de demain en une seule ligne !
                NotificationManager.shared.scheduleSinglePrayer(name: "Fajr", date: prayerTimesTomorrow.fajr)
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
}
