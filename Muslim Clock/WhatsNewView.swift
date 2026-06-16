//
//  WhatsNewView.swift
//  Muslim Clock
//
//  Popup "Quoi de neuf" affichée une fois au premier lancement après une mise à jour.
//  Comparaison Bundle.shortVersion vs @AppStorage("lastSeenVersion") dans MainView.
//

import SwiftUI

struct WhatsNewItem: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let description: String
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    /// Liste des nouveautés. À mettre à jour à chaque release.
    private let items: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "moon.stars.fill",
            color: .orange,
            title: "Mode Ramadan adaptatif",
            description: "Pendant le mois béni, les widgets Home prennent une teinte ambre lanterne, un badge « Iftar » apparaît à côté de Maghrib et « Fin du Sohoor » à côté de Fajr. Le nom canonique des prières reste préservé partout."
        ),
        WhatsNewItem(
            icon: "hands.sparkles.fill",
            color: .teal,
            title: "Du'a au bon moment",
            description: "Une carte contextuelle s'affiche pour l'iftar (Abu Dawud 2357), pendant la nuit du sahari (Bukhari 1923) et durant les 10 dernières nuits avec la du'a de Laylatul Qadr (Tirmidhi 3513)."
        ),
        WhatsNewItem(
            icon: "book.pages.fill",
            color: .indigo,
            title: "Khatma plus sobre",
            description: "Le suivi de lecture met l'accent sur la régularité avec un indicateur sobre — pour rester fidèle à l'esprit du wird sans glisser vers la gamification."
        ),
        WhatsNewItem(
            icon: "questionmark.circle.fill",
            color: .gray,
            title: "Transparence éditoriale",
            description: "Une page « Pourquoi pas de tracker de prière ? » explique le choix de ne pas gamifier la salât, conforme à la fatwa du Cheikh Ibn 'Uthaymîn (Majmû' al-Fatâwâ 16/111)."
        ),
        WhatsNewItem(
            icon: "location.north.line.fill",
            color: .teal,
            title: "Qibla plus précise",
            description: "Fusion CoreMotion 60 Hz pour une aiguille fluide, sans secousses ni « tour fantôme » lors des changements brusques d'orientation."
        ),
        WhatsNewItem(
            icon: "sparkles",
            color: .yellow,
            title: "Stabilité & performances",
            description: "Robustesse du chargement des contenus religieux, fluidité du module Khatma, et conformité totale au nouveau privacy manifest Apple."
        ),
    ]

    var body: some View {
        ZStack {
            // Fond cohérent avec les autres sheets de l'app
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                        .symbolEffect(.bounce, value: items.count)
                    Text("Quoi de neuf")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Text("Découvre les nouveautés de cette mise à jour")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 40)
                .padding(.bottom, 28)

                // Items
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }

                // CTA
                Button {
                    dismiss()
                } label: {
                    Text("Continuer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(
                            colors: [.orange, .orange.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func itemRow(_ item: WhatsNewItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(item.color.opacity(0.18), lineWidth: 1)
        )
    }
}
