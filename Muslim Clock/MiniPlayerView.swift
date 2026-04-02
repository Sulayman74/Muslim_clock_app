//
//  MiniPlayerView.swift
//  Muslim Clock
//
//  iOS 26 — Mini Player pour tabViewBottomAccessory + Full Player
//

import SwiftUI

// MARK: - ═══════════════════════════════════════════════════
// MINI PLAYER BAR (ultra-léger pour tabViewBottomAccessory)
//
// ⚠️ IMPORTANT : tabViewBottomAccessory re-crée sa vue à chaque
// redraw de la tab bar. On ne met RIEN de lourd ici :
// - Pas d'AsyncImage (→ clignotement réseau)
// - Pas de @State (→ réinitialisé à chaque redraw)
// - Pas de .sheet (→ s'ouvre/ferme tout seul)
//
// Le sheet est géré dans MainView via podcastManager.showFullPlayer
// ═══════════════════════════════════════════════════════════

struct MiniPlayerBar: View {
    @ObservedObject var manager: PodcastManager
    
    var body: some View {
        // 1. Un VStack global pour empiler les boutons et la barre de progression
        VStack(spacing: 0) {
            
            // ── LA ZONE DES BOUTONS ET TEXTES ──
            HStack(spacing: 14) {
                
                // ZONE TAPPABLE (Ouvre le Full Player)
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.2)) // Petit fond pour faire ressortir l'icône
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.currentEpisodeTitle)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        
                        // LE SOUS-TITRE CAMÉLÉON
                        if manager.isPlaying {
                            // En lecture : Temps actuel / Temps total
                            Text("\(formatTime(manager.currentTime)) / \(formatTime(manager.duration))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.orange)
                        } else if manager.currentTime > 5 {
                            // En pause : Reprendre à...
                            Text("Reprendre à \(formatTime(manager.currentTime))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            // Au tout début : Auteur
                            Text(manager.podcastAuthor)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.showFullPlayer = true
                }
                
                // ── BOUTONS DE CONTRÔLE ──
                Button {
                    // Ta logique Play/Pause
                    if manager.isPlaying {
                        if let id = manager.currentlyPlayingID, let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    } else if manager.currentTime > 5 {
                        manager.resumeFromBookmark()
                    } else {
                        if let id = manager.currentlyPlayingID, let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    }
                } label: {
                    Group {
                        if manager.isBuffering {
                            ProgressView().tint(.primary)
                        } else {
                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                
                Button { manager.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            
            // ── 🌟 LA BARRE DE PROGRESSION ULTRA-FINE ──
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Fond de la barre (Gris transparent)
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                    
                    // Remplissage orange
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: max(0, geo.size.width * CGFloat(manager.currentTime / max(manager.duration, 1))))
                }
            }
            .frame(height: 2) // Seulement 2 pixels de haut !
        }
        // Design global du lecteur
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16)) // Coupe les bords pour que la barre suive l'arrondi en bas
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
    

// MARK: - ═══════════════════════════════════════════════════
// FULL PLAYER (sheet modale — affiché depuis MainView)
// ═══════════════════════════════════════════════════════════

struct FullPlayerView: View {
    @ObservedObject var manager: PodcastManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── TOP BAR ──
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(10)
                }
                Spacer()
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        manager.stopAndClose()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.orange.opacity(0.2))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 25)
            .padding(.bottom, 10)
            
            // ── ARTWORK (AsyncImage OK ici — le sheet ne se re-crée pas en boucle) ──
            AsyncImage(url: manager.podcastArtworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280, maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
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
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .environment(\.layoutDirection, .rightToLeft)
                
                Text(manager.podcastAuthor)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // ── SCRUBBER ──
            VStack(spacing: 6) {
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
                        if !editing { manager.seek(to: manager.currentTime) }
                    }
                )
                .tint(.orange)
                
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
            
            // ── CONTRÔLES ──
            HStack(spacing: 40) {
                Button { manager.playPreviousEpisode() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.orange.opacity(0.7))
                }
                
                Button { manager.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                }
                
                Button {
                    if manager.isPlaying {
                        if let id = manager.currentlyPlayingID,
                           let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    } else if manager.currentTime > 5 {
                        manager.resumeFromBookmark()
                    } else {
                        if let id = manager.currentlyPlayingID,
                           let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(.orange.opacity(0.2), lineWidth: 0.5))
                        
                        if manager.isBuffering {
                            ProgressView().tint(.white).scaleEffect(1.3)
                        } else {
                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.orange)
                                .offset(x: manager.isPlaying ? 0 : 2)
                        }
                    }
                }
                
                Button { manager.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                }
                
                Button { manager.playNextEpisode() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.orange.opacity(0.7))
                }
            }
            .padding(.bottom, 24)
            
            // ── VITESSE ──
            HStack {
                Spacer()
                Button { manager.cyclePlaybackRate() } label: {
                    Text(rateLabel(manager.playbackRate))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.orange.opacity(0.15), lineWidth: 0.5))
                }
                Spacer()
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
    
    private func rateLabel(_ rate: Float) -> String {
        if rate == 1.0 { return "1x" }
        if rate == 1.25 { return "1.25x" }
        if rate == 1.5 { return "1.5x" }
        if rate == 2.0 { return "2x" }
        return "\(rate)x"
    }
}
