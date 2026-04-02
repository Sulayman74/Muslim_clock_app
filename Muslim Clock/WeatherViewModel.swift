//
//  WeatherService.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//

import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import Combine


@MainActor // Sécurise les mises à jour UI pour éviter l'erreur de concurrence
class WeatherViewModel: ObservableObject {
        // Textes "bidons" de la bonne longueur pour que le Skeleton ait une belle forme
        @Published var temperature: String = "22°C"
        @Published var conditionIcon: String = "cloud.sun.fill"
        @Published var moonSymbol: String = "moonphase.new.moon"
        // NOUVEAU : Gestion des états pour l'UX
        @Published var isLoading: Bool = true
        @Published var hasError: Bool = false
        private var hasFetched: Bool = false
        let weatherService = WeatherService()

    
    func fetchWeather(for location: CLLocation) async {
            guard !hasFetched else { return }
            hasFetched = true
            
            do {
                let weather = try await weatherService.weather(for: location)
                let tempValue = weather.currentWeather.temperature.converted(to: .celsius).value
                self.temperature = String(format: "%.0f°C", tempValue)
                self.conditionIcon = weather.currentWeather.symbolName
                // On regarde le premier jour du tableau des prévisions (aujourd'hui)
                if let todayForecast = weather.dailyForecast.first {
                self.moonSymbol = todayForecast.moon.phase.symbolName
                }
                self.isLoading = false
                self.hasError = false
            } catch {
                self.temperature = "N/A"
                self.conditionIcon = "exclamationmark.triangle"
                self.moonSymbol = "moon.fill"
                self.hasError = true
                self.isLoading = false
                self.hasFetched = false
            }
        }
    
    }


