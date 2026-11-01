//
//  MatnRecitationView.swift
//  Muslim Clock — module ʿIlm, vérification de récitation d'un matn
//
//  Réutilise le correcteur de récitation (transcription on-device + aligneur)
//  sur le texte d'une leçon. Un matn se LIT plus qu'il ne se psalmodie : le
//  moteur de dictée y est nettement plus fiable que sur le tartil coranique.
//  Aucune écriture : ni progression Leitner, ni `recitation_progress` — c'est
//  un miroir d'auto-contrôle, la validation reste « Je connais cette leçon ».
//

import SwiftUI

struct MatnRecitationView: View {
    @Environment(\.dismiss) private var dismiss
    let lesson: IlmLesson

    @State private var transcriber = RecitationTranscriber()
    @State private var alignment: RecitationAlignment?

    /// Le matn comme passage de référence (un seul « verset », numérotation
    /// sans objet : rien n'est persisté sous ces clés).
    private var reference: RecitationReference {
        RecitationReferenceLoader.makeReference(riwaya: .hafs, surah: 0, ayahTexts: [1: lesson.arabic])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(verbatim: lesson.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if let alignment {
                            resultBlock(alignment)
                        } else {
                            matnText
                        }

                        Label("Récite en voix de lecture posée. Un mot non signalé n'est pas forcément juste.", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .animation(.smooth(duration: 0.35), value: alignment != nil)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                controlBar
            }
            .navigationTitle("Vérifier de mémoire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(ModuleAccent.ilm)
        .onChange(of: transcriber.state) { _, state in
            if state == .finished, alignment == nil, let transcript = transcriber.transcript {
                alignment = RecitationAligner.align(reference: reference, transcript: transcript)
            }
        }
        .onDisappear { transcriber.cancel() }
    }

    // MARK: - Texte

    /// Matn voilé pendant l'exercice : on vérifie la mémoire, pas la lecture.
    private var matnText: some View {
        Text(verbatim: lesson.arabic)
            .font(ScriptureFont.arabic())
            .lineSpacing(ScriptureFont.arabicLineSpacing)
            .foregroundStyle(.white)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
            .blur(radius: transcriber.state == .finished ? 0 : 8)
            .scriptureCard(accent: ModuleAccent.ilm)
            .overlay {
                if transcriber.state != .finished {
                    Label("Récite de mémoire", systemImage: "eye.slash")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
    }

    @ViewBuilder
    private func resultBlock(_ alignment: RecitationAlignment) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if alignment.isLowConfidence {
                Label("Je n'ai pas bien entendu", systemImage: "ear.trianglebadge.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                Text(verbatim: alignment.accuracy.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(alignment.accuracy >= 0.9 ? .green : ModuleAccent.ilm)
                Text("des mots reconnus")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }

        Text(coloredMatn(alignment))
            .font(ScriptureFont.arabic())
            .lineSpacing(ScriptureFont.arabicLineSpacing)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .fixedSize(horizontal: false, vertical: true)
            .scriptureCard(accent: ModuleAccent.ilm)

        if !alignment.isLowConfidence {
            HStack(spacing: 14) {
                legendItem("Juste", .white)
                legendItem("Approximatif", .yellow)
                legendItem("Autre mot", .orange)
                legendItem("Omis", .red.opacity(0.85))
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.65))
        }
    }

    private func coloredMatn(_ alignment: RecitationAlignment) -> AttributedString {
        var result = AttributedString()
        let spoken = alignment.items.filter { $0.reference != nil }
        for (i, item) in spoken.enumerated() {
            guard let word = item.reference else { continue }
            var piece = AttributedString(word.display)
            piece.foregroundColor = color(for: item.kind, lowConfidence: alignment.isLowConfidence)
            if item.kind == .omitted && !alignment.isLowConfidence {
                piece.strikethroughStyle = .single
            }
            result += piece
            if i < spoken.count - 1 { result += AttributedString(" ") }
        }
        return result
    }

    private func color(for kind: AlignedWordKind, lowConfidence: Bool) -> Color {
        guard !lowConfidence else { return .white }
        switch kind {
        case .matched: return .white
        case .approximate: return .yellow
        case .substituted: return .orange
        case .omitted: return .red.opacity(0.85)
        case .inserted, .repeated, .unverifiable: return .white
        }
    }

    private func legendItem(_ label: LocalizedStringKey, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    // MARK: - Contrôles

    @ViewBuilder
    private var controlBar: some View {
        VStack(spacing: 8) {
            statusLine
            Button {
                Task {
                    switch transcriber.state {
                    case .listening:
                        await transcriber.stop()
                    case .finished:
                        alignment = nil
                        transcriber.acknowledge()
                        await transcriber.start(hints: reference.recognitionHints)
                    default:
                        await transcriber.start(hints: reference.recognitionHints)
                    }
                }
            } label: {
                Label(buttonTitle, systemImage: buttonIcon)
                    .bold()
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(transcriber.state == .listening
                                ? AnyShapeStyle(Color.orange.gradient)
                                : AnyShapeStyle(ModuleAccent.ilm.gradient))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
            }
            .disabled(transcriber.state == .preparing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var buttonTitle: LocalizedStringKey {
        switch transcriber.state {
        case .listening: "Terminer"
        case .finished: "Réessayer"
        default: "Réciter"
        }
    }

    private var buttonIcon: String {
        switch transcriber.state {
        case .listening: "stop.fill"
        case .finished: "arrow.counterclockwise"
        default: "mic.fill"
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            switch transcriber.state {
            case .listening:
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("J'écoute… \(transcriber.heardWordCount) mots")
                        .monospacedDigit()
                }
            case .preparing:
                Label("Préparation de la reconnaissance arabe (une seule fois)…", systemImage: "arrow.down.circle")
            case .denied(let kind):
                Text(kind == .microphone ? "Accès au micro refusé." : "Reconnaissance vocale refusée.")
            case .unsupported:
                Text("Reconnaissance arabe indisponible sur cet appareil.")
            case .failed(let message):
                Text(verbatim: message)
            case .idle, .finished:
                Text("Récite le matn de mémoire, l'app te montre ce qui diffère.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
        .lineLimit(2)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
    }
}
