//
//  IlmLessonView.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Détail d'une leçon : arabe en grand (support de mémorisation) + traduction FR.
//  Mode « Mémoriser » : arabe ET traduction voilés (blur), révélation au toucher —
//  la vérification après rappel porte sur les mots et le sens.
//
//  Parité lecteur Coran (PLAN_UX_ILM_LECTEUR.md) : thème sépia/sombre partagé
//  (`ReadingTheme`, fond statique — diacritiques nets), toggle traduction
//  persisté, pagination par leçon (une leçon = une page = une unité de rappel),
//  enregistreur en capsule HUD (lire le matn PENDANT la réécoute).
//

import SwiftUI

struct IlmLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: IlmViewModel
    let track: IlmTrack
    @State var index: Int

    /// Mode d'étude : lecture (AR + FR) ou mémorisation (voilé, révélation au tap).
    @State private var isMemorizing = false
    /// En mode mémorisation : le texte est-il révélé ?
    @State private var isRevealed = false
    /// Overlay bref après validation d'une leçon.
    @State private var showCelebration = false
    /// Enregistreur de récitation — service partagé avec la bibliothèque Coran.
    /// UNE seule instance au niveau parent : AVAudioSession est un singleton et
    /// le TabView pré-monte les pages voisines.
    @State private var recorder = QuranRecorder()

    /// Préférence de lecture PARTAGÉE avec le lecteur Coran (papier global —
    /// l'identité ʿIlm reste portée par l'accent purple).
    @AppStorage("quranReadingTheme") private var readingTheme: ReadingTheme = .dark
    /// Traduction affichée en mode Lire (en Mémoriser, elle suit le voile).
    @AppStorage("ilmShowTranslation") private var showTranslation = true

    private var lesson: IlmLesson { track.lessons[index] }
    private var theme: ReadingTheme { readingTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                // Fond statique du thème (remplace le cosmique animé : lecture
                // prolongée = diacritiques nets, cf. rationale du lecteur Coran).
                theme.background
                    .ignoresSafeArea()

                // Pagination : une leçon = une page = une unité de rappel
                // (ancrage spatial). Chaque page a son propre scroll.
                TabView(selection: $index) {
                    ForEach(track.lessons.indices, id: \.self) { i in
                        lessonPage(track.lessons[i], position: i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    // Chevrons conservés (accessibilité : VoiceOver, grands textes).
                    Button { goTo(index - 1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(index == 0)
                    Button { goTo(index + 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(index == track.lessons.count - 1)

                    // Réglages de lecture (pattern du lecteur Coran).
                    Menu {
                        Toggle(isOn: $showTranslation.animation(.smooth(duration: 0.3))) {
                            Label("Traduction française", systemImage: "text.book.closed")
                        }
                        Picker("Fond", selection: $readingTheme) {
                            ForEach(ReadingTheme.allCases) { t in
                                Label(t.label, systemImage: t.icon).tag(t)
                            }
                        }
                    } label: {
                        Image(systemName: "textformat")
                    }
                }
            }
            // Capsule d'enregistrement HORS FLUX (mode Mémoriser) : reste visible
            // pendant qu'on lit le matn en se réécoutant — une barre dans le
            // scroll partirait hors écran sur un matn long.
            .overlay(alignment: .bottom) {
                Group {
                    if isMemorizing {
                        recorderHUD
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.3), value: isMemorizing)
            }
            .overlay {
                if showCelebration {
                    celebrationOverlay
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .sensoryFeedback(.success, trigger: showCelebration)
        // Libère micro/session audio si on quitte la leçon en cours d'enregistrement.
        .onDisappear { recorder.discard() }
        // Reset au changement de page (swipe OU chevrons) : enregistrement et voile.
        .onChange(of: index) { _, _ in
            recorder.discard()
            isRevealed = false
        }
    }

    private func goTo(_ newIndex: Int) {
        guard track.lessons.indices.contains(newIndex) else { return }
        withAnimation(.smooth(duration: 0.25)) {
            index = newIndex
        }
    }

    // MARK: - Page de leçon

    private func lessonPage(_ lesson: IlmLesson, position: Int) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                modePicker
                positionCapsule(position)
                arabicCard(lesson)
                translationSection(lesson)
                if let note = lesson.note, !note.isEmpty {
                    noteCard(note)
                }
                completeButton(lesson)
            }
            .padding(.horizontal, 16)
            // Constant quel que soit le mode (anti-wiggle) : réserve la place
            // de la capsule HUD.
            .padding(.bottom, 110)
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

    /// « 3 / 12 » — position dans le parcours (ancrage spatial de la mémorisation).
    private func positionCapsule(_ position: Int) -> some View {
        Text(verbatim: "\(position + 1) / \(track.lessons.count)")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(theme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.cardStroke, lineWidth: 1))
    }

    // MARK: - Texte arabe

    private func arabicCard(_ lesson: IlmLesson) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            // Aligné à droite (norme typographique arabe). Pas d'override layoutDirection :
            // la direction RTL vient du contenu lui-même, et `.trailing` dans un contexte
            // RTL inverserait visuellement l'alignement.
            Text(verbatim: lesson.arabic)
                .font(.system(size: 24, weight: .medium))
                .lineSpacing(12)
                .foregroundColor(theme.textPrimary)
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
        .background(theme.cardBackground)
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
                .foregroundColor(theme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isMemorizing else { return }
            withAnimation(.smooth(duration: 0.3)) { isRevealed.toggle() }
        }
    }

    // MARK: - Traduction

    /// Mode Lire : selon le toggle persisté. Mode Mémoriser : toujours présente
    /// mais VOILÉE avec l'arabe (même tap de révélation) — la vérification après
    /// rappel porte sur les mots ET le sens ; le blur garde la hauteur constante
    /// (anti-wiggle par construction).
    @ViewBuilder
    private func translationSection(_ lesson: IlmLesson) -> some View {
        Group {
            if isMemorizing || showTranslation {
                translationCard(lesson)
                    .blur(radius: isMemorizing && !isRevealed ? 7 : 0)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.3), value: showTranslation)
    }

    private func translationCard(_ lesson: IlmLesson) -> some View {
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
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        )
    }

    private func noteCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange.opacity(0.85))
                .font(.footnote)
            Text(verbatim: note)
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
    }

    // MARK: - Enregistrement de récitation (capsule HUD)

    /// Boucle d'auto-correction : réciter de mémoire → s'enregistrer → se réécouter
    /// en lisant le matn. Le partage permet l'ʿarḍ (envoyer sa récitation à
    /// quelqu'un qui corrige).
    private var recorderHUD: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill").foregroundStyle(.purple)
                Text("Réciter puis s'écouter")
                    .font(.caption.bold())
                    .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textPrimary)
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
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    // Parité Coran : sujet + message (destinataire de l'ʿarḍ).
                    ShareLink(
                        item: url,
                        subject: Text("Récitation — \(lesson.title)"),
                        message: Text("Ma récitation (\(Self.timeLabel(duration)))")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Button { recorder.discard() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
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
                            Capsule().fill(theme.divider)
                            Capsule()
                                .fill(Color.purple)
                                .frame(width: geo.size.width * CGFloat(progress))
                        }
                    }
                    .frame(height: 5)
                    Text(Self.timeLabel(duration))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(theme.textTertiary)
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
        }
        .padding(14)
        // minHeight : les états du switch ont des hauteurs différentes —
        // plancher pour que la capsule ne « pompe » pas (anti-wiggle).
        .frame(minHeight: 88)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
        // La capsule respire comme un bloc (verre + enfants synchrones).
        .geometryGroup()
        .animation(.smooth(duration: 0.25), value: recorder.state)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityHint(Text("Récite de mémoire, puis réécoute-toi en lisant le texte pour te corriger."))
    }

    /// "m:ss" — durée compacte pour la capsule d'enregistrement.
    private static func timeLabel(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Validation

    private func completeButton(_ lesson: IlmLesson) -> some View {
        let isCompleted = vm.isCompleted(lesson.id)
        return Button {
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
                .foregroundColor(theme.textPrimary)
            Text("Leçon acquise")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textSecondary)
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.modal, style: .continuous))
        .shadow(color: .purple.opacity(0.3), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
