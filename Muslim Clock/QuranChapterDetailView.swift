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

    @AppStorage("quranShowTransliteration") private var showTransliteration: Bool = false
    @AppStorage("quranShowTranslation") private var showTranslation: Bool = true

    /// Marque-page libre — sourate et ayah sauvegardées au tap "Marquer ici" sur une carte.
    /// 0 = aucun marque-page.
    @AppStorage("quranBookmarkSura") private var bookmarkSura: Int = 0
    @AppStorage("quranBookmarkAyah") private var bookmarkAyah: Int = 0

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
            CosmicBackground(season: IslamicSeasonInfo.current())
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
            QuranRecorderView(
                suraDisplayName: chapter?.transliteration ?? chapterIndex.transliteration,
                suraSlug: (chapter?.transliteration ?? chapterIndex.transliteration)
                    .replacingOccurrences(of: " ", with: "")
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .joined()
            )
        }
        .preferredColorScheme(.dark)
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
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange.opacity(0.8))
            Text("Impossible de charger cette sourate")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
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
                                ayahCard(ayah: ayah, chapter: chapter)
                                    .id(ayah.id)
                            }
                        }
                        .padding(.horizontal, 12)

                        Text("— Fin de la sourate \(chapter.transliteration) —")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
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
            .onAppear {
                // Auto-scroll vers le verset cible si fourni (ex: reprise Khatma / bookmark).
                if let target = scrollToAyah {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(target, anchor: .top)
                            highlightedAyah = target
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeOut(duration: 0.8)) {
                                highlightedAyah = nil
                            }
                        }
                    }
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
                        .foregroundStyle(.white.opacity(0.5))
                    Slider(value: $autoScrollSeconds, in: 0.5...15.0, step: 0.5)
                        .tint(.teal)
                    Image(systemName: "tortoise.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text("\(String(format: "%.1f", autoScrollSeconds)) s / verset")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
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
                let ayah = chapter.verses[autoScrollIndex]
                // Reset instantané du sablier puis animation linéaire 0→1 sur la durée.
                var resetTransaction = Transaction()
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) { ayahProgress = 0 }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(ayah.id, anchor: .center)
                    highlightedAyah = ayah.id
                }
                withAnimation(.linear(duration: autoScrollSeconds)) {
                    ayahProgress = 1.0
                }
                try? await Task.sleep(nanoseconds: UInt64(autoScrollSeconds * 1_000_000_000))
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

    // MARK: - Sub-views

    private func header(chapter: QuranChapter) -> some View {
        VStack(spacing: 4) {
            Text(chapter.name)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .environment(\.layoutDirection, .rightToLeft)
            HStack(spacing: 6) {
                Text(chapter.transliteration)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.teal)
                if let translation = chapter.translation {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))
                    Text(translation)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Text("\(chapter.totalVerses) versets · \(chapter.isMeccan ? "Révélée à La Mecque" : "Révélée à Médine")")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.bottom, 4)
    }

    private var bismillahCard: some View {
        VStack(spacing: 6) {
            Text(QuranConstants.bismillah)
                .font(.custom("AmiriQuran-Regular", size: 26))
                .foregroundColor(.white)
                .environment(\.layoutDirection, .rightToLeft)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if showTransliteration {
                Text(QuranConstants.bismillahTransliteration)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.5))
            }
            if showTranslation {
                Text(QuranConstants.bismillahFrench)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
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
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showTranslation, let translation = ayah.translation {
                Divider()
                    .background(Color.white.opacity(0.08))
                Text(translation)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            highlightedAyah == ayah.id
                ? AnyShapeStyle(Color.teal.opacity(0.18))
                : AnyShapeStyle(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    highlightedAyah == ayah.id ? Color.teal.opacity(0.6) : Color.white.opacity(0.06),
                    lineWidth: highlightedAyah == ayah.id ? 1.5 : 1
                )
        )
        .overlay(alignment: .bottom) {
            // Sablier linéaire en bas de la card — visible uniquement sur le verset courant en auto-scroll.
            if isAutoScrolling && highlightedAyah == ayah.id {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
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
        text.foregroundColor = .white

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
        } else {
            loadError = "Vérifie ta connexion réseau, puis réessaie."
        }
    }
}
