//
//  QuranChapterDetailView.swift
//  Muslim Clock — module Quran Library
//
//  Affiche une sourate complète : header (nom AR + transliteration + traduction + type),
//  Bismillah (sauf Fatiha et At-Tawba), puis liste des versets en `LazyVStack`.
//
//  Toggles afficher/masquer translit + FR persistés via @AppStorage. Marker `﴿n﴾`
//  entre les versets pour rendu Mushaf-like.
//

import SwiftUI
import SwiftData

// MARK: - Thème de lecture

/// Fond de lecture du Coran — surfaces unies et statiques, pensées pour la lecture
/// prolongée : contraste élevé mais non maximal (pas de blanc/noir purs, évite la
/// halation), aucune animation sous le texte pour garder les diacritiques nets.
enum QuranReadingTheme: String, CaseIterable, Identifiable {
    /// Papier crème, texte brun foncé — confort de jour, évoque le mushaf imprimé.
    case sepia
    /// Gris très sombre, texte blanc cassé — confort du soir. Défaut (comportement historique).
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sepia: String(localized: "Sépia")
        case .dark: String(localized: "Sombre")
        }
    }

    var icon: String {
        switch self {
        case .sepia: "sun.max"
        case .dark: "moon"
        }
    }

    /// Schéma imposé à la vue pour que barre de navigation, menus et matériaux suivent le fond.
    var colorScheme: ColorScheme {
        switch self {
        case .sepia: .light
        case .dark: .dark
        }
    }

    var background: Color {
        switch self {
        case .sepia: Color(red: 0.98, green: 0.95, blue: 0.89)
        case .dark: Color(red: 0.09, green: 0.10, blue: 0.11)
        }
    }

    var cardBackground: Color {
        switch self {
        case .sepia: Color(red: 1.0, green: 0.99, blue: 0.96)
        case .dark: Color.white.opacity(0.06)
        }
    }

    var cardStroke: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.14)
        case .dark: Color.white.opacity(0.06)
        }
    }

    /// Texte principal (arabe, titres).
    var textPrimary: Color {
        switch self {
        case .sepia: sepiaInk
        case .dark: Color.white.opacity(0.87)
        }
    }

    /// Texte secondaire (traduction, translittération).
    var textSecondary: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.65)
        case .dark: Color.white.opacity(0.6)
        }
    }

    /// Métadonnées discrètes (compteurs, fins de section, séparateurs de titre).
    var textTertiary: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.45)
        case .dark: Color.white.opacity(0.4)
        }
    }

    /// Filets et pistes de progression.
    var divider: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.12)
        case .dark: Color.white.opacity(0.08)
        }
    }

    /// Encre brun foncé du thème sépia (#3E2F1C).
    private var sepiaInk: Color { Color(red: 0.24, green: 0.18, blue: 0.11) }
}

struct QuranChapterDetailView: View {
    let chapterIndex: QuranChapterIndex
    /// Numéro d'ayah ciblé (auto-scroll au mount). `nil` = pas de scroll auto.
    var scrollToAyah: Int? = nil

    @StateObject private var loader = QuranLibraryLoader.shared
    @State private var chapter: QuranChapter?
    @State private var loadError: String?
    @State private var highlightedAyah: Int?
    /// Présentation de la sheet d'enregistrement de récitation.
    @State private var showRecorder: Bool = false
    /// Recorder partagé chapter ↔ sheet pour permettre la synchro karaoké
    /// (highlight + scroll du verset courant sous la sheet).
    @State private var recorder = QuranRecorder()
    /// Mode karaoké activé (toggle persistant dans la sheet).
    @AppStorage("quranKaraokeEnabled") private var karaokeEnabled: Bool = false
    /// Index du verset courant en karaoké (1-indexé). Incrémenté par le bouton "Verset suivant".
    @State private var karaokeIndex: Int = 1

    @AppStorage("quranShowTransliteration") private var showTransliteration: Bool = false
    @AppStorage("quranShowTranslation") private var showTranslation: Bool = true
    /// Fond de lecture (sépia / sombre) — persistant, propre au lecteur.
    @AppStorage("quranReadingTheme") private var readingTheme: QuranReadingTheme = .dark

    /// Marque-page libre — sourate et ayah sauvegardées au tap "Marquer ici" sur une carte.
    /// 0 = aucun marque-page.
    @AppStorage("quranBookmarkSura") private var bookmarkSura: Int = 0
    @AppStorage("quranBookmarkAyah") private var bookmarkAyah: Int = 0

    // MARK: - Pages Madinah
    /// Débuts de page dans cette sourate (`ayah → page`), calculé au chargement.
    /// Vide si le mapping est indisponible ou si aucune page ne commence dans la sourate.
    @State private var pageBreaks: [Int: Int] = [:]
    /// Page Madinah du verset visible le plus haut — alimente l'indicateur "Page N / 604".
    @State private var currentPage: Int?
    /// Versets actuellement montés par la LazyVStack. Type référence volontaire :
    /// muter ce Set à chaque onAppear/onDisappear ne doit PAS invalider la vue —
    /// seul `currentPage` (qui ne change qu'aux frontières de page) déclenche un rendu.
    @State private var visibleAyahs = VisibleAyahTracker()

    private final class VisibleAyahTracker {
        var ids = Set<Int>()
    }

    // MARK: - Crédit automatique des pages lues
    @Environment(\.modelContext) private var modelContext
    /// VM local pour le crédit automatique (le plan est rechargé depuis UserDefaults à
    /// l'init). Le tracker a sa propre instance — la synchro passe par SwiftData.
    @State private var planVM = QuranPlanViewModel()
    /// Instant d'arrivée sur la page courante — filtre les défilements de navigation.
    @State private var pageEnteredAt: Date = .now
    /// Page tout juste créditée au journal (feedback "✓ +1" transitoire dans la capsule).
    @State private var justCreditedPage: Int?

    /// Temps minimal passé sur une page pour qu'elle compte comme lue en la quittant.
    /// Une vraie lecture prend plusieurs minutes ; 20 s écarte les scrolls de repérage
    /// tout en créditant l'auto-scroll au rythme par défaut (~50 s/page).
    private static let minimumPageDwell: TimeInterval = 20

    // MARK: - Auto-scroll
    /// Lecture automatique active : un timer avance vers le verset suivant à intervalle régulier.
    @State private var isAutoScrolling: Bool = false
    /// Intervalle entre 2 versets, en secondes. 0.5 = très rapide (révision), 15 = lecture méditée.
    @AppStorage("quranAutoScrollSeconds") private var autoScrollSeconds: Double = 3.5
    @State private var autoScrollIndex: Int = 0
    @State private var autoScrollTask: Task<Void, Never>?
    /// Progression visuelle (0 → 1) du sablier du verset courant, animée sur `autoScrollSeconds`.
    @State private var ayahProgress: Double = 0

    var body: some View {
        ZStack {
            // Fond uni statique — pas de CosmicBackground ici : un fond animé sous le
            // texte dégrade la netteté des diacritiques et fatigue sur lecture longue.
            readingTheme.background
                .ignoresSafeArea()

            if let chapter {
                content(chapter: chapter)
            } else if let loadError {
                errorState(loadError)
            } else {
                loadingState
            }
        }
        .navigationTitle(chapterIndex.transliteration)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Translittération", isOn: $showTransliteration)
                    Toggle("Traduction française", isOn: $showTranslation)
                    Picker("Fond de lecture", selection: $readingTheme) {
                        ForEach(QuranReadingTheme.allCases) { theme in
                            Label(theme.label, systemImage: theme.icon).tag(theme)
                        }
                    }
                } label: {
                    Image(systemName: "textformat")
                        .foregroundStyle(.teal)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showRecorder = true
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .foregroundStyle(.teal)
                }
                .accessibilityLabel(Text("Enregistrer ma récitation"))
            }
        }
        .sheet(isPresented: $showRecorder) {
            let displayName = chapter?.transliteration ?? chapterIndex.transliteration
            QuranRecorderView(
                recorder: recorder,
                suraDisplayName: displayName,
                suraSlug: QuranRecorder.suraSlug(from: displayName),
                karaokeEnabled: $karaokeEnabled,
                onStartRecording: { startKaraokeIfNeeded() },
                onMarkNextVerse: { markNextVerse() }
            )
        }
        .preferredColorScheme(readingTheme.colorScheme)
        .task { await load() }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.teal)
                .scaleEffect(1.3)
            Text("Chargement de \(chapterIndex.transliteration)…")
                .font(.caption)
                .foregroundStyle(readingTheme.textSecondary)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange.opacity(0.8))
            Text("Impossible de charger cette sourate")
                .font(.subheadline)
                .foregroundStyle(readingTheme.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundStyle(readingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await load(force: true) }
            } label: {
                Label("Réessayer", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.teal.gradient)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
        }
        .padding(30)
    }

    // MARK: - Content

    private func content(chapter: QuranChapter) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        header(chapter: chapter)

                        if chapter.shouldDisplayBismillah {
                            bismillahCard
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(chapter.verses) { ayah in
                                if let page = pageBreaks[ayah.id] {
                                    pageSeparator(page: page)
                                }
                                ayahCard(ayah: ayah, chapter: chapter)
                                    .id(ayah.id)
                            }
                        }
                        .padding(.horizontal, 12)

                        Text("— Fin de la sourate \(chapter.transliteration) —")
                            .font(.caption2)
                            .foregroundStyle(readingTheme.textTertiary)
                            .padding(.top, 12)
                            .padding(.bottom, 80) // espace pour le HUD auto-scroll en bas
                    }
                    .padding(.top, 12)
                }
                .simultaneousGesture(
                    // Si l'utilisateur scroll manuellement → pause l'auto-scroll
                    DragGesture().onChanged { _ in
                        if isAutoScrolling { stopAutoScroll() }
                    }
                )

                // HUD auto-scroll en bas
                autoScrollHUD(chapter: chapter, proxy: proxy)
            }
            .overlay(alignment: .top) {
                pageIndicator
            }
            .task(id: scrollToAyah) {
                // Auto-scroll vers le verset cible si fourni (ex: reprise Khatma / bookmark).
                // `.task` auto-cancel à la sortie de la View — pas de fuite.
                guard let target = scrollToAyah else { return }
                try? await Task.sleep(nanoseconds: 200_000_000)
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(target, anchor: .top)
                    highlightedAyah = target
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 0.8)) {
                    highlightedAyah = nil
                }
            }
            // Karaoké : pendant l'enregistrement, suit le dernier verset marqué.
            .onChange(of: recorder.versePassages.last?.ayahId) { _, newAyah in
                guard karaokeEnabled, let newAyah else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newAyah, anchor: .center)
                    highlightedAyah = newAyah
                }
            }
            // Karaoké : pendant la lecture, suit l'ayah courant calculé par le recorder.
            .onChange(of: recorder.playbackAyahId) { _, newAyah in
                guard karaokeEnabled, let newAyah else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newAyah, anchor: .center)
                    highlightedAyah = newAyah
                }
            }
            .onDisappear { stopAutoScroll() }
        }
    }

    // MARK: - Auto-scroll HUD

    private func autoScrollHUD(chapter: QuranChapter, proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 14) {
            Button {
                if isAutoScrolling {
                    stopAutoScroll()
                } else {
                    startAutoScroll(chapter: chapter, proxy: proxy)
                }
            } label: {
                Image(systemName: isAutoScrolling ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.teal)
            }

            VStack(spacing: 2) {
                HStack {
                    Image(systemName: "hare.fill")
                        .font(.caption2)
                        .foregroundStyle(readingTheme.textSecondary)
                    Slider(value: $autoScrollSeconds, in: 0.5...15.0, step: 0.5)
                        .tint(.teal)
                    Image(systemName: "tortoise.fill")
                        .font(.caption2)
                        .foregroundStyle(readingTheme.textSecondary)
                }
                Text("\(String(format: "%.1f", autoScrollSeconds)) s / verset")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(readingTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.teal.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 30)
        .padding(.bottom, 16)
    }

    private func startAutoScroll(chapter: QuranChapter, proxy: ScrollViewProxy) {
        guard !chapter.verses.isEmpty else { return }
        // Priorité de reprise :
        // 1. Verset highlighted (l'utilisateur a déjà avancé pendant cette session) ;
        // 2. Marque-page (`quranBookmarkAyah`) s'il pointe sur la sourate courante ;
        // 3. Début de la sourate (verset 1).
        let startAyah: Int
        if let highlighted = highlightedAyah {
            startAyah = highlighted
        } else if bookmarkSura == chapter.id && bookmarkAyah > 0 {
            startAyah = bookmarkAyah
        } else {
            startAyah = 1
        }
        autoScrollIndex = max(0, min(startAyah - 1, chapter.verses.count - 1))
        isAutoScrolling = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        autoScrollTask?.cancel()
        autoScrollTask = Task { @MainActor in
            while isAutoScrolling && autoScrollIndex < chapter.verses.count {
                // Capture la durée en début d'itération : si l'utilisateur déplace le slider
                // pendant la lecture, l'animation du sablier ET le sleep utilisent la même valeur
                // (sinon : désync visuelle entre la progression de la capsule et le passage au
                // verset suivant).
                let iterationDuration = autoScrollSeconds
                let ayah = chapter.verses[autoScrollIndex]
                // Reset instantané du sablier puis animation linéaire 0→1 sur la durée.
                var resetTransaction = Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) { ayahProgress = 0 }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(ayah.id, anchor: .center)
                    highlightedAyah = ayah.id
                }
                withAnimation(.linear(duration: iterationDuration)) {
                    ayahProgress = 1.0
                }
                try? await Task.sleep(nanoseconds: UInt64(iterationDuration * 1_000_000_000))
                if Task.isCancelled { break }
                autoScrollIndex += 1
            }
            // Fin atteinte → arrêt propre
            if autoScrollIndex >= chapter.verses.count {
                isAutoScrolling = false
            }
            ayahProgress = 0
        }
    }

    private func stopAutoScroll() {
        autoScrollTask?.cancel()
        autoScrollTask = nil
        isAutoScrolling = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { ayahProgress = 0 }
    }

    // MARK: - Karaoké

    /// Au start d'un enregistrement karaoké : reset l'index au verset de départ
    /// (bookmark de la sourate courante > verset highlighted > verset 1), et marque
    /// le premier passage.
    private func startKaraokeIfNeeded() {
        guard karaokeEnabled else { return }
        // L'auto-scroll standard et le karaoké sont mutuellement exclusifs.
        if isAutoScrolling { stopAutoScroll() }

        let startAyah: Int
        if let highlighted = highlightedAyah {
            startAyah = highlighted
        } else if bookmarkSura == chapterIndex.id && bookmarkAyah > 0 {
            startAyah = bookmarkAyah
        } else {
            startAyah = 1
        }
        karaokeIndex = startAyah
        recorder.markVerse(ayahId: startAyah)
        highlightedAyah = startAyah
    }

    /// Tap "Verset suivant" en mode karaoké : incrémente l'index, marque le passage,
    /// et highlight + scroll vers le nouveau verset.
    private func markNextVerse() {
        guard let total = chapter?.verses.count, karaokeIndex < total else { return }
        karaokeIndex += 1
        recorder.markVerse(ayahId: karaokeIndex)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Pages Madinah

    /// Séparateur inséré avant le 1er verset de chaque page du mushaf.
    private func pageSeparator(page: Int) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(readingTheme.divider)
                .frame(height: 1)
            Text("Page \(page)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(readingTheme.textTertiary)
                .fixedSize()
            Rectangle()
                .fill(readingTheme.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Début de la page \(page) du mushaf"))
    }

    /// Capsule "Page N / 604" flottante en haut — suit le verset visible le plus haut.
    /// Affiche brièvement "✓ +1" quand une page vient d'être créditée au journal.
    @ViewBuilder
    private var pageIndicator: some View {
        if let currentPage {
            HStack(spacing: 6) {
                Text("Page \(currentPage) / \(QuranConstants.totalMadinahPages)")
                    .foregroundStyle(readingTheme.textSecondary)
                if justCreditedPage != nil {
                    Text("✓ +1")
                        .foregroundStyle(.teal)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
            .font(.caption2.weight(.semibold).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(readingTheme.background.opacity(0.92))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(readingTheme.cardStroke, lineWidth: 1))
            .padding(.top, 6)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: currentPage)
            .animation(.spring(duration: 0.35), value: justCreditedPage)
        }
    }

    /// Recalcule la page courante à partir du verset monté le plus haut.
    /// Ne touche l'état (donc le rendu) que si la page a réellement changé.
    private func refreshCurrentPage(chapter: QuranChapter) {
        guard let topAyah = visibleAyahs.ids.min() else { return }
        guard let page = QuranPageMapper.shared.page(for: chapter.id, ayah: topAyah),
              page != currentPage else { return }

        // Franchissement vers l'avant : la page qu'on quitte est terminée si on y a
        // passé un temps de lecture plausible. Le crédit ne s'applique que si c'est la
        // page attendue par la Khatma (règle séquentielle dans `autoLogPage`).
        if let previous = currentPage,
           page == previous + 1,
           Date.now.timeIntervalSince(pageEnteredAt) >= Self.minimumPageDwell,
           planVM.autoLogPage(previous, context: modelContext) {
            justCreditedPage = previous
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if justCreditedPage == previous { justCreditedPage = nil }
            }
        }
        pageEnteredAt = .now
        currentPage = page
    }

    // MARK: - Sub-views

    private func header(chapter: QuranChapter) -> some View {
        VStack(spacing: 4) {
            Text(chapter.name)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(readingTheme.textPrimary)
                .environment(\.layoutDirection, .rightToLeft)
            HStack(spacing: 6) {
                Text(chapter.transliteration)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.teal)
                if let translation = chapter.translation {
                    Text("•")
                        .foregroundStyle(readingTheme.textTertiary)
                    Text(translation)
                        .font(.system(size: 14))
                        .foregroundStyle(readingTheme.textSecondary)
                }
            }
            Text("\(chapter.totalVerses) versets · \(chapter.isMeccan ? "Révélée à La Mecque" : "Révélée à Médine")")
                .font(.caption2)
                .foregroundStyle(readingTheme.textTertiary)
        }
        .padding(.bottom, 4)
    }

    private var bismillahCard: some View {
        VStack(spacing: 6) {
            Text(QuranConstants.bismillah)
                .font(.custom("AmiriQuran-Regular", size: 26))
                .foregroundColor(readingTheme.textPrimary)
                .environment(\.layoutDirection, .rightToLeft)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if showTransliteration {
                Text(QuranConstants.bismillahTransliteration)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(readingTheme.textSecondary)
            }
            if showTranslation {
                Text(QuranConstants.bismillahFrench)
                    .font(.caption)
                    .foregroundStyle(readingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(readingTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    private func ayahCard(ayah: QuranAyah, chapter: QuranChapter) -> some View {
        VStack(alignment: .center, spacing: 8) {
            // Bloc arabe + marker ayah
            Text(arabicTextWithMarker(ayah: ayah))
                .font(.custom("AmiriQuran-Regular", size: 24))
                .multilineTextAlignment(.center)
                .lineSpacing(12)
                .environment(\.layoutDirection, .rightToLeft)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            if showTransliteration {
                Text(ayah.transliteration)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(readingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showTranslation, let translation = ayah.translation {
                Divider()
                    .background(readingTheme.divider)
                Text(translation)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(readingTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            highlightedAyah == ayah.id
                ? AnyShapeStyle(Color.teal.opacity(0.18))
                : AnyShapeStyle(readingTheme.cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    highlightedAyah == ayah.id ? Color.teal.opacity(0.6) : readingTheme.cardStroke,
                    lineWidth: highlightedAyah == ayah.id ? 1.5 : 1
                )
        )
        .overlay(alignment: .bottom) {
            // Sablier linéaire en bas de la card — visible uniquement sur le verset courant en auto-scroll.
            if isAutoScrolling && highlightedAyah == ayah.id {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(readingTheme.divider)
                            .frame(height: 3)
                        Capsule()
                            .fill(Color.teal)
                            .frame(width: geo.size.width * CGFloat(ayahProgress), height: 3)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 3)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
        .onAppear {
            visibleAyahs.ids.insert(ayah.id)
            refreshCurrentPage(chapter: chapter)
        }
        .onDisappear {
            visibleAyahs.ids.remove(ayah.id)
            refreshCurrentPage(chapter: chapter)
        }
        .contextMenu {
            // Marquer ici
            Button {
                bookmarkSura = chapter.id
                bookmarkAyah = ayah.id
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label(
                    isBookmarked(chapter: chapter, ayah: ayah) ? "Marque-page actuel" : "Marquer ici",
                    systemImage: isBookmarked(chapter: chapter, ayah: ayah) ? "bookmark.fill" : "bookmark"
                )
            }

            // Partager
            ShareLink(
                item: shareText(ayah: ayah, chapter: chapter),
                subject: Text("\(chapter.transliteration) (\(chapter.id)), verset \(ayah.id)"),
                message: Text("Verset du Coran")
            ) {
                Label("Partager", systemImage: "square.and.arrow.up")
            }

            // Copier
            Button {
                UIPasteboard.general.string = shareText(ayah: ayah, chapter: chapter)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("Copier", systemImage: "doc.on.doc")
            }
        }
    }

    /// Indique si ce verset est le marque-page actuel.
    private func isBookmarked(chapter: QuranChapter, ayah: QuranAyah) -> Bool {
        bookmarkSura == chapter.id && bookmarkAyah == ayah.id
    }

    /// Texte partagé : arabe + (translit si activée) + traduction FR + référence + attribution.
    private func shareText(ayah: QuranAyah, chapter: QuranChapter) -> String {
        var parts: [String] = [ayah.text]
        if showTransliteration {
            parts.append(ayah.transliteration)
        }
        if let translation = ayah.translation {
            parts.append("« \(translation) »")
        }
        parts.append("— Sourate \(chapter.transliteration) (\(chapter.id)), verset \(ayah.id)")
        parts.append("Traduction : Muhammad Hamidullah")
        return parts.joined(separator: "\n\n")
    }

    /// Construit le texte arabe avec le marker ﴿n﴾ teal en fin.
    private func arabicTextWithMarker(ayah: QuranAyah) -> AttributedString {
        var text = AttributedString(ayah.text)
        text.foregroundColor = readingTheme.textPrimary

        var marker = AttributedString(" ﴿\(ayah.id)﴾")
        marker.foregroundColor = .teal.opacity(0.85)
        marker.font = .system(size: 16, weight: .bold)

        return text + marker
    }

    // MARK: - Loading

    private func load(force: Bool = false) async {
        if chapter != nil && !force { return }
        chapter = nil
        loadError = nil
        if let result = await loader.loadChapter(chapterIndex.id) {
            chapter = result
            let mapper = QuranPageMapper.shared
            pageBreaks = mapper.pageBreaks(for: result.id)
            // Page initiale : celle du verset ciblé (reprise Khatma/bookmark), sinon celle
            // du 1er verset — couvre aussi les sourates qui commencent en milieu de page.
            currentPage = mapper.page(for: result.id, ayah: scrollToAyah ?? 1)
        } else {
            loadError = "Vérifie ta connexion réseau, puis réessaie."
        }
    }
}
