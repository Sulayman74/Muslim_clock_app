//
//  AdhkarCategoryDetailView.swift
//  Muslim Clock — Livret d'invocations
//
//  Détail d'une catégorie : liste des invocations en consultation seule.
//  Réutilise `DhikrCardView` en mode consultation (`onTap: nil` → badge « ×N »
//  statique + badge d'authenticité), donc aucune logique de compteur ici.
//

import SwiftUI

/// Accent commun au livret d'invocations.
let adhkarBookletAccent = Color(red: 0.4, green: 0.7, blue: 0.75)

/// Liste d'invocations en consultation seule, avec toggles langue/bienfait locaux.
/// Factorisée pour être réutilisée par le détail d'une catégorie ET les résultats
/// de recherche (DRY).
struct DhikrConsultationList: View {
    let adhkar: [Dhikr]
    var accent: Color = adhkarBookletAccent

    @State private var showArabic: [Int: Bool] = [:]
    @State private var showBenefit: [Int: Bool] = [:]

    var body: some View {
        LazyVStack(spacing: 14) {
            ForEach(adhkar) { dhikr in
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
    }
}

struct AdhkarCategoryDetailView: View {
    let category: AdhkarCategory

    var body: some View {
        ZStack {
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                DhikrConsultationList(adhkar: category.adhkar)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle(category.titleFr)
        .navigationBarTitleDisplayMode(.inline)
    }
}
