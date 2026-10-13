//
//  RecitationSessionView.swift
//  Muslim Clock — onglet Apprendre, correcteur de récitation
//
//  Séance : texte de référence (voilé en mode mémorisation), micro, indicateur
//  « j'écoute » (jamais le texte brut entendu), puis résultat : texte colorié,
//  score, conseils, écoute du conseil et du récitateur, réessayer.
//

import SwiftUI

struct RecitationSessionView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @State private var vm: RecitationSessionViewModel
    let hideText: Bool

    init(reference: RecitationReference, hideText: Bool) {
        _vm = State(initialValue: RecitationSessionViewModel(reference: reference))
        self.hideText = hideText
    }

    private var languageCode: String { locale.language.languageCode?.identifier ?? "fr" }

    var body: some View {
        ZStack {
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let alignment = vm.alignment {
                        RecitationResultView(vm: vm, alignment: alignment, languageCode: languageCode)
                            .transition(.opacity)
                    } else {
                        referenceText
                            .transition(.opacity)
                    }
                    disclaimer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.smooth(duration: 0.35), value: vm.hasResult)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controlBar
        }
        .navigationTitle(Text(verbatim: vm.reference.riwaya.label))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.transcriber.state) { _, state in
            if state == .finished {
                vm.analyzeIfFinished()
                Task { await vm.rephraseAdvice(languageCode: languageCode) }
            }
        }
        .onDisappear { vm.cancel() }
        .sensoryFeedback(.start, trigger: vm.transcriber.state == .listening)
        .sensoryFeedback(.success, trigger: vm.hasResult)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack {
            Text(verbatim: rangeLabel)
                .font(.caption.bold())
                .foregroundStyle(ModuleAccent.quran)
                .chipStyle(color: ModuleAccent.quran)
            Spacer()
            Text(verbatim: vm.reference.riwaya.labelArabic)
                .font(ScriptureFont.arabic(16))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var rangeLabel: String {
        let r = vm.reference.ayahRange
        return r.count == 1
            ? String(format: String(localized: "Sourate %lld · verset %lld"), vm.reference.surah, r.lowerBound)
            : String(format: String(localized: "Sourate %lld · versets %lld–%lld"), vm.reference.surah, r.lowerBound, r.upperBound)
    }

    // MARK: - Texte de référence

    private var referenceText: some View {
        VStack(alignment: .trailing, spacing: 14) {
            ForEach(vm.reference.ayahRange.map { $0 }, id: \.self) { ayah in
                Text(verbatim: "\(vm.reference.ayahTexts[ayah] ?? "") ﴿\(ayah)﴾")
                    .font(ScriptureFont.arabic())
                    .lineSpacing(ScriptureFont.arabicLineSpacing)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Voile de mémorisation : flou à hauteur constante (aucun saut au dévoilement).
        .blur(radius: hideText && vm.transcriber.state != .finished ? 8 : 0)
        .scriptureCard(accent: ModuleAccent.quran)
        .overlay {
            if hideText {
                Label("Récite de mémoire", systemImage: "eye.slash")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .accessibilityLabel(hideText ? Text("Texte masqué pour la mémorisation") : Text(verbatim: vm.reference.ayahTexts.values.joined(separator: " ")))
    }

    // MARK: - Barre de contrôle

    @ViewBuilder
    private var controlBar: some View {
        VStack(spacing: 10) {
            statusLine
            HStack(spacing: 12) {
                if vm.hasResult {
                    Button {
                        Task { await vm.retry() }
                    } label: {
                        Label("Réessayer", systemImage: "arrow.counterclockwise")
                            .bold()
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(ModuleAccent.quran.opacity(0.18))
                            .foregroundStyle(ModuleAccent.quran)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
                    }
                    if let weakest = vm.weakestAyah, vm.reference.ayahRange.count > 1 {
                        Button {
                            Task { await vm.retry(ayah: weakest) }
                        } label: {
                            Text("Verset \(weakest) seul")
                                .bold()
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(ModuleAccent.quran.gradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
                        }
                    }
                } else {
                    micButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var micButton: some View {
        let listening = vm.transcriber.state == .listening
        return Button {
            Task {
                if listening { await vm.stopListening() } else { await vm.startListening() }
            }
        } label: {
            Label(listening ? "Terminer" : "Réciter", systemImage: listening ? "stop.fill" : "mic.fill")
                .bold()
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(listening ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(ModuleAccent.quran.gradient))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
        }
        .disabled(vm.transcriber.state == .preparing || vm.isLoadingReference)
        .accessibilityIdentifier("recitation.mic")
        .animation(.smooth(duration: 0.2), value: listening)
    }

    /// Ligne d'état à hauteur fixe (anti-wiggle) : écoute, préparation, erreurs.
    @ViewBuilder
    private var statusLine: some View {
        Group {
            switch vm.transcriber.state {
            case .listening:
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .symbolEffect(.pulse)
                    Text("J'écoute… \(vm.transcriber.heardWordCount) mots")
                        .monospacedDigit()
                    Spacer()
                    Text(verbatim: Self.clock(vm.transcriber.elapsed))
                        .monospacedDigit()
                }
            case .preparing:
                Label("Préparation de la reconnaissance arabe (une seule fois)…", systemImage: "arrow.down.circle")
            case .denied(let kind):
                HStack {
                    Text(kind == .microphone ? "Accès au micro refusé." : "Reconnaissance vocale refusée.")
                    Spacer()
                    Button("Réglages") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.footnote.bold())
                }
            case .unsupported:
                Text("Reconnaissance arabe indisponible sur cet appareil.")
            case .failed(let message):
                Text(verbatim: message)
            case .idle, .finished:
                Text(vm.hasResult ? "Résultat enregistré dans ta progression." : "Appuie sur Réciter puis commence après la basmala.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
        .lineLimit(2)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }

    private var disclaimer: some View {
        Label("Un mot non signalé n'est pas forcément juste. Fais valider ta récitation par un enseignant. Le tajwid n'est pas évalué.", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))
            .fixedSize(horizontal: false, vertical: true)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Résultat

struct RecitationResultView: View {
    @Bindable var vm: RecitationSessionViewModel
    let alignment: RecitationAlignment
    let languageCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            scoreCard
            coloredText
            if !alignment.isLowConfidence { legend }
            adviceCard
            listenRow
        }
    }

    private var scoreCard: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if alignment.isLowConfidence {
                Label("Je n'ai pas bien entendu", systemImage: "ear.trianglebadge.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                Text(verbatim: alignment.accuracy.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(alignment.accuracy >= 0.9 ? .green : ModuleAccent.quran)
                Text("des mots reconnus")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Texte de référence colorié mot à mot. Sous faible confiance : aucune couleur
    /// d'erreur (on ne juge pas ce qu'on n'a pas entendu).
    private var coloredText: some View {
        VStack(alignment: .trailing, spacing: 14) {
            ForEach(vm.reference.ayahRange.map { $0 }, id: \.self) { ayah in
                Text(attributedAyah(ayah))
                    .font(ScriptureFont.arabic())
                    .lineSpacing(ScriptureFont.arabicLineSpacing)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scriptureCard(accent: ModuleAccent.quran)
    }

    private func attributedAyah(_ ayah: Int) -> AttributedString {
        var result = AttributedString()
        let items = alignment.items.filter { $0.reference?.ayah == ayah }
        for (i, item) in items.enumerated() {
            guard let word = item.reference else { continue }
            var piece = AttributedString(word.display)
            piece.foregroundColor = color(for: item.kind)
            if item.kind == .omitted && !alignment.isLowConfidence {
                piece.strikethroughStyle = .single
            }
            result += piece
            if i < items.count - 1 { result += AttributedString(" ") }
        }
        var marker = AttributedString(" ﴿\(ayah)﴾")
        marker.foregroundColor = .white.opacity(0.5)
        result += marker
        return result
    }

    private func color(for kind: AlignedWordKind) -> Color {
        guard !alignment.isLowConfidence else { return .white }
        switch kind {
        case .matched: return .white
        case .approximate: return .yellow
        case .substituted: return .orange
        case .omitted: return .red.opacity(0.85)
        case .inserted, .repeated: return .white
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("Juste", .white)
            legendItem("Approximatif", .yellow)
            legendItem("Autre mot", .orange)
            legendItem("Omis", .red.opacity(0.85))
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.65))
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ label: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Conseils", systemImage: "text.bubble.fill")
                .font(.caption.bold())
                .foregroundStyle(ModuleAccent.quran)
            if let paragraph = vm.rephrasedAdvice {
                Text(verbatim: paragraph)
                    .font(ScriptureFont.translation())
                    .lineSpacing(ScriptureFont.translationLineSpacing)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                Text("Reformulé sur ton appareil par Apple Intelligence.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ForEach(vm.tips) { tip in
                    Label {
                        Text(verbatim: tip.textFr)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: icon(for: tip.kind))
                            .foregroundStyle(tip.kind == .perfect ? .green : .orange)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .scriptureCard(accent: ModuleAccent.quran)
        .animation(.smooth(duration: 0.35), value: vm.rephrasedAdvice)
    }

    private func icon(for kind: CoachTipKind) -> String {
        switch kind {
        case .omitted: "minus.circle"
        case .substituted: "arrow.left.arrow.right.circle"
        case .inserted: "plus.circle"
        case .repeated: "repeat.circle"
        case .hesitation: "pause.circle"
        case .lowConfidence: "ear"
        case .perfect: "checkmark.seal.fill"
        }
    }

    private var listenRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                listenButton(
                    title: vm.audio.playing == .advice ? "Arrêter" : "Écouter le conseil",
                    icon: vm.audio.playing == .advice ? "stop.fill" : "speaker.wave.2.fill"
                ) {
                    if vm.audio.playing == .advice { vm.audio.stop() } else {
                        vm.audio.speak(vm.adviceText, languageCode: languageCode)
                    }
                }
                if vm.hasReferenceReciter {
                    listenButton(
                        title: isReciterPlaying ? "Arrêter" : "Écouter le récitateur",
                        icon: isReciterPlaying ? "stop.fill" : "play.circle.fill"
                    ) {
                        if isReciterPlaying { vm.audio.stop() } else {
                            Task { vm.audio.playReciter(await vm.reciterTracks(only: vm.weakestAyah)) }
                        }
                    }
                }
            }
            if let url = vm.transcriber.recordingURL {
                HStack(spacing: 10) {
                    listenButton(
                        title: vm.audio.playing == .ownRecording ? "Arrêter" : "Me réécouter",
                        icon: vm.audio.playing == .ownRecording ? "stop.fill" : "waveform"
                    ) {
                        if vm.audio.playing == .ownRecording { vm.audio.stop() } else { vm.audio.playRecording(at: url) }
                    }
                    ShareLink(item: url) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(ModuleAccent.quran)
                            .background(ModuleAccent.quran.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
                    }
                }
            }
            if !vm.hasReferenceReciter {
                Text("Récitateur de référence disponible en Hafs uniquement pour le moment.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var isReciterPlaying: Bool {
        if case .reciter = vm.audio.playing { return true }
        return false
    }

    private func listenButton(title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(ModuleAccent.quran)
                .background(ModuleAccent.quran.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
        }
    }
}
