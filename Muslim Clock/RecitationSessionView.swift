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
    /// Couleurs tajwid sur le texte de référence (affichage ; jamais évalué).
    @AppStorage("recitationTajweedColors") private var tajweedColors = true

    init(reference: RecitationReference, hideText: Bool) {
        _vm = State(initialValue: RecitationSessionViewModel(reference: reference))
        self.hideText = hideText
    }

    private var languageCode: String { locale.language.languageCode?.identifier ?? "fr" }

    /// Pas de changement de sourate pendant l'écoute, l'analyse ou un chargement.
    private var isNavigationLocked: Bool {
        vm.transcriber.state == .listening || vm.transcriber.state == .preparing
            || vm.isCalibrating || vm.isLoadingReference
    }

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
        .toolbar {
            // Sourate précédente / suivante — uniquement s'il en existe une.
            ToolbarItemGroup(placement: .topBarTrailing) {
                if vm.hasPreviousSurah {
                    Button {
                        Task { await vm.moveToSurah(vm.reference.surah - 1) }
                    } label: {
                        Label("Sourate précédente", systemImage: "chevron.backward")
                    }
                    .disabled(isNavigationLocked)
                }
                if vm.hasNextSurah {
                    Button {
                        Task { await vm.moveToSurah(vm.reference.surah + 1) }
                    } label: {
                        Label("Sourate suivante", systemImage: "chevron.forward")
                    }
                    .disabled(isNavigationLocked)
                }
            }
        }
        .onChange(of: vm.transcriber.state) { _, state in
            if state == .finished {
                Task {
                    await vm.analyzeIfFinished()
                    await vm.rephraseAdvice(languageCode: languageCode)
                }
            }
        }
        .onDisappear { vm.cancel() }
        // Couleurs tajwid du passage (rechargées si la sourate ou la plage change).
        .task(id: "\(vm.reference.surah):\(vm.reference.ayahRange)") { await vm.loadTajweed() }
        .sensoryFeedback(.start, trigger: vm.transcriber.state == .listening)
        .sensoryFeedback(.success, trigger: vm.hasResult)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 10) {
            Text(verbatim: rangeLabel)
                .font(.caption.bold())
                .foregroundStyle(ModuleAccent.quran)
                .chipStyle(color: ModuleAccent.quran)
            Spacer()
            if !vm.tajweed.isEmpty {
                Button {
                    withAnimation(.smooth(duration: 0.25)) { tajweedColors.toggle() }
                } label: {
                    Image(systemName: tajweedColors ? "paintpalette.fill" : "paintpalette")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tajweedColors ? ModuleAccent.quran : .white.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Couleurs tajwid"))
                .accessibilityValue(Text(tajweedColors ? "Activées" : "Désactivées"))
            }
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
            VStack(alignment: .trailing, spacing: 14) {
                ForEach(vm.reference.ayahRange.map { $0 }, id: \.self) { ayah in
                    Text(referenceAyah(ayah))
                        .font(ScriptureFont.arabic())
                        .lineSpacing(ScriptureFont.arabicLineSpacing)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Voile de mémorisation : flou à hauteur constante (aucun saut au dévoilement).
            .blur(radius: hideText && vm.transcriber.state != .finished ? 8 : 0)
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

            if showsTajweed {
                tajweedLegend
            }
        }
        .scriptureCard(accent: ModuleAccent.quran)
        .animation(.smooth(duration: 0.25), value: showsTajweed)
        .accessibilityLabel(hideText ? Text("Texte masqué pour la mémorisation") : Text(verbatim: vm.reference.ayahTexts.values.joined(separator: " ")))
    }

    private var showsTajweed: Bool { tajweedColors && !vm.tajweed.isEmpty }

    /// Texte du verset : coloré par règle tajwid quand l'édition annotée est
    /// disponible et activée, sinon le texte de référence en blanc.
    private func referenceAyah(_ ayah: Int) -> AttributedString {
        var result = AttributedString()
        if showsTajweed, let runs = vm.tajweed[ayah] {
            for run in runs {
                var piece = AttributedString(run.text)
                piece.foregroundColor = run.rule?.family.color ?? .white
                result += piece
            }
        } else {
            var piece = AttributedString(vm.reference.ayahTexts[ayah] ?? "")
            piece.foregroundColor = .white
            result = piece
        }
        var marker = AttributedString(" ﴿\(ayah)﴾")
        marker.foregroundColor = .white.opacity(0.5)
        result += marker
        return result
    }

    /// Légende limitée aux règles présentes dans le passage — informatif,
    /// le tajwid n'est pas évalué (cf. disclaimer).
    private var tajweedLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ForEach(vm.tajweedFamilies, id: \.self) { family in
                    HStack(spacing: 4) {
                        Circle().fill(family.color).frame(width: 7, height: 7)
                        Text(verbatim: family.label)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.65))
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Couleurs du mushaf tajwid, à titre indicatif.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .accessibilityElement(children: .combine)
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
            case .finished where vm.isCalibrating:
                Label("Analyse de ta récitation…", systemImage: "waveform.badge.magnifyingglass")
            case .idle, .finished:
                Text(vm.hasResult ? "Résultat enregistré dans ta progression." : "Appuie sur Réciter puis commence après la basmala.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
        .lineLimit(3)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            // La reconnaissance décroche sur le tartil chanté (madd tenus,
            // mélodie) : une voix de lecture posée donne de meilleurs résultats.
            Label("Astuce : récite en voix de lecture posée, sans psalmodie — la reconnaissance comprend mieux.", systemImage: "lightbulb")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Label("Un mot non signalé n'est pas forcément juste. Fais valider ta récitation par un enseignant. Le tajwid n'est pas évalué.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
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
            heardTranscript
            adviceCard
            listenRow
        }
    }

    /// Ce que le moteur a réellement entendu, replié par défaut : permet de
    /// distinguer une erreur de récitation d'une erreur de reconnaissance
    /// (« je l'ai bien dit, c'est le téléphone qui a mal entendu »).
    private var heardTranscript: some View {
        DisclosureGroup {
            Text(verbatim: heardText)
                .font(ScriptureFont.arabic(ScriptureFont.arabicCompact))
                .lineSpacing(ScriptureFont.arabicLineSpacing)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .textSelection(.enabled)
        } label: {
            Label("Ce que j'ai entendu", systemImage: "ear")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
        }
        .tint(.white.opacity(0.7))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassCardSecondary(cornerRadius: CornerRadius.card, tint: ModuleAccent.quran)
    }

    /// Mots entendus dans l'ordre, sans doublon de fusion (un même mot entendu
    /// rattaché à deux mots de référence n'apparaît qu'une fois).
    private var heardText: String {
        var words: [String] = []
        var last: HeardToken?
        for item in alignment.items {
            guard let heard = item.heard, heard != last else { continue }
            words.append(heard.text)
            last = heard
        }
        return words.isEmpty ? String(localized: "Rien d'exploitable n'a été entendu.") : words.joined(separator: " ")
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
        case .unverifiable: return .white.opacity(0.45)
        case .inserted, .repeated: return .white
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                legendItem("Juste", .white)
                legendItem("Approximatif", .yellow)
                legendItem("Autre mot", .orange)
                legendItem("Omis", .red.opacity(0.85))
                if alignment.hasUnverifiableWords {
                    legendItem("Non vérifiable", .white.opacity(0.45))
                }
            }
            if alignment.hasUnverifiableWords {
                Text("Les mots grisés échappent à la reconnaissance, même sur le récitateur : ils ne comptent pas dans ton score.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Ce que la calibration a réellement fait — ou pourquoi elle n'a rien pu faire.
            if let summary = vm.calibrationSummary {
                Label {
                    Text(verbatim: summary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: vm.calibration.status == .ready ? "checkmark.seal" : "exclamationmark.triangle")
                }
                .foregroundStyle(vm.calibration.status == .ready ? .white.opacity(0.65) : .orange.opacity(0.9))
            }
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
