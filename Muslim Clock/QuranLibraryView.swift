//
//  QuranLibraryView.swift
//  Muslim Clock — module Quran Library
//
//  Liste des 114 sourates avec search bar. Utilise `List` natif pour scrolling
//  performant + diffing automatique. Détection des sourates pré-cachées pour
//  warm-up des plus consultées.
//

import SwiftUI

struct QuranLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = QuranLibraryLoader.shared

    @State private var chapters: [QuranChapterIndex] = []
    @State private var searchText: String = ""
    @State private var loadError: String?
    @State private var isLoading = false

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
            }
            .searchable(text: $searchText, prompt: "Rechercher une sourate…")
        }
        .preferredColorScheme(.dark)
        .task { await loadIfNeeded() }
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
        List(filteredChapters) { chapter in
            NavigationLink(value: chapter) {
                ChapterRow(chapter: chapter)
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .scrollContentBackground(.hidden)
        .navigationDestination(for: QuranChapterIndex.self) { chapter in
            QuranChapterDetailView(chapterIndex: chapter)
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
