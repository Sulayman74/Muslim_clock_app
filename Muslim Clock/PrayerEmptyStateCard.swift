//
//  PrayerEmptyStateCard.swift
//  Muslim Clock — onglet Salat, état vide
//
//  Sans position (refusée, jamais demandée, introuvable) ou si le calcul échoue,
//  l'écran n'affichait que des squelettes, sans rien dire ni rien proposer.
//  Cette carte nomme la situation et donne UNE action. Elle ne prend aucune
//  place quand tout va bien (le ZStack conteneur survit pour animer l'entrée/sortie).
//

import SwiftUI
import CoreLocation

struct PrayerEmptyStateCard: View {
    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    @ObservedObject private var location = SharedLocationManager.shared
    @Environment(\.openURL) private var openURL

    /// Délai avant de considérer qu'aucun point GPS n'arrivera (squelette borné).
    private static let searchTimeout: TimeInterval = 8
    @State private var searchTimedOut = false

    private enum Situation: Equatable {
        case accessDenied, permissionNotAsked, positionNotFound, calculationFailed
    }

    private var situation: Situation? {
        if location.isAccessDenied { return .accessDenied }
        if location.authorizationStatus == .notDetermined { return .permissionNotAsked }
        if location.currentLocation == nil { return searchTimedOut ? .positionNotFound : nil }
        if prayerVM.calculationFailed { return .calculationFailed }
        return nil
    }

    var body: some View {
        // Espacement porté par la carte elle-même : absente, elle ne laisse
        // aucun trou dans la pile (la zone est en `spacing: 0`).
        ZStack {
            if let situation {
                card(situation)
                    .padding(.bottom, ZoneSpacing.intraZonePrimary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.35), value: situation)
        // Borne le squelette : relancé si la position arrive ou disparaît.
        .task(id: location.currentLocation == nil) {
            searchTimedOut = false
            guard location.currentLocation == nil else { return }
            try? await Task.sleep(for: .seconds(Self.searchTimeout))
            guard !Task.isCancelled else { return }
            searchTimedOut = true
        }
    }

    // MARK: - Carte

    private func card(_ situation: Situation) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon(situation))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PrayerStateTint.upcoming)

            Text(title(situation))
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message(situation))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                perform(situation)
            } label: {
                Text(actionLabel(situation))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .glassEffect(.regular.tint(PrayerStateTint.upcoming.opacity(0.25)), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Contenu par situation

    private func icon(_ s: Situation) -> String {
        switch s {
        case .accessDenied: "location.slash.fill"
        case .permissionNotAsked: "location.fill"
        case .positionNotFound: "location.magnifyingglass"
        case .calculationFailed: "exclamationmark.triangle.fill"
        }
    }

    private func title(_ s: Situation) -> LocalizedStringKey {
        switch s {
        case .accessDenied: "Localisation désactivée"
        case .permissionNotAsked: "Où êtes-vous ?"
        case .positionNotFound: "Position introuvable"
        case .calculationFailed: "Horaires indisponibles"
        }
    }

    private func message(_ s: Situation) -> LocalizedStringKey {
        switch s {
        case .accessDenied: "Impossible de calculer les horaires sans votre position. Autorisez la localisation dans les Réglages."
        case .permissionNotAsked: "Les horaires de prière dépendent de votre position."
        case .positionNotFound: "Aucun point GPS reçu. Vérifiez que la localisation est active, puis réessayez."
        case .calculationFailed: "Le calcul des horaires a échoué pour cette position."
        }
    }

    private func actionLabel(_ s: Situation) -> LocalizedStringKey {
        switch s {
        case .accessDenied: "Ouvrir les Réglages"
        case .permissionNotAsked: "Autoriser la localisation"
        case .positionNotFound, .calculationFailed: "Réessayer"
        }
    }

    private func perform(_ s: Situation) {
        switch s {
        case .accessDenied:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        case .permissionNotAsked:
            location.requestPermissionAndStart()
        case .positionNotFound:
            Task { await location.refreshLocation() }
        case .calculationFailed:
            prayerVM.forceRecalculation()
        }
    }
}
