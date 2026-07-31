//
//  PlaylistView.swift
//  Muslim Clock
//
//  File d'attente verticale de la série audio : liste scrollable + recherche,
//  auto-scroll vers l'épisode en cours, reprise par épisode. Présentée en sheet
//  depuis l'accueil (« Voir tout ») et depuis le plein écran (« file d'attente »).
//

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var manager: PodcastManager
    var tintColor: Color = .orange
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    /// Épisodes filtrés par la recherche (insensible à la casse et aux diacritiques
    /// — gère le français accentué et l'arabe vocalisé).
    private var filtered: [PodcastEpisode] {
        guard !query.isEmpty else { return manager.episodes }
        return manager.episodes.filter {
            PodcastMath.episodeMatches(title: $0.title, query: query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, episode in
                        row(index: index, episode: episode)
                            .id(episode.id)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $query, prompt: Text("Rechercher un épisode"))
                .onAppear {
                    // Auto-scroll vers l'épisode en cours à l'ouverture.
                    guard query.isEmpty, let id = manager.currentlyPlayingID else { return }
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .navigationTitle(Text(verbatim: manager.podcastTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(tintColor.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Ligne d'épisode

    @ViewBuilder
    private func row(index: Int, episode: PodcastEpisode) -> some View {
        let isCurrent = manager.currentlyPlayingID == episode.id
        let isPlayed = manager.isEpisodePlayed(episode: episode)
        let position = manager.positionFor(episode: episode)

        Button {
            manager.togglePlay(episode: episode)
        } label: {
            HStack(spacing: 12) {
                // Indicateur : onde si en lecture, sinon numéro d'ordre.
                ZStack {
                    if isCurrent && manager.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(tintColor)
                    } else {
                        Text(verbatim: "\(index + 1)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isPlayed ? .secondary : .primary)
                    }
                }
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: episode.title)
                        .font(.system(size: 15, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isPlayed ? .secondary : .primary)
                        .lineLimit(2)
                    // Reprise disponible pour cet épisode (position mémorisée, non terminé).
                    if position > 5 && !isPlayed {
                        Text(verbatim: "Reprendre à \(playbackTimeLabel(position))")
                            .font(.caption2)
                            .foregroundStyle(tintColor)
                    }
                }

                Spacer(minLength: 8)

                if isPlayed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.green.opacity(0.8))
                } else if isCurrent {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tintColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
