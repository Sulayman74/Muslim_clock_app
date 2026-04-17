import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import Combine

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var temperature: String = "22°C"
    @Published var conditionIcon: String = "cloud.sun.fill"
    @Published var moonSymbol: String = "moon"
    
    @Published var isLoading: Bool = true
    @Published var hasError: Bool = false
    
    // 🛡️ NOUVEAU : Mémoire pour le bouclier anti-spam
    private var lastLocation: CLLocation?
    private var lastFetchTime: Date?
    
    let weatherService = WeatherService()

    /// Bypass l'anti-spam : utilisé sur pull-to-refresh ou retour de connexion.
    func forceRefresh(for location: CLLocation) async {
        lastFetchTime = nil
        lastLocation  = nil
        await fetchWeather(for: location)
    }

    func fetchWeather(for location: CLLocation) async {
        
        // 🛑 BOUCLIER ANTI-SPAM
        // 1. A-t-on bougé de moins de 5 kilomètres ?
        let isSameLocation = (lastLocation?.distance(from: location) ?? .infinity) < 5000
        // 2. La dernière requête date-t-elle de moins de 30 minutes (1800 secondes) ?
        let isRecent = Date().timeIntervalSince(lastFetchTime ?? .distantPast) < 1800
        
        // Si on est au même endroit et que c'est récent (et qu'il n'y a pas d'erreur à réparer), on stoppe !
        if isSameLocation && isRecent && !hasError {
            return
        }
        
        // Si on passe le bouclier, on mémorise cette nouvelle requête
        self.lastLocation = location
        self.lastFetchTime = Date()
        self.isLoading = true
        
        do {
            let (current, daily) = try await weatherService.weather(for: location, including: .current, .daily)
            
            let tempValue = current.temperature.converted(to: .celsius).value
            self.temperature = String(format: "%.0f°C", tempValue)
            self.conditionIcon = current.symbolName
            
            if let todayForecast = daily.first {
                self.moonSymbol = todayForecast.moon.phase.symbolName
                print("🌖 WeatherKit a bien renvoyé la lune : \(self.moonSymbol)")
            }
            
            self.isLoading = false
            self.hasError = false
            
        } catch {
            print("❌ Erreur API WeatherKit : \(error.localizedDescription)")
            self.temperature = "N/A"
            self.conditionIcon = "exclamationmark.triangle"
            self.moonSymbol = "moon.fill"
            self.hasError = true
            self.isLoading = false
            
            // En cas d'erreur, on reset le timer pour autoriser un nouvel essai rapide
            self.lastFetchTime = nil
        }
    }
}
