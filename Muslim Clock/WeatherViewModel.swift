import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import Combine
import os

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var temperature: String = "--°C"
    @Published var conditionIcon: String = "cloud.fill"
    @Published var moonSymbol: String = "moon"

    @Published var isLoading: Bool = true
    @Published var hasError: Bool = false

    /// Attribution WeatherKit — REQUISE par Apple (App Review guideline 5.2.5).
    /// Doit être affichée visuellement (logo + texte « Weather ») partout où des données
    /// météo sont rendues, avec lien tap vers `legalPageURL` (sources des données).
    /// Cachée après le premier fetch — pas besoin de la recharger à chaque requête.
    @Published var attribution: WeatherAttribution?

    // MARK: - Constantes anti-spam

    /// Distance minimale (mètres) pour considérer qu'on a "bougé" et déclencher un refetch.
    private static let locationThresholdMeters: Double = 5_000

    /// Délai minimal (secondes) entre deux fetches au même endroit.
    private static let fetchCooldownSeconds: TimeInterval = 1_800   // 30 min

    /// Cooldown minimal après une erreur — évite le spam si l'API WeatherKit est down.
    private static let errorRetryCooldownSeconds: TimeInterval = 100

    // MARK: - State interne

    private var lastLocation: CLLocation?
    private var lastFetchTime: Date?

    /// Task en cours — annulée si un nouveau fetch arrive (évite la race condition
    /// où une location change pendant un fetch en cours laisserait 2 updates UI
    /// concurrents et un quota WeatherKit gaspillé).
    private var currentFetchTask: Task<Void, Never>?

    let weatherService = WeatherService()

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "Weather")

    // MARK: - API publique

    /// Bypass l'anti-spam : utilisé sur pull-to-refresh ou retour de connexion.
    func forceRefresh(for location: CLLocation) async {
        lastFetchTime = nil
        lastLocation = nil
        await fetchWeather(for: location)
    }

    /// Récupère la météo si nécessaire (passe le bouclier anti-spam).
    ///
    /// Garanties :
    /// - Skip silencieusement si bouclier actif (même position < 5 km et < 30 min).
    /// - Annule tout fetch en cours avant d'en lancer un nouveau.
    /// - L'attribution Apple Weather est chargée une seule fois (cachée ensuite).
    func fetchWeather(for location: CLLocation) async {
        // 🛑 BOUCLIER ANTI-SPAM
        let movedFar = (lastLocation?.distance(from: location) ?? .infinity) >= Self.locationThresholdMeters
        let cooledDown = Date().timeIntervalSince(lastFetchTime ?? .distantPast) >= Self.fetchCooldownSeconds

        if !movedFar && !cooledDown && !hasError {
            return
        }

        // 🛑 ANNULATION DU FETCH EN COURS (évite race condition)
        currentFetchTask?.cancel()

        // Mémorise immédiatement pour que les appels concurrents qui arriveraient
        // entre-temps voient déjà la dernière localisation et passent le bouclier.
        self.lastLocation = location
        self.lastFetchTime = Date()
        self.isLoading = true

        let task = Task { @MainActor [weak self] in
            await self?.performFetch(for: location)
            return ()
        }
        self.currentFetchTask = task
        await task.value
    }

    // MARK: - Privé

    private func performFetch(for location: CLLocation) async {
        do {
            let (current, daily) = try await weatherService.weather(
                for: location,
                including: .current, .daily
            )

            // Si l'appel a été cancelled entre-temps, ne touche pas l'UI.
            try Task.checkCancellation()

            let tempValue = current.temperature.converted(to: .celsius).value
            self.temperature = String(format: "%.0f°C", tempValue)
            self.conditionIcon = current.symbolName

            if let todayForecast = daily.first {
                self.moonSymbol = todayForecast.moon.phase.symbolName
            }

            // Charge l'attribution Apple une seule fois (cachée ensuite).
            if self.attribution == nil {
                await loadAttribution()
            }

            self.isLoading = false
            self.hasError = false
            Self.logger.info("Weather fetched: \(self.temperature, privacy: .public)")

        } catch is CancellationError {
            // Annulation propre par un fetch plus récent — ne touche pas l'UI.
            Self.logger.debug("Weather fetch cancelled (superseded)")
        } catch {
            Self.logger.error("WeatherKit failure: \(error.localizedDescription, privacy: .public)")
            self.temperature = "--°C"
            self.conditionIcon = "exclamationmark.triangle"
            self.moonSymbol = "moon.fill"
            self.hasError = true
            self.isLoading = false

            // Throttle anti-spam erreur : permet un retry après 100 s (au lieu de
            // tout de suite), évite de marteler l'API WeatherKit en cas de panne.
            self.lastFetchTime = Date().addingTimeInterval(Self.errorRetryCooldownSeconds - Self.fetchCooldownSeconds)
        }
    }

    /// Charge l'attribution WeatherKit (logo + URL de page légale).
    /// Échec silencieux : l'UI affiche un fallback texte « Weather » si l'image ne charge pas.
    private func loadAttribution() async {
        do {
            self.attribution = try await weatherService.attribution
        } catch {
            Self.logger.warning("Attribution fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
