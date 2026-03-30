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
    
    @Published var isLoading: Bool = true
    
    // LA NOUVEAUTÉ : On stocke la date exacte (Objectif)
    @Published var nextPrayerDate: Date? = nil
    
    @Published var dailyPrayers: [DailyPrayer] = []
    
    func calculatePrayers(for location: CLLocation) {
        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        var params = CalculationMethod.muslimWorldLeague.params
        params.madhab = .shafi
        
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        if let prayerTimes = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) {
            updateNextPrayer(prayerTimes: prayerTimes)
            self.isLoading = false
        }
    }
    
    private func updateNextPrayer(prayerTimes: PrayerTimes) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let currentNext = prayerTimes.nextPrayer()
        
        self.dailyPrayers = [
            DailyPrayer(name: "Fajr", time: formatter.string(from: prayerTimes.fajr), isNext: currentNext == .fajr),
            DailyPrayer(name: "Dhuhr", time: formatter.string(from: prayerTimes.dhuhr), isNext: currentNext == .dhuhr),
            DailyPrayer(name: "Asr", time: formatter.string(from: prayerTimes.asr), isNext: currentNext == .asr),
            DailyPrayer(name: "Maghrib", time: formatter.string(from: prayerTimes.maghrib), isNext: currentNext == .maghrib),
            DailyPrayer(name: "Isha", time: formatter.string(from: prayerTimes.isha), isNext: currentNext == .isha)
        ]
        
        let prayerDates: [Date] = [
                    prayerTimes.fajr,
                    prayerTimes.dhuhr,
                    prayerTimes.asr,
                    prayerTimes.maghrib,
                    prayerTimes.isha
                ]
        NotificationManager.shared.schedulePrayerNotifications(prayers: self.dailyPrayers, prayerDates: prayerDates)
        
        if let next = currentNext {
            // On sauvegarde la date exacte pour le décompte SwiftUI natif !
            let targetDate = prayerTimes.time(for: next)
            self.nextPrayerDate = targetDate
            
            self.nextPrayerName = getPrayerName(for: next)
            self.nextPrayerTime = formatter.string(from: targetDate)
        } else {
            // Si on a passé l'Isha, on remet à zéro
            self.nextPrayerDate = nil
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
