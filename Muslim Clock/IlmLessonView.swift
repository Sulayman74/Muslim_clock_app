//
//  IlmLessonView.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Détail d'une leçon : arabe en grand (support de mémorisation) + traduction FR.
//  Mode « Mémoriser » : texte arabe voilé, révélation au toucher (auto-évaluation).
//

import SwiftUI

struct IlmLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: IlmViewModel
    let track: IlmTrack
    @State var index: Int

    /// Mode d'étude : lecture (AR + FR) ou mémorisation (AR voilé, FR masquée).
    @State private var isMemorizing = false
    /// En mode mémorisation : le texte arabe est-il révélé ?
    @State private var isRevealed = false
    /// Overlay bref après validation d'une leçon.
    @State private var showCelebration = false
    /// Enregistreur de récitation — service partagé avec la bibliothèque Coran,
    /// réutilisé tel quel (auto-correction : réciter, se réécouter en lisant le matn).
    @State private var recorder = QuranRecorder()

    private var lesson: IlmLesson { track.lessons[index] }
    private var isCompleted: Bool { vm.isCompleted(lesson.id) }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        modePicker
                        arabicCard
                        if isMemorizing {
                            recorderBar
                        } else {
                            translationCard
                        }
                        if let note = lesson.note, !note.isEmpty {
                            noteCard(note)
                        }
                        completeButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { goTo(index - 1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(index == 0)
                    Button { goTo(index + 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(index == track.lessons.count - 1)
                }
            }
            .overlay {
                if showCelebration {
                    celebrationOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: showCelebration)
        // Libère micro/session audio si on quitte la leçon en cours d'enregistrement.
        .onDisappear { recorder.discard() }
    }

    private func goTo(_ newIndex: Int) {
        guard track.lessons.indices.contains(newIndex) else { return }
        recorder.discard()
        withAnimation(.smooth(duration: 0.25)) {
            index = newIndex
            isRevealed = false
        }
    }

    // MARK: - Mode d'étude

    private var modePicker: some View {
        Picker("Mode", selection: $isMemorizing.animation(.smooth(duration: 0.3))) {
            Text("Lire").tag(false)
            Text("Mémoriser").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
        .onChange(of: isMemorizing) { _, _ in isRevealed = false }
    }

    // MARK: - Texte arabe

    private var arabicCard: some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Aligné à droite (norme typographique arabe). Pas d'override layoutDirection :
            // la direction RTL vient du contenu lui-même, et `.trailing` dans un contexte
            // RTL inverserait visuellement l'alignement.
            Text(verbatim: lesson.arabic)
                .font(.system(size: 24, weight: .medium))
                .lineSpacing(12)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .blur(radius: isMemorizing && !isRevealed ? 7 : 0)

            if let source = lesson.source, !source.isEmpty {
                Text(verbatim: "— \(source)")
                    .font(.caption)
                    .foregroundColor(.purple.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
        .overlay {
            if isMemorizing && !isRevealed {
                VStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill")
                        .font(.title3)
                    Text("Récite de mémoire, puis touche pour vérifier")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.75))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isMemorizing else { return }
            withAnimation(.smooth(duration: 0.3)) { isRevealed.toggle() }
        }
    }

    // MARK: - Enregistrement de récitation

    /// Boucle d'auto-correction : réciter de mémoire → s'enregistrer → se réécouter
    /// en lisant le matn. Le partage permet l'ʿarḍ (envoyer sa récitation à quelqu'un
    /// qui corrige).
    private var recorderBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill").foregroundStyle(.purple)
                Text("Réciter et s'écouter")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                Spacer()
            }

            switch recorder.state {
            case .idle, .requestingPermission:
                Button {
                    Task {
                        if await recorder.requestPermission() {
                            recorder.start(suraSlug: "Ilm-\(lesson.id)")
                        }
                    }
                } label: {
                    Label("S'enregistrer", systemImage: "record.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.25))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
                }

            case .permissionDenied:
                Text("Micro refusé — autorise-le dans Réglages pour t'enregistrer.")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .recording(let elapsed):
                HStack(spacing: 12) {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .opacity(Int(elapsed * 2) % 2 == 0 ? 1 : 0.35)
                    Text(Self.timeLabel(elapsed))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                    Spacer()
                    Button { recorder.stop() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.red)
                    }
                }

            case .recorded(let url, let duration):
                HStack(spacing: 14) {
                    Button { recorder.play() } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.purple)
                    }
                    Text(Self.timeLabel(duration))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Button { recorder.discard() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

            case .playingBack(let progress, let duration):
                HStack(spacing: 12) {
                    Button { recorder.stopPlayback() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.purple)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(Color.purple)
                                .frame(width: geo.size.width * CGFloat(progress))
                        }
                    }
                    .frame(height: 5)
                    Text(Self.timeLabel(duration))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.6))
                }

            case .error(let message):
                HStack(spacing: 8) {
                    Text(verbatim: message)
                        .font(.caption)
                        .foregroundColor(.orange.opacity(0.9))
                    Spacer()
                    Button("Réessayer") { recorder.discard() }
                        .font(.caption.bold())
                        .foregroundColor(.purple)
                }
            }

            Text("Récite de mémoire, puis réécoute-toi en lisant le texte pour te corriger.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .animation(.smooth(duration: 0.25), value: recorder.state)
    }

    /// "m:ss" — durée compacte pour la barre d'enregistrement.
    private static func timeLabel(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Traduction

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.book.closed.fill").foregroundStyle(.purple)
                Text("Traduction")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
            }
            Text(verbatim: lesson.text)
                .font(.system(size: 15))
                .lineSpacing(5)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
    }

    private func noteCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange.opacity(0.85))
                .font(.footnote)
            Text(verbatim: note)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
    }

    // MARK: - Validation

    private var completeButton: some View {
        Button {
            if isCompleted {
                vm.uncompleteLesson(lesson.id)
            } else {
                vm.completeLesson(lesson.id)
                celebrateThenAdvance()
            }
        } label: {
            HStack {
                Image(systemName: isCompleted ? "checkmark.seal.fill" : "checkmark.circle")
                Text(isCompleted ? "Leçon acquise" : "Je connais cette leçon")
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isCompleted ? AnyShapeStyle(.green.opacity(0.55)) : AnyShapeStyle(.purple.gradient))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 4)
    }

    /// Célébration brève, puis passage auto à la leçon suivante s'il en reste une.
    private func celebrateThenAdvance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            showCelebration = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.smooth(duration: 0.3)) { showCelebration = false }
            if index < track.lessons.count - 1 {
                goTo(index + 1)
            }
        }
    }

    private var celebrationOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.purple)
                .symbolEffect(.bounce, value: showCelebration)
            Text(verbatim: "ما شاء الله")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            Text("Leçon acquise")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.modal, style: .continuous))
        .shadow(color: .purple.opacity(0.3), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
