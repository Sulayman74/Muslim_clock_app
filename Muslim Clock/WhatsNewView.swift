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
            icon: "airplane",
            color: travelModeAccent,
            title: String(localized: "Mode voyage (Safar)"),
            description: String(localized: "L'app détecte quand tu t'éloignes de chez toi et te propose d'activer le mode voyage — invocations du voyageur mises en avant et accent dédié. Rien n'est jamais activé à ta place : le voyage suit ton intention.")
        ),
        WhatsNewItem(
            icon: "book.closed.fill",
            color: .indigo,
            title: String(localized: "Facilités du voyageur"),
            description: String(localized: "Une fiche claire sur le raccourcissement (qasr), le regroupement (jamʿ) et le jeûne en voyage — chaque règle appuyée par ses preuves : Coran, Sunna authentique et paroles de savants.")
        ),
        WhatsNewItem(
            icon: "hands.and.sparkles.fill",
            color: .green,
            title: String(localized: "Nouvelles invocations authentiques"),
            description: String(localized: "Le livret s'enrichit : invocations du voyage, du jeûne et invocations générales du quotidien, chacune avec sa source et son degré d'authenticité.")
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
