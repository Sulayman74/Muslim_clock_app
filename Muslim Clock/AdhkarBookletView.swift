//
//  AdhkarBookletView.swift
//  Muslim Clock — Livret d'invocations (type Hisn al-Muslim, authentifié)
//
//  Écran principal : « Suggéré maintenant » (contextuel aux horaires de prière)
//  puis la liste complète des catégories. Contenu bundle + remote via
//  RemoteJSONLoader (DRY — même pipeline que adhkar.json).
//

import SwiftUI

struct AdhkarBookletView: View {
    /// Si fourni, le livret s'ouvre directement sur le détail de cette catégorie
    /// (raccourci depuis la mini-suggestion de l'accueil). Le retour révèle la liste.
    var initialCategoryID: String? = nil

    @EnvironmentObject private var prayerVM: PrayerTimesViewModel

    @State private var categories: [AdhkarCategory] = []
    @State private var isLoading = true
    /// Instant de référence pour les suggestions, rafraîchi à l'ouverture.
    @State private var referenceDate = Date()
    /// Pile de navigation (ids de catégorie) — permet le push initial programmatique.
    @State private var path: [String] = []

    private static let remoteURL = "https://sulayman74.github.io/Muslim_clock_app/hisn_adhkar.json"
    private let accent = Color(red: 0.4, green: 0.7, blue: 0.75)

    /// Catégories mises en avant selon le moment (fonction pure, testable).
    private var suggested: [AdhkarCategory] {
        AdhkarSuggestion.suggested(
            from: categories,
            now: referenceDate,
            prayerDates: prayerVM.dailyPrayers.map(\.date),
            fajr: prayerVM.fajrDate,
            lastThirdOfNight: prayerVM.lastThirdOfNight
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                if isLoading && categories.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else if categories.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Invocations")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { id in
                if let category = categories.first(where: { $0.id == id }) {
                    AdhkarCategoryDetailView(category: category)
                }
            }
        }
        .task {
            referenceDate = Date()
            let loaded = await RemoteJSONLoader.load(
                filename: "hisn_adhkar.json",
                remoteURL: Self.remoteURL,
                type: [AdhkarCategory].self
            )
            categories = loaded ?? []
            isLoading = false
            // Push initial vers la catégorie demandée (raccourci mini-suggestion).
            if let initialCategoryID,
               path.isEmpty,
               categories.contains(where: { $0.id == initialCategoryID }) {
                path = [initialCategoryID]
            }
        }
    }

    // MARK: - Contenu

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                if !suggested.isEmpty {
                    section(
                        title: String(localized: "Suggéré maintenant"),
                        systemImage: "sparkles",
                        categories: suggested,
                        highlighted: true
                    )
                }

                section(
                    title: String(localized: "Toutes les catégories"),
                    systemImage: "square.grid.2x2.fill",
                    categories: categories,
                    highlighted: false
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private func section(
        title: String,
        systemImage: String,
        categories: [AdhkarCategory],
        highlighted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(highlighted ? accent : .white.opacity(0.6))

            ForEach(categories) { category in
                NavigationLink(value: category.id) {
                    CategoryRow(category: category, accent: accent, highlighted: highlighted)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text("Livret indisponible pour le moment.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(40)
    }
}

// MARK: - Ligne de catégorie

private struct CategoryRow: View {
    let category: AdhkarCategory
    let accent: Color
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(highlighted ? 0.22 : 0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.titleFr)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(category.titleAr)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .environment(\.layoutDirection, .rightToLeft)
            }

            Spacer()

            Text(verbatim: "\(category.adhkar.count)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(tint: highlighted ? accent : nil)
    }
}

// MARK: - Bouton d'accès (tab Salat)

/// Point d'entrée du livret depuis l'écran principal. Ouvre `AdhkarBookletView`
/// en sheet, en transmettant `PrayerTimesViewModel` pour la suggestion contextuelle.
struct AdhkarBookletButton: View {
    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    @State private var show = false
    private let accent = Color(red: 0.4, green: 0.7, blue: 0.75)

    var body: some View {
        Button {
            show = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Livret d'invocations")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Selon la situation — sources authentifiées")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .glassCard(tint: accent)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: show)
        .sheet(isPresented: $show) {
            AdhkarBookletView()
                .environmentObject(prayerVM)
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Mini-suggestion contextuelle (tab Salat)

/// Card « À réciter maintenant » : met en avant la catégorie pertinente au moment
/// présent (via `AdhkarSuggestion`) avec un aperçu de sa première invocation.
/// N'occupe aucun espace tant qu'aucune catégorie n'est pertinente. Au tap, ouvre
/// le livret directement sur cette catégorie (lecture immédiate + accès au livret).
struct AdhkarMomentCard: View {
    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    @State private var categories: [AdhkarCategory] = []
    @State private var showBooklet = false
    private let accent = Color(red: 0.4, green: 0.7, blue: 0.75)

    private var topCategory: AdhkarCategory? {
        AdhkarSuggestion.suggested(
            from: categories,
            now: Date(),
            prayerDates: prayerVM.dailyPrayers.map(\.date),
            fajr: prayerVM.fajrDate,
            lastThirdOfNight: prayerVM.lastThirdOfNight
        ).first
    }

    var body: some View {
        Group {
            if let category = topCategory {
                card(for: category)
            }
        }
        .task {
            if categories.isEmpty {
                categories = await RemoteJSONLoader.load(
                    filename: "hisn_adhkar.json",
                    remoteURL: "https://sulayman74.github.io/Muslim_clock_app/hisn_adhkar.json",
                    type: [AdhkarCategory].self
                ) ?? []
            }
        }
    }

    private func card(for category: AdhkarCategory) -> some View {
        Button {
            showBooklet = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: category.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(accent)
                    Text("À réciter maintenant")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Text(category.titleFr)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                if let first = category.adhkar.first {
                    Text(first.arabic)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .padding(16)
            .glassCard(tint: accent)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showBooklet)
        .sheet(isPresented: $showBooklet) {
            AdhkarBookletView(initialCategoryID: category.id)
                .environmentObject(prayerVM)
                .presentationDragIndicator(.visible)
        }
    }
}
