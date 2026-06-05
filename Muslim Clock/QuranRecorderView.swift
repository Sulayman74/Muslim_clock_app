//
//  QuranRecorderView.swift
//  Muslim Clock — module Quran Library
//
//  Sheet d'enregistrement de récitation : permission → record → playback → share.
//  Délègue toute la mécanique audio à `QuranRecorder` (service @Observable).
//

import SwiftUI
import AVFoundation

struct QuranRecorderView: View {
    /// Nom affiché de la sourate (ex: "Al-Fatiha").
    let suraDisplayName: String
    /// Slug ASCII utilisé pour le nom de fichier (ex: "AlFatiha").
    let suraSlug: String

    @Environment(\.dismiss) private var dismiss
    @State private var recorder = QuranRecorder()
    /// Animation pulse du bouton record.
    @State private var pulse: Bool = false
    /// Hauteur courante de la sheet — `.medium` pendant recording/playback pour laisser
    /// voir le texte du Coran au-dessus, `.large` sinon (UI riche + illustrations).
    @State private var detent: PresentationDetent = .large

    var body: some View {
        ZStack {
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            VStack(spacing: 14) {
                // Le header (titre + Fermer) n'est utile qu'en grand format.
                // En mini-bar : on libère l'espace, la poignée native suffit pour fermer.
                if detent != .height(220) {
                    header
                }
                Spacer(minLength: 4)
                content
                Spacer(minLength: 4)
                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .presentationDetents([.height(220), .medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationContentInteraction(.scrolls)
        .onChange(of: recorder.state) { _, newState in
            switch newState {
            case .recording, .playingBack:
                // Mini-bar : libère ~3/4 d'écran pour lire la sourate sous la sheet.
                detent = .height(220)
            case .idle, .requestingPermission, .permissionDenied, .recorded, .error:
                detent = .large
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            // Si on quitte la sheet pendant un enregistrement → discard pour libérer le micro.
            if case .recording = recorder.state {
                recorder.discard()
            } else if case .playingBack = recorder.state {
                recorder.pausePlayback()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Fermer") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text("Enregistrement")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            // Bouton invisible pour équilibrer le layout horizontal.
            Button("Fermer") { }.opacity(0).disabled(true)
        }
    }

    // MARK: - Content (état-dépendant)

    @ViewBuilder
    private var content: some View {
        switch recorder.state {
        case .idle, .requestingPermission:
            idleContent
        case .permissionDenied:
            permissionDeniedContent
        case .recording(let elapsed):
            recordingContent(elapsed: elapsed)
        case .recorded(_, let duration):
            recordedContent(duration: duration)
        case .playingBack(let progress, let duration):
            playingBackContent(progress: progress, duration: duration)
        case .error(let message):
            errorContent(message: message)
        }
    }

    private var idleContent: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.teal.opacity(0.35), .indigo.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                Image(systemName: "mic.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.teal)
            }

            VStack(spacing: 6) {
                Text("Prêt à enregistrer")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Récitation de \(suraDisplayName)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text("Durée maximale : 10 min · format M4A léger.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Accès au micro refusé")
                .font(.headline)
                .foregroundColor(.white)
            Text("Active le micro pour cette app dans Réglages iOS puis reviens ici.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Ouvrir Réglages", systemImage: "gear")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.teal.gradient)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
        }
    }

    private func recordingContent(elapsed: TimeInterval) -> some View {
        HStack(spacing: 16) {
            // Pulse rouge compact (à gauche)
            ZStack {
                Circle()
                    .fill(Color.red.opacity(pulse ? 0.18 : 0.38))
                    .frame(width: pulse ? 78 : 68, height: pulse ? 78 : 68)
                Circle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 52, height: 52)
                Image(systemName: "waveform")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .onDisappear { pulse = false }

            // Compteur + sablier (à droite)
            VStack(alignment: .leading, spacing: 6) {
                Text(formatTime(elapsed))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                ProgressView(value: elapsed, total: QuranRecorder.maxRecordingDuration)
                    .tint(.red)
                Text("Enregistrement en cours…")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 4)
    }

    private func recordedContent(duration: TimeInterval) -> some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green.opacity(0.4), .teal.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 4) {
                Text("Enregistrement terminé")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Text("Durée : \(formatTime(duration))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func playingBackContent(progress: Double, duration: TimeInterval) -> some View {
        HStack(spacing: 16) {
            // Cercle progress compact à gauche.
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.teal)
            }
            .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 6) {
                Text(formatTime(progress * duration))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("sur \(formatTime(duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                Text("Lecture en cours…")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 4)
    }

    private func errorContent(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Une erreur est survenue")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    // MARK: - Footer (actions)

    @ViewBuilder
    private var footer: some View {
        switch recorder.state {
        case .idle, .requestingPermission, .error:
            Button {
                Task {
                    let granted = await recorder.requestPermission()
                    if granted { recorder.start(suraSlug: suraSlug) }
                }
            } label: {
                Label("Commencer l'enregistrement", systemImage: "record.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
                    .font(.headline)
            }

        case .permissionDenied:
            EmptyView()

        case .recording:
            Button {
                recorder.stop()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Arrêter", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
                    .font(.headline)
            }

        case .recorded(let url, let duration):
            HStack(spacing: 12) {
                Button {
                    recorder.play()
                } label: {
                    Label("Réécouter", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                }

                ShareLink(
                    item: url,
                    subject: Text("Récitation — \(suraDisplayName)"),
                    message: Text("Récitation enregistrée (\(formatTime(duration))). Qu'Allah accepte de nous, آمين.")
                ) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.teal.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                }

                Button(role: .destructive) {
                    recorder.discard()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundColor(.red)
                }
            }

        case .playingBack:
            Button {
                recorder.pausePlayback()
            } label: {
                Label("Pause", systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.teal.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let mm = total / 60
        let ss = total % 60
        return String(format: "%02d:%02d", mm, ss)
    }
}
