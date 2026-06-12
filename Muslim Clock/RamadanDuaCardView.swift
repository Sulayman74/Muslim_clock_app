//
//  RamadanDuaCardView.swift
//  Muslim Clock — module Ramadan
//
//  Carte affichée dans MainView uniquement pendant le mois de Ramadan.
//  Sélectionne contextuellement une du'a (Iftar / Suhoor / général) selon
//  l'heure courante et les horaires de prière.
//

import SwiftUI

struct RamadanDuaCardView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @State private var service = RamadanDuaService()
    /// Tick toutes les minutes pour redéterminer la fenêtre (iftar ↔ suhoor ↔ general)
    /// sans recharger le JSON.
    @State private var tick: Int = 0

    private var maghribDate: Date? {
        prayerVM.dailyPrayers.first { $0.name == "Maghrib" }?.date
    }
    private var ishaDate: Date? {
        prayerVM.dailyPrayers.first { $0.name == "Isha" }?.date
    }

    private var window: RamadanDuaWindow {
        _ = tick // force la dépendance reactive
        return RamadanDuaService.currentWindow(
            now: .now,
            maghrib: maghribDate,
            isha: ishaDate,
            fajr: prayerVM.fajrDate
        )
    }

    private var dua: RamadanDua? {
        service.dua(for: window)
    }

    // MARK: - Palette par fenêtre

    private var accent: Color {
        switch window {
        case .iftar:   return .orange
        case .suhoor:  return Color(red: 0.6, green: 0.5, blue: 0.85) // violet doux nuit
        case .general: return .teal
        }
    }

    private var icon: String {
        switch window {
        case .iftar:   return "sunset.fill"
        case .suhoor:  return "moon.stars.fill"
        case .general: return "moon.fill"
        }
    }

    private var title: String {
        switch window {
        case .iftar:   return String(localized: "Du'a de l'Iftar")
        case .suhoor:  return String(localized: "Du'a du Suhoor")
        case .general: return String(localized: "Du'a du Ramadan")
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let dua {
                content(dua: dua)
            } else if service.isLoading {
                placeholder
            } else {
                // Échec total du chargement (réseau + cache + bundle) — on n'affiche rien
                // plutôt qu'un fallback codé en dur. Le bundle servira presque toujours.
                EmptyView()
            }
        }
        .task {
            await service.loadIfNeeded()
        }
        .task {
            // Tick minute pour réévaluer la fenêtre contextuelle.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                tick &+= 1
            }
        }
    }

    @ViewBuilder
    private func content(dua: RamadanDua) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête : icône + titre + badge catégorie
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Text(verbatim: title)
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                Spacer()
            }

            // Arabe (RTL)
            Text(verbatim: dua.arabic)
                .font(.custom("AmiriQuran-Regular", size: 22))
                .lineSpacing(8)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .foregroundColor(.white)

            // Traduction FR
            Text(verbatim: dua.french)
                .font(.system(size: 14, design: .rounded))
                .italic()
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // Source
            HStack {
                Spacer()
                Text(verbatim: dua.source)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(accent.opacity(0.18)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            ProgressView().tint(accent)
            Text("Chargement de la du'a...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
