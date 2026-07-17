//
//  TravelModeUI.swift
//  Muslim Clock — Mode voyage (Safar)
//
//  Surfaces SwiftUI du mode voyage : pastille d'en-tête, bannière de suggestion GPS
//  (non-intrusive), et section Réglages. Aucune logique métier ici (layout + bindings
//  uniquement, cf. CLAUDE.md) — l'intention est en @AppStorage, l'observation GPS
//  dans `TravelModeStore`.
//

import SwiftUI

// MARK: - Intégration accueil (voile + en-tête)

/// Voile d'accent posé sur le fond de l'accueil quand le mode voyage est actif.
/// Rien à afficher sinon (vue vide). Centralise ici la décision d'affichage pour
/// que `MainView` ne porte pas cette logique (cf. CLAUDE.md : pas de logique en Views).
struct TravelModeBackdrop: View {
    @AppStorage(TravelKeys.active) private var travelModeActive = false

    var body: some View {
        if travelModeActive {
            travelModeAccent.opacity(0.12)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

/// En-tête voyage de l'accueil : pastille si le mode est actif, sinon bannière de
/// suggestion GPS non-intrusive (si le GPS estime un voyage et qu'elle n'a pas été
/// ignorée cette session). Toute la décision vit ici, `MainView` n'appelle qu'une vue.
struct TravelModeHeader: View {
    @AppStorage(TravelKeys.active) private var travelModeActive = false
    @Environment(TravelModeStore.self) private var travel
    /// Suggestion ignorée pour cette session (ne réapparaît pas jusqu'au prochain lancement).
    @State private var suggestionDismissed = false

    var body: some View {
        if travelModeActive {
            TravelModePill()
                .padding(.top, 2)
        } else if travel.isTravelingByGPS && !suggestionDismissed {
            TravelSuggestionBanner(
                distanceKm: travel.distanceFromHomeKm,
                onActivate: { withAnimation { travelModeActive = true } },
                onDismiss: { withAnimation { suggestionDismissed = true } }
            )
            .padding(.top, 4)
        }
    }
}

// MARK: - Pastille d'en-tête

/// Pastille affichée en haut de l'accueil quand le mode voyage est actif.
struct TravelModePill: View {
    var body: some View {
        Label("Mode voyage", systemImage: "airplane")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(travelModeAccent.gradient, in: Capsule())
    }
}

// MARK: - Bannière de suggestion (GPS pense qu'on voyage, mode encore OFF)

/// Proposition non-intrusive : le GPS estime que l'on voyage alors que le mode est
/// inactif. Le tap active l'intention — jamais d'activation silencieuse (fiqh : niyyah).
struct TravelSuggestionBanner: View {
    let distanceKm: Int?
    /// Appelée quand l'utilisateur accepte d'activer le mode voyage.
    let onActivate: () -> Void
    /// Appelée pour ignorer la suggestion.
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.title2)
                .foregroundStyle(travelModeAccent)
                .symbolEffect(.pulse)

            VStack(alignment: .leading, spacing: 2) {
                Text("Vous semblez en voyage")
                    .font(.footnote.bold())
                    .foregroundColor(.white)
                Text(distanceKm.map { "À environ \($0) km de votre point de départ" }
                     ?? "Activer les invocations du voyageur ?")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button(action: onActivate) {
                Text("Activer")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(travelModeAccent.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .cardStyle()
    }
}

// MARK: - Section Réglages

/// Section « Mode voyage » des Réglages. Le toggle est l'intention (source de vérité) ;
/// le bouton « Définir comme domicile » re-ancre la détection (déménagement).
///
/// Vue isolée (comme `AdhkarReminderSettingsSection`) : elle seule dépend de
/// `TravelModeStore` via l'environnement, ce qui garde `SettingsView` découplée.
struct TravelModeSettingsSection: View {
    @AppStorage(TravelKeys.active) private var travelModeActive = false
    @Environment(TravelModeStore.self) private var travel
    /// Fiche des facilités : accessible en permanence (préparer un long trajet à
    /// l'avance), indépendamment de l'intention de voyage — cf. découplage SOLID.
    @State private var showFiqh = false

    var body: some View {
        Section {
            Toggle(isOn: $travelModeActive.animation()) {
                HStack(spacing: 10) {
                    Image(systemName: "airplane")
                        .foregroundColor(travelModeAccent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mode voyage")
                            .foregroundColor(.white)
                        Text("Invocations du voyageur + accent dédié")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .tint(travelModeAccent)

            Button {
                travel.markCurrentLocationAsHome()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "house.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Définir ce lieu comme domicile")
                            .foregroundColor(.white)
                        Text(travel.homeIsSet
                             ? "Recale la détection automatique de voyage"
                             : "Aucun domicile enregistré pour l'instant")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            Button {
                showFiqh = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(travelModeAccent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Facilités du voyageur")
                            .foregroundColor(.white)
                        Text("Qasr, jamʿ, jeûne — avec les preuves")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .sheet(isPresented: $showFiqh) { TravelFiqhView() }
        } header: {
            Text("Voyage")
                .foregroundColor(.white.opacity(0.6))
        } footer: {
            Text("Le mode voyage suit votre intention : vous l'activez vous-même. Le GPS ne fait que le suggérer au-delà de ~83 km de votre domicile.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .listRowBackground(Color.white.opacity(0.05))
    }
}

// MARK: - Previews

#Preview("Pastille") {
    ZStack {
        Color.black.ignoresSafeArea()
        TravelModePill()
    }
}

#Preview("Bannière de suggestion") {
    ZStack {
        Color.black.ignoresSafeArea()
        TravelSuggestionBanner(distanceKm: 312, onActivate: {}, onDismiss: {})
            .padding()
    }
}

#Preview("Section Réglages") {
    List {
        TravelModeSettingsSection()
    }
    .scrollContentBackground(.hidden)
    .background(Color.black)
    .environment(TravelModeStore())
}
