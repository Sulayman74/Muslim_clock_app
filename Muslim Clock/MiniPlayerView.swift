//
//  MiniPlayerView.swift
//  Muslim Clock
//
//  iOS 26 Liquid Glass — Mini Player + Expanded Player
//

import SwiftUI

// MARK: - ═══════════════════════════════════════════════════
// MINI PLAYER BAR (flottant en bas de l'écran)
// Tap → ouvre le full player en sheet
// ═══════════════════════════════════════════════════════════

struct MiniPlayerBar: View {
    @ObservedObject var manager: PodcastManager
    @State private var showFullPlayer = false
    
    var body: some View {
        // N'afficher que si un épisode est en cours
        if manager.currentlyPlayingID != nil {
            VStack(spacing: 0) {
                // Mini barre de progression en haut
                GeometryReader { geo in
                    Capsule()
                        .fill(.orange)
                        .frame(
                            width: manager.duration > 0
                                ? geo.size.width * CGFloat(manager.currentTime / manager.duration)
                                : 0,
                            height: 2.5
                        )
                        .animation(.linear(duration: 0.5), value: manager.currentTime)
                }
                .frame(height: 2.5)
                
                HStack(spacing: 14) {
                    // Artwork mini
                    AsyncImage(url: manager.podcastArtworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                    
                    // Titre (scrolling si long)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.currentEpisodeTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Text(manager.podcastAuthor)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Bouton skip back
                    Button { manager.skipBackward() } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    
                    // Play / Pause
                    Button {
                        if let id = manager.currentlyPlayingID,
                           let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    } label: {
                        Group {
                            if manager.isBuffering {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22))
                            }
                        }
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.white)
                    }
                    
                    // Bouton skip forward
                    Button { manager.skipForward() } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture { showFullPlayer = true }
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView(manager: manager)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// FULL PLAYER (sheet modale)
// Artwork + titre + scrubber + contrôles + vitesse
// ═══════════════════════════════════════════════════════════

struct FullPlayerView: View {
    @ObservedObject var manager: PodcastManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── Drag indicator zone ──
            Spacer().frame(height: 20)
            
            // ── ARTWORK ──
            AsyncImage(url: manager.podcastArtworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
                        // Animation Apple Music style
                        .scaleEffect(manager.isPlaying ? 1.0 : 0.88)
                        .animation(.interpolatingSpring(stiffness: 80, damping: 12), value: manager.isPlaying)
                default:
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .frame(width: 280, height: 280)
                        .overlay(
                            Image(systemName: "waveform")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .padding(.bottom, 30)
            
            // ── TITRE & AUTEUR ──
            VStack(spacing: 6) {
                Text(manager.currentEpisodeTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .environment(\.layoutDirection, .rightToLeft)
                
                Text(manager.podcastAuthor)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // ── SCRUBBER / TIMELINE ──
            VStack(spacing: 6) {
                // Le slider natif
                Slider(
                    value: Binding(
                        get: { manager.currentTime },
                        set: { newValue in
                            manager.isSeeking = true
                            manager.currentTime = newValue
                        }
                    ),
                    in: 0...(max(manager.duration, 1)),
                    onEditingChanged: { editing in
                        if !editing {
                            manager.seek(to: manager.currentTime)
                        }
                    }
                )
                .tint(.orange)
                
                // Temps écoulé / restant
                HStack {
                    Text(formatTime(manager.currentTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("-\(formatTime(max(0, manager.duration - manager.currentTime)))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // ── CONTRÔLES DE LECTURE ──
            HStack(spacing: 40) {
                // Épisode précédent
                Button { manager.playPreviousEpisode() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                // Skip -15s
                Button { manager.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
                
                // Play / Pause (gros bouton central)
                Button {
                    if let id = manager.currentlyPlayingID,
                       let ep = manager.episodes.first(where: { $0.id == id }) {
                        manager.togglePlay(episode: ep)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        if manager.isBuffering {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.3)
                        } else {
                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                                // Petit offset pour centrer visuellement le triangle Play
                                .offset(x: manager.isPlaying ? 0 : 2)
                        }
                    }
                }
                
                // Skip +15s
                Button { manager.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
                
                // Épisode suivant
                Button { manager.playNextEpisode() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 24)
            
            // ── VITESSE DE LECTURE ──
            HStack(spacing: 16) {
                Spacer()
                
                // Bouton vitesse
                Button { manager.cyclePlaybackRate() } label: {
                    Text(rateLabel(manager.playbackRate))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )
                }
                
                Spacer()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func rateLabel(_ rate: Float) -> String {
        if rate == 1.0 { return "1x" }
        if rate == 1.25 { return "1.25x" }
        if rate == 1.5 { return "1.5x" }
        if rate == 2.0 { return "2x" }
        return "\(rate)x"
    }
}
