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
            icon: "book.pages.fill",
            color: .teal,
            title: "Khatma du Quran",
            description: "Planifie ta lecture (1 Juz/jour, ½, ¼ ou Khatma Ramadan), suis tes progrès avec des stats et reçois des rappels doux après chaque prière."
        ),
        WhatsNewItem(
            icon: "bell.badge.circle.fill",
            color: .orange,
            title: "Live Activity « Prochaine Salât »",
            description: "Bannière live 30 min avant chaque prière sur l'écran verrouillé et la Dynamic Island. Compte à rebours en temps réel."
        ),
        WhatsNewItem(
            icon: "switch.2",
            color: .indigo,
            title: "Contrôles Centre de Contrôle (iOS 18+)",
            description: "Ajoute « Qibla » et « Adhkar du moment » à ton Centre de Contrôle, au bouton Action ou à ton écran verrouillé."
        ),
        WhatsNewItem(
            icon: "sparkles",
            color: .yellow,
            title: "Affinage de l'expérience",
            description: "Transitions plus fluides au passage français ↔ arabe, accessibilité améliorée, stabilité visuelle et optimisations pour grandes tailles de texte."
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
