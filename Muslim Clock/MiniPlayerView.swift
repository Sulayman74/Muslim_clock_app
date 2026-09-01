//
//  MiniPlayerView.swift
//  Muslim Clock
//
//  iOS 26 — Mini Player pour tabViewBottomAccessory + Full Player
//

import SwiftUI
import Combine

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
    var tintColor: Color = .orange
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. BARRE DE PROGRESSION CONTINUE (sans texte)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                    
                    Rectangle()
                        .fill(tintColor)
                        // Calcul sécurisé pour éviter un frame négatif ou NaN
                        .frame(width: max(0, manager.duration > 0 ? geo.size.width * CGFloat(manager.currentTime / manager.duration) : 0))
                }
            }
            .frame(height: 2) // 🔒 Hauteur figée
            
            // 2. CONTENU DU PLAYER
            HStack(spacing: 12) {
                // Bouton Play/Pause avec frame fixe
                Button {
                    if let id = manager.currentlyPlayingID, let ep = manager.episodes.first(where: { $0.id == id }) {
                        manager.togglePlay(episode: ep)
                    }
                } label: {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44) // 🔒 Verrouille la taille de la zone de tap
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                
                // Textes limités à 1 ligne
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.currentEpisodeTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text(manager.podcastTitle)
                        .font(.caption)
                        .foregroundColor(tintColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading) // 🔒 Pousse au fond sans trembler
                
                // 🌊 ONDES AUDIO (couleur dynamique)
                MiniAudioWaveView(isPlaying: manager.isPlaying, color: tintColor)
                    .padding(.trailing, 4)
                
                // Bouton pour ouvrir le grand player
                Button {
                    manager.showFullPlayer = true
                } label: {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(tintColor.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56) // 🔒 HAUTEUR STRICTEMENT FIXE (Le secret anti-wiggle)
            .contentShape(Rectangle()) // Permet de cliquer sur toute la barre
            .onTapGesture {
                manager.showFullPlayer = true
            }
        }
        .glassEffect(.clear, in: .rect(cornerRadius: 20))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 🌊 COMPOSANT ONDE AUDIO (GPU ACCELERATED - ZÉRO TREMBLEMENT)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct MiniAudioWaveView: View {
    var isPlaying: Bool
    var color: Color = .orange
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            // Barre 1
            Capsule()
                .fill(color)
                .frame(width: 3, height: 16) // 🔒 Frame physique intouchable
                .scaleEffect(y: isPlaying ? (isAnimating ? 0.8 : 0.3) : 0.2, anchor: .bottom)
                .animation(isPlaying ? .easeInOut(duration: 0.4).repeatForever(autoreverses: true) : .spring(), value: isAnimating)
            
            // Barre 2
            Capsule()
                .fill(color)
                .frame(width: 3, height: 16)
                .scaleEffect(y: isPlaying ? (isAnimating ? 0.4 : 1.0) : 0.2, anchor: .bottom)
                .animation(isPlaying ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true) : .spring(), value: isAnimating)
            
            // Barre 3
            Capsule()
                .fill(color)
                .frame(width: 3, height: 16)
                .scaleEffect(y: isPlaying ? (isAnimating ? 0.9 : 0.4) : 0.2, anchor: .bottom)
                .animation(isPlaying ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .spring(), value: isAnimating)
        }
        .frame(width: 18, height: 16) // 🔒 Taille globale complètement verrouillée
        .onAppear {
            isAnimating = isPlaying
        }
        .onChange(of: isPlaying) { oldState, newState in
            isAnimating = newState
        }
    }
}
    

// MARK: - ═══════════════════════════════════════════════════
// FULL PLAYER (sheet modale — affiché depuis MainView)
// ═══════════════════════════════════════════════════════════

struct FullPlayerView: View {
    @ObservedObject var manager: PodcastManager
    var tintColor: Color = .orange
    @Environment(\.dismiss) private var dismiss
    @State private var showPlaylist = false
    
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
                    showPlaylist = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tintColor.opacity(0.7))
                        .padding(10)
                }
                Button {
                    dismiss()
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        manager.stopAndClose()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(tintColor.opacity(0.4))
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
                    Image(systemName: "waveform")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                        .frame(width: 280, height: 280)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                }
            }
            .padding(.bottom, 30)
            
            // ── TITRE & AUTEUR ──
            VStack(spacing: 6) {
                Text(verbatim: manager.currentEpisodeTitle)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .environment(\.layoutDirection, .rightToLeft)
                
                Text(verbatim: manager.podcastAuthor)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                
                // INDICATEUR DE PROGRESSION DE LA SÉRIE
                if manager.seriesProgress > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10))
                        Text("Série complétée à \(manager.seriesProgress, format: .percent.precision(.fractionLength(0)))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15))
                    .clipShape(Capsule())
                }
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
                .tint(tintColor)
                
                HStack {
                    Text(verbatim: playbackTimeLabel(manager.currentTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: "-\(playbackTimeLabel(max(0, manager.duration - manager.currentTime)))")
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
                        .foregroundStyle(tintColor.opacity(0.7))
                }
                
                Button { manager.skipBackward() } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(tintColor)
                }
                
                Button {
                    if manager.isPlaying {
                        if let id = manager.currentlyPlayingID,
                           let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    } else if manager.currentTime > 5 {
                        manager.resume()
                    } else {
                        if let id = manager.currentlyPlayingID,
                           let ep = manager.episodes.first(where: { $0.id == id }) {
                            manager.togglePlay(episode: ep)
                        }
                    }
                } label: {
                    Group {
                        if manager.isBuffering {
                            ProgressView().tint(.white).scaleEffect(1.3)
                        } else {
                            Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(tintColor)
                                .offset(x: manager.isPlaying ? 0 : 2)
                        }
                    }
                    .frame(width: 70, height: 70)
                    .glassEffect(.regular.tint(tintColor.opacity(0.15)).interactive(), in: Circle())
                }
                
                Button { manager.skipForward() } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundStyle(tintColor)
                }
                
                Button { manager.playNextEpisode() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(tintColor.opacity(0.7))
                }
            }
            .padding(.bottom, 24)
            
            // ── VITESSE ──
            HStack {
                Spacer()
                Button { manager.cyclePlaybackRate() } label: {
                    Text(verbatim: rateLabel(manager.playbackRate))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .glassEffect(.clear.tint(tintColor.opacity(0.10)), in: Capsule())
                }
                Spacer()
            }
        }
        // Feedback haptique moderne (.sensoryFeedback) — fire automatiquement
        // au changement du trigger. Pas besoin de wrapper les Buttons.
        .sensoryFeedback(.impact(weight: .light), trigger: manager.isPlaying)
        .sensoryFeedback(.selection, trigger: manager.playbackRate)
        .sheet(isPresented: $showPlaylist) {
            PlaylistView(manager: manager, tintColor: tintColor)
        }
    }

    private func rateLabel(_ rate: Float) -> String {
        if rate == 1.0 { return "1x" }
        if rate == 1.25 { return "1.25x" }
        if rate == 1.5 { return "1.5x" }
        if rate == 2.0 { return "2x" }
        return "\(rate)x"
    }
}
// MARK: - ═══════════════════════════════════════════════════
// WAVEFORM ANIMÉE (Simple & Performante)
// ═══════════════════════════════════════════════════════════

struct AnimatedWaveformIcon: View {
    let isPlaying: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(isPlaying ? 0.2 : 0.1))

            // TimelineView paused hors lecture : l'ancien Timer.publish(0.15 s)
            // réveillait le runloop ~7×/s même podcast en pause. Ici, zéro tick
            // dès que isPlaying == false.
            TimelineView(.animation(minimumInterval: 0.15, paused: !isPlaying)) { timeline in
                let heights = barHeights(at: timeline.date)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: isPlaying
                                        ? [Color.orange, Color.orange.opacity(0.6)]
                                        : [Color.white.opacity(0.5), Color.white.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2.5, height: 16 * (isPlaying ? heights[index] : 0.3))
                            .animation(.easeInOut(duration: 0.15), value: heights[index])
                            // Retombée douce des barres au passage en pause.
                            .animation(.easeOut(duration: 0.3), value: isPlaying)
                    }
                }
            }
        }
    }

    /// Hauteurs pseudo-aléatoires **déterministes** — fonction pure du temps
    /// (hash sinusoïdal par pas de 0.15 s). Même rendu visuel qu'un random par
    /// tick, sans @State ni Timer.
    private func barHeights(at date: Date) -> [CGFloat] {
        let step = floor(date.timeIntervalSinceReferenceDate / 0.15)
        return (0..<5).map { index in
            let raw = sin(step * 12.9898 + Double(index) * 78.233) * 43758.5453
            let unit = raw - floor(raw) // fraction 0..<1 pseudo-aléatoire
            return 0.3 + CGFloat(unit) * 0.7
        }
    }
}


