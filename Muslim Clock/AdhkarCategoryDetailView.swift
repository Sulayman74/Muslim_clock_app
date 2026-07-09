//
//  AdhkarCategoryDetailView.swift
//  Muslim Clock — Livret d'invocations
//
//  Détail d'une catégorie : liste des invocations en consultation seule.
//  Réutilise `DhikrCardView` en mode consultation (`onTap: nil` → badge « ×N »
//  statique + badge d'authenticité), donc aucune logique de compteur ici.
//

import SwiftUI

struct AdhkarCategoryDetailView: View {
    let category: AdhkarCategory

    /// Accent cohérent avec le reste du livret.
    private let accent = Color(red: 0.4, green: 0.7, blue: 0.75)

    /// Toggles locaux d'affichage (langue / bienfait) par dhikr — comme AdhkarView.
    @State private var showArabic: [Int: Bool] = [:]
    @State private var showBenefit: [Int: Bool] = [:]

    var body: some View {
        ZStack {
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(category.adhkar) { dhikr in
                        DhikrCardView(
                            dhikr: dhikr,
                            repeatCount: dhikr.repeat,
                            count: 0,
                            isCompleted: false,
                            showArabic: showArabic[dhikr.id] ?? true,
                            showBenefit: showBenefit[dhikr.id] ?? false,
                            accentColor: accent,
                            onTap: nil,   // consultation seule
                            onToggleArabic: { showArabic[dhikr.id] = !(showArabic[dhikr.id] ?? true) },
                            onToggleBenefit: { showBenefit[dhikr.id] = !(showBenefit[dhikr.id] ?? false) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(category.titleFr)
        .navigationBarTitleDisplayMode(.inline)
    }
}
