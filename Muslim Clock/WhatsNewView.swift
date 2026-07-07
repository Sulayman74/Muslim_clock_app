//
//  WhatsNewView.swift
//  Muslim Clock
//
//  Popup "Quoi de neuf" affichée une fois au premier lancement après une mise à jour.
//  Comparaison Bundle.shortVersion vs @AppStorage("lastSeenAppVersion") dans MainView.
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
    /// Strings via `String(localized:)` : le texte français est la clé (sourceLanguage fr)
    /// — ne pas le reformuler sans raison, ça orphelinerait les traductions en/ar.
    private let items: [WhatsNewItem] = [
        WhatsNewItem(
            icon: "books.vertical.fill",
            color: .purple,
            title: String(localized: "Programme d'apprentissage ʿIlm"),
            description: String(localized: "68 leçons pour étudier les Trois Fondements, les Quatre Règles et les 40 hadiths de Nawawi — arabe entièrement vocalisé, traduction française et notes d'authenticité.")
        ),
        WhatsNewItem(
            icon: "calendar.badge.checkmark",
            color: .green,
            title: String(localized: "Un plan à ton rythme"),
            description: String(localized: "Choisis ton texte et ta cadence : l'app estime la durée du parcours et t'envoie un rappel quotidien avec ta prochaine leçon.")
        ),
        WhatsNewItem(
            icon: "eye.slash.fill",
            color: .indigo,
            title: String(localized: "Mode Mémoriser"),
            description: String(localized: "Le texte se voile pour t'entraîner à réciter de tête, et tu peux enregistrer ta récitation pour te réécouter et te corriger.")
        ),
        WhatsNewItem(
            icon: "square.stack.3d.up.fill",
            color: .orange,
            title: String(localized: "Révision espacée"),
            description: String(localized: "Des flash cards recto/verso reviennent au bon moment (méthode Leitner) pour ancrer durablement ce que tu as appris.")
        ),
    ]

    /// Version marketing affichée sous le titre — ancre visuellement la sheet à la release.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

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
                    if !appVersion.isEmpty {
                        Text("Version \(appVersion)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
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
