//
//  RamadanDuaCardView.swift
//  Muslim Clock — module Ramadan
//
//  Carte affichée dans MainView uniquement pendant le mois de Ramadan.
//  Sélectionne contextuellement une du'a (Iftar / Suhoor / général) selon
//  l'heure courante et les horaires de prière.
//
//  Règles d'affichage :
//  - Iftar  : Maghrib ± 30 min — toujours affichée
//  - Suhoor : Isha → Fajr — toujours affichée
//  - Général (Laylatul Qadr) : seulement durant les 10 dernières nuits (jour hijri ≥ 20)
//

import SwiftUI

struct RamadanDuaCardView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @State private var service = RamadanDuaService()
    /// Tick toutes les minutes pour redéterminer la fenêtre (iftar ↔ suhoor ↔ general)
    /// sans recharger le JSON.
    @State private var tick: Int = 0
    /// Override DEBUG — observer pour rafraîchir immédiatement la card quand le
    /// picker change dans SettingsView. Pas d'effet en Release (clé toujours vide).
    @AppStorage("debugRamadanWindow") private var debugRamadanWindow: String = ""
    /// Langue de l'app — détermine si on affiche la traduction (masquée si arabe).
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    private var maghribDate: Date? {
        prayerVM.dailyPrayers.first { $0.name == "Maghrib" }?.date
    }
    private var ishaDate: Date? {
        prayerVM.dailyPrayers.first { $0.name == "Isha" }?.date
    }

    private var window: RamadanDuaWindow {
        _ = tick // force la dépendance reactive sur le tick minute
        _ = debugRamadanWindow // observe l'override DEBUG pour refresh instantané
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

    /// Jour hijri courant (respecte l'override DEBUG `debugSeasonDate`).
    private var hijriDay: Int {
        IslamicSeasonInfo.current().hijriDay
    }

    /// La carte n'est rendue que si elle a un sens dans le moment courant :
    /// - fenêtres Iftar et Suhoor → toujours
    /// - fenêtre Général → seulement durant les 10 dernières nuits (jour ≥ 20)
    ///
    /// En DEBUG, un override explicite via le picker `debugRamadanWindow` bypasse
    /// la règle des 10 nuits pour faciliter les tests de n'importe quelle catégorie.
    private var shouldDisplay: Bool {
        #if DEBUG
        if !debugRamadanWindow.isEmpty { return true }
        #endif
        if window == .general && hijriDay < 20 { return false }
        return true
    }

    /// `true` si l'app affiche son contenu en arabe (langue explicite ou système).
    /// Quand vrai, on masque la traduction FR : l'arabe parle de lui-même.
    private var isArabicUI: Bool {
        if appLanguage == "ar" { return true }
        if appLanguage == "system" {
            return Locale.current.language.languageCode?.identifier == "ar"
        }
        return false
    }

    // MARK: - Palette par fenêtre

    private var accent: Color {
        switch window {
        case .iftar:   return .orange
        case .suhoor:  return IslamicSeasonInfo.ramadanNightTint
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
        // Le ZStack reste toujours présent dans l'arbre de vue (même quand
        // `shouldDisplay` est false ou que le pool est vide) — c'est ce qui
        // garantit que `.task` s'attache et déclenche le chargement initial.
        // Avec un simple `Group { if ... }` vide, SwiftUI optimise la branche
        // et la `.task` ne fire jamais → pool reste vide pour toujours.
        ZStack {
            if shouldDisplay {
                if let dua {
                    content(dua: dua)
                } else if service.isLoading {
                    placeholder
                }
            }
        }
        .task {
            await service.loadIfNeeded()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                tick &+= 1
            }
        }
    }

    @ViewBuilder
    private func content(dua: RamadanDua) -> some View {
        VStack(spacing: 14) {
            // En-tête centré
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(verbatim: title)
                    .font(.caption.bold())
            }
            .foregroundStyle(accent)

            // Arabe — toujours affiché, centré
            Text(verbatim: dua.arabic)
                .font(.custom("AmiriQuran-Regular", size: 22))
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)

            // Traduction — masquée si l'UI est en arabe
            if !isArabicUI {
                Text(verbatim: dua.french)
                    .font(.system(size: 14, design: .rounded))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Source centrée
            Text(verbatim: dua.source)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(tint: accent)
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
