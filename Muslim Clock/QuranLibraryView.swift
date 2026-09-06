//
//  QuranLibraryView.swift
//  Muslim Clock — module Quran Library
//
//  Liste des 114 sourates avec search bar. Utilise `List` natif pour scrolling
//  performant + diffing automatique. Détection des sourates pré-cachées pour
//  warm-up des plus consultées.
//

import SwiftUI

/// Route de navigation d'un résultat de recherche plein-texte vers le lecteur.
private struct VerseSearchRoute: Hashable {
    let chapter: QuranChapterIndex
    let ayah: Int
}

struct QuranLibraryView: View {
    /// `true` : ouvre directement le champ de recherche (clavier actif) —
    /// utilisé par la rangée « Rechercher un verset » du tab Rappel.
    var searchActivated: Bool = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = QuranLibraryLoader.shared

    @State private var chapters: [QuranChapterIndex] = []
    @State private var searchText: String = ""
    @State private var searchPresented: Bool = false
    @State private var loadError: String?
    @State private var isLoading = false

    /// Résultats de la recherche plein-texte (Spotlight du Coran).
    @State private var verseMatches: [QuranVerseMatch] = []

    /// Saisie vocale (Phase 2) — le transcript remplit le champ de recherche.
    @State private var voice = QuranVerseIdentifier()

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                if chapters.isEmpty {
                    loadingOrErrorState
                } else {
                    chaptersList
                }
            }
            .navigationTitle("Sourates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                // Micro Spotlight — visible uniquement si la reco arabe
                // ON-DEVICE existe sur ce device (jamais de mode serveur).
                if QuranVerseIdentifier.isSupported {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            if voice.state == .listening {
                                voice.stop()
                            } else {
                                searchPresented = true
                                Task { await voice.start() }
                            }
                        } label: {
                            Image(systemName: voice.state == .listening
                                  ? "waveform.badge.mic"
                                  : "mic.fill")
                                .foregroundStyle(voice.state == .listening ? .red : .teal)
                        }
                        .accessibilityLabel(Text(voice.state == .listening
                                                 ? "Arrêter l'écoute"
                                                 : "Réciter un verset pour le chercher"))
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $searchPresented,
                        prompt: "Sourate, ou mots d'un verset…")
            // HUD d'écoute — hors flux (overlay), transitions explicites,
            // conteneur survivant : protocole anti-wiggle.
            .overlay(alignment: .bottom) {
                Group {
                    if voice.state == .listening {
                        listeningHUD
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.3), value: voice.state)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if searchActivated { searchPresented = true }
            await loadIfNeeded()
            // Pré-chauffe l'index de recherche plein-texte avant la 1re frappe.
            QuranSearchCorpusLoader.shared.prewarm()
        }
        .task(id: searchText) {
            // Micro-debounce : évite un match par caractère pendant la frappe.
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await runVerseSearch()
        }
        // Le transcript vocal remplit le champ — visible et ÉDITABLE (filet de
        // sécurité du cadrage Spotlight : une reco imparfaite se corrige au
        // clavier au lieu d'échouer). Le pipeline de recherche existant matche.
        .onChange(of: voice.transcript) { _, newValue in
            guard !newValue.isEmpty else { return }
            searchText = newValue
        }
        .onDisappear { voice.stop() }
        // Refus micro/reconnaissance → explication + lien Réglages.
        .alert("Autorisation nécessaire", isPresented: deniedBinding) {
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                voice.acknowledgeDenied()
            }
            Button("Plus tard", role: .cancel) { voice.acknowledgeDenied() }
        } message: {
            Text(deniedMessage)
        }
    }

    // MARK: - Saisie vocale

    private var listeningHUD: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(.teal)
                .symbolEffect(.variableColor.iterative, isActive: true)
            Text("Récite, je t'écoute…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button {
                voice.stop()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56) // plancher anti-wiggle
        .glassCard(cornerRadius: 18, tint: .teal)
        .geometryGroup()
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var deniedBinding: Binding<Bool> {
        Binding(
            get: { if case .denied = voice.state { return true } else { return false } },
            set: { if !$0 { voice.acknowledgeDenied() } }
        )
    }

    private var deniedMessage: String {
        if case .denied(let kind) = voice.state, kind == .speech {
            return String(localized: "Autorise la reconnaissance vocale pour chercher un verset en le récitant. Tout est traité sur ton appareil, rien n'est envoyé.")
        }
        return String(localized: "Autorise le micro pour chercher un verset en le récitant. Tout est traité sur ton appareil, rien n'est envoyé.")
    }

    // MARK: - Recherche plein-texte (versets)

    private var arabicTokenCount: Int {
        QuranSearchNormalizer.tokens(searchText).count
    }

    private func runVerseSearch() async {
        let query = searchText
        guard QuranSearchNormalizer.tokens(query).count >= QuranVerseIndex.minimumQueryTokens,
              let index = await QuranSearchCorpusLoader.shared.loadIndex() else {
            verseMatches = []
            return
        }
        let matches = index.match(query: query)
        // La requête a pu changer pendant le chargement de l'index.
        if query == searchText { verseMatches = matches }
    }

    /// Résout la sourate d'un résultat : index réseau si chargé, sinon fallback
    /// offline construit depuis les métadonnées du corpus bundlé (suffisant
    /// pour ouvrir le lecteur — le type mecquois/médinois n'y est pas affiché).
    private func chapterIndex(for sura: Int) -> QuranChapterIndex? {
        if let found = chapters.first(where: { $0.id == sura }) { return found }
        guard let meta = QuranSearchCorpusLoader.shared.suraMeta[sura] else { return nil }
        return QuranChapterIndex(id: sura, name: meta.arabicName,
                                 transliteration: meta.englishName, translation: nil,
                                 type: "", totalVerses: meta.verseCount, link: nil)
    }

    // MARK: - States

    @ViewBuilder
    private var loadingOrErrorState: some View {
        if isLoading {
            ProgressView()
                .tint(.teal)
                .scaleEffect(1.4)
        } else if let err = loadError {
            VStack(spacing: 14) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange.opacity(0.8))
                Text("Impossible de charger l'index des sourates.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button {
                    Task { await loadIfNeeded(forceReload: true) }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.teal.gradient)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
            }
            .padding(40)
        }
    }

    // MARK: - Liste

    private var filteredChapters: [QuranChapterIndex] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return chapters }
        let needle = searchText.lowercased()
        return chapters.filter { chapter in
            chapter.transliteration.lowercased().contains(needle)
                || chapter.translation?.lowercased().contains(needle) == true
                || String(chapter.id) == needle
        }
    }

    private var chaptersList: some View {
        List {
            // ── Résultats plein-texte (Spotlight du Coran) ──
            if !verseMatches.isEmpty {
                Section {
                    ForEach(verseMatches) { match in
                        verseResultRows(match)
                    }
                } header: {
                    Text("Versets")
                        .foregroundStyle(.teal)
                }
                .listRowBackground(Color.white.opacity(0.05))
            } else if (1..<QuranVerseIndex.minimumQueryTokens).contains(arabicTokenCount) {
                Section {
                    Label("Tape au moins 3 mots du verset", systemImage: "text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .listRowBackground(Color.white.opacity(0.05))
            }

            // ── Sourates ──
            Section {
                ForEach(filteredChapters) { chapter in
                    NavigationLink(value: chapter) {
                        ChapterRow(chapter: chapter)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationDestination(for: QuranChapterIndex.self) { chapter in
            QuranChapterDetailView(chapterIndex: chapter)
        }
        .navigationDestination(for: VerseSearchRoute.self) { route in
            QuranChapterDetailView(chapterIndex: route.chapter, scrollToAyah: route.ayah)
        }
    }

    /// Ligne(s) d'un résultat : le verset représentant + les autres occurrences
    /// repliées dans un DisclosureGroup (refrain d'Ar-Rahman ×31…).
    @ViewBuilder
    private func verseResultRows(_ match: QuranVerseMatch) -> some View {
        if let chapter = chapterIndex(for: match.ref.sura) {
            NavigationLink(value: VerseSearchRoute(chapter: chapter, ayah: match.ref.ayah)) {
                VerseMatchRow(match: match, chapter: chapter)
            }
            if match.occurrences.count > 1 {
                DisclosureGroup {
                    ForEach(match.occurrences.dropFirst(), id: \.self) { occ in
                        if let occChapter = chapterIndex(for: occ.sura) {
                            NavigationLink(value: VerseSearchRoute(chapter: occChapter, ayah: occ.ayah)) {
                                Text("\(occChapter.transliteration) · verset \(occ.ayah)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .monospacedDigit()
                            }
                        }
                    }
                } label: {
                    Text("\(match.occurrences.count - 1) autres occurrences")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.teal.opacity(0.85))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Loading

    private func loadIfNeeded(forceReload: Bool = false) async {
        if !chapters.isEmpty && !forceReload { return }
        isLoading = true
        loadError = nil
        if let result = await loader.loadIndex() {
            chapters = result
            // Warm-up : pré-charge les sourates courtes les plus consultées (Fatiha, Yasin,
            // Mulk, Kahf, etc.) en arrière-plan pour fluidifier l'ouverture.
            loader.prefetch(chapterIds: [1, 18, 36, 67, 112, 113, 114])
        } else {
            loadError = "Vérifie ta connexion réseau, puis réessaie."
        }
        isLoading = false
    }
}

// MARK: - Rangée d'accès (tab Rappel, section « Références »)

/// Point d'entrée direct du Spotlight du Coran : ouvre la bibliothèque avec le
/// champ de recherche actif (1 tap au lieu de 3). En Phase 2, le micro de
/// recherche vocale vivra dans la même barre — cette entrée le portera aussi.
struct QuranVerseSearchRow: View {
    @State private var showSearch = false

    var body: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "text.magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.teal)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Rechercher un verset")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Sourate, ou mots d'un verset")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .glassCardSecondary(cornerRadius: 16, tint: .teal, fallback: GlassFallback.warm)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showSearch)
        .sheet(isPresented: $showSearch) {
            QuranLibraryView(searchActivated: true)
        }
    }
}

// MARK: - Ligne de résultat verset

private struct VerseMatchRow: View {
    let match: QuranVerseMatch
    let chapter: QuranChapterIndex

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.teal.opacity(0.35), .teal.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.teal)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(chapter.transliteration) · verset \(match.ref.ayah)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    if match.occurrences.count > 1 {
                        Text(verbatim: "×\(match.occurrences.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.teal)
                            .chipStyle(color: .teal)
                    }
                }
                // Extrait imla'i vocalisé — RTL explicite (protocole anti-wiggle : le
                // contenu est stable par ligne, pas d'animation implicite).
                Text(verbatim: match.displayText)
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Row

private struct ChapterRow: View {
    let chapter: QuranChapterIndex

    var body: some View {
        HStack(spacing: 12) {
            // Numéro dans un cercle stylé
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.teal.opacity(0.35), .teal.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                Text("\(chapter.id)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(chapter.transliteration)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if chapter.isMeccan {
                        Text("Mecque")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text("Médine")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                if let translation = chapter.translation {
                    Text(translation)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Text("\(chapter.totalVerses) versets")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Text(chapter.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.vertical, 4)
    }
}
