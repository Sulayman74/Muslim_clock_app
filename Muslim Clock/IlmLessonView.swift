//
//  IlmLessonView.swift
//  Muslim Clock — module Programme ʿIlm
//
//  « Page de matn imprimé » (concours de design, spec A gagnante) : la leçon
//  comme une page de livre — masthead typographique (kicker, titre serif,
//  folio, ornement), corps en AmiriQuran pleine page SANS cartes, note de bas
//  de page, barre de pied (mode + chevrons) façon Apple Books.
//
//  La toolbar est MUETTE (titre vide) : un titre de leçon fait jusqu'à 63
//  caractères, aucune barre inline ne peut le porter entre les boutons — il
//  vit dans la page et tourne avec elle, comme dans un livre.
//
//  Mode « Mémoriser » : arabe ET traduction voilés (blur — hauteur constante,
//  anti-wiggle par construction), révélation au toucher.
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

    /// Hauteur de la barre de pied (mode + chevrons) — fixe, anti-wiggle.
    private static let bottomBarHeight: CGFloat = 52

    private var lesson: IlmLesson { track.lessons[index] }
    private var theme: ReadingTheme { readingTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                // Fond statique du thème (lecture prolongée = diacritiques nets).
                theme.background
                    .ignoresSafeArea()

                // Pagination : une leçon = une page = une unité de rappel.
                TabView(selection: $index) {
                    ForEach(track.lessons.indices, id: \.self) { i in
                        lessonPage(track.lessons[i], position: i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            // Barre muette : le titre vit dans la page (masthead) — plus jamais
            // de troncature entre les boutons.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                // Réglages de lecture. Les chevrons ont déménagé dans la barre
                // de pied (cibles 44 pt, toujours visibles — accessibilité).
                ToolbarItem(placement: .primaryAction) {
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
            // Barre de pied : UNE instance, hors TabView (elle ne swipe pas —
            // c'est du chrome). safeAreaInset → les scrolls des pages s'insettent
            // automatiquement.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            // Capsule d'enregistrement (mode Mémoriser), au-dessus de la barre.
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
        // Pagination accessible EN COMPLÉMENT des chevrons (cherry-pick spec B).
        .accessibilityAction(named: Text("Leçon suivante")) { goTo(index + 1) }
        .accessibilityAction(named: Text("Leçon précédente")) { goTo(index - 1) }
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
            VStack(spacing: 0) {
                masthead(lesson, position: position)
                studyBlock(lesson)
                if let note = lesson.note, !note.isEmpty {
                    footnote(note)
                }
                completeButton(lesson)
                    .padding(.top, 32)
            }
            // Marges de page « livre » (24) — la réserve basse ne couvre que la
            // capsule HUD (états playback/erreur inclus) : la barre de pied est
            // absorbée nativement par le safeAreaInset.
            .padding(.horizontal, 24)
            .padding(.bottom, 150)
        }
    }

    // MARK: - Masthead (kicker · titre · folio · ornement)

    private func masthead(_ lesson: IlmLesson, position: Int) -> some View {
        VStack(spacing: 10) {
            // Kicker : parcours en arabe + français, discret.
            HStack(spacing: 6) {
                Text(verbatim: track.titleArabic)
                    .font(.system(size: 12, weight: .medium))
                Text(verbatim: "·")
                Text(verbatim: track.title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.5)
            }
            .foregroundColor(theme.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // Titre complet — serif, multi-lignes, jamais tronqué. Point
            // d'ancrage VoiceOver de la page (la barre étant muette).
            Text(verbatim: lesson.title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            // Folio : position + durée estimée (cherry-pick spec B).
            Text(verbatim: "Leçon \(position + 1) sur \(track.lessons.count) · ~\(IlmMath.estimatedMinutes(arabicText: lesson.arabic)) min")
                .font(.system(size: 12, weight: .medium, design: .serif))
                .italic()
                .monospacedDigit()
                .foregroundColor(theme.textTertiary)

            ornament
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    /// Filet ─── ◆ ─── , signature « page de livre ».
    private var ornament: some View {
        HStack(spacing: 10) {
            Rectangle().fill(theme.divider).frame(width: 48, height: 1)
            Image(systemName: "diamond.fill")
                .font(.system(size: 6))
                .foregroundStyle(.purple.opacity(0.4))
            Rectangle().fill(theme.divider).frame(width: 48, height: 1)
        }
    }

    /// Variante courte pour la transition arabe → traduction.
    private var shortOrnament: some View {
        HStack(spacing: 8) {
            Rectangle().fill(theme.divider).frame(width: 32, height: 1)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(.purple.opacity(0.35))
            Rectangle().fill(theme.divider).frame(width: 32, height: 1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Corps de page (arabe · source · traduction) — sans cartes

    private func studyBlock(_ lesson: IlmLesson) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Matn — même police que le mushaf du lecteur Coran (parité).
            // Aligné à droite ; pas d'override layoutDirection : la direction
            // RTL vient du contenu, `.trailing` dans un contexte RTL inverserait.
            Text(verbatim: lesson.arabic)
                .font(.custom("AmiriQuran-Regular", size: 25))
                .lineSpacing(14)
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .blur(radius: isMemorizing && !isRevealed ? 7 : 0)
                .padding(.top, 4)

            if let source = lesson.source, !source.isEmpty {
                Text(verbatim: "— \(source)")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(.purple.opacity(0.85))
                    .padding(.top, 6)
            }

            // Traduction : en Lire selon le toggle ; en Mémoriser toujours
            // présente mais voilée avec l'arabe (le blur garde la hauteur —
            // anti-wiggle). Le filet appartient au groupe : ils (dis)paraissent
            // ensemble.
            Group {
                if isMemorizing || showTranslation {
                    VStack(alignment: .leading, spacing: 0) {
                        shortOrnament
                            .padding(.vertical, 20)
                        Text(verbatim: lesson.text)
                            .font(.system(size: 16, design: .serif))
                            .lineSpacing(7)
                            .foregroundColor(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .blur(radius: isMemorizing && !isRevealed ? 7 : 0)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.smooth(duration: 0.3), value: showTranslation)
        }
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

    /// Note = note de bas de page (hairline + ※), plus de carte.
    private func footnote(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(theme.divider).frame(height: 1)
            HStack(alignment: .top, spacing: 8) {
                Text(verbatim: "※")
                    .font(.system(size: 12))
                Text(verbatim: note)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(theme.textTertiary)
        }
        .padding(.top, 28)
    }

    // MARK: - Barre de pied (mode + chevrons)

    private var bottomBar: some View {
        HStack {
            Button { goTo(index - 1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(index == 0)
            .accessibilityLabel(Text("Leçon précédente"))

            Spacer()

            Picker("Mode", selection: $isMemorizing.animation(.smooth(duration: 0.3))) {
                Text("Lire").tag(false)
                Text("Mémoriser").tag(true)
            }
            .pickerStyle(.segmented)
            // Largeur bornée : la barre ne reflow jamais (anti-wiggle).
            .frame(maxWidth: 200)
            .onChange(of: isMemorizing) { _, _ in isRevealed = false }

            Spacer()

            Button { goTo(index + 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(index == track.lessons.count - 1)
            .accessibilityLabel(Text("Leçon suivante"))
        }
        .padding(.horizontal, 12)
        .frame(height: Self.bottomBarHeight)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .bottom)
        .overlay(alignment: .top) {
            theme.divider.frame(height: 1)
        }
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
        // Flotte AU-DESSUS de la barre de pied.
        .padding(.bottom, Self.bottomBarHeight + 10)
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
    }

    /// Célébration brève (teaser de la suivante — cherry-pick spec B), puis
    /// passage auto à la leçon suivante s'il en reste une.
    private func celebrateThenAdvance() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            showCelebration = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
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

            if index < track.lessons.count - 1 {
                Text("Suivante : \(track.lessons[index + 1].title)")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text(verbatim: "Parcours terminé — الحمد لله")
                    .font(.caption.bold())
                    .foregroundColor(.green.opacity(0.9))
            }
            // Rend visible le système de révision espacée (Leitner) déjà bâti.
            Text("Cette leçon rejoint tes révisions espacées")
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
        }
        .padding(28)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.modal, style: .continuous))
        .shadow(color: .purple.opacity(0.3), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
