//
//  QuranASRSpikeView.swift
//  Muslim Clock — SPIKE Phase 2 Spotlight (code jetable, DEBUG only)
//
//  Harnais de mesure GO/NO-GO de la reconnaissance vocale de versets
//  (PLAN_FEATURE_QURAN_SPOTLIGHT.md §2). Branche SFSpeechRecognizer :
//  1. Probe : l'arabe est-il disponible sur CE device ? en on-device ?
//  2. Boucle de mesure : réciter → transcript live → matcher → top-3 +
//     latence + confiance. À dérouler sur ~30 versets récités réellement.
//
//  La branche Whisper-Coran (tarteel-ai/whisper-base-ar-quran, Apache 2.0,
//  WER annoncé 5,75 %) sera branchée ici si SFSpeech échoue le GO.
//

#if DEBUG
import SwiftUI
import Speech
import AVFoundation

struct QuranASRSpikeView: View {

    // Probe
    @State private var probeReport = "Tape « Sonder » pour vérifier ce device."

    // Session
    @State private var forceOnDevice = true
    @State private var isListening = false
    @State private var transcript = ""
    @State private var status = "Prêt"

    // Mesures
    @State private var matches: [QuranVerseMatch] = []
    @State private var isConfident = false
    @State private var latencyMS: Int?

    // Audio / reco
    @State private var engine: AVAudioEngine?
    @State private var request: SFSpeechAudioBufferRecognitionRequest?
    @State private var task: SFSpeechRecognitionTask?
    @State private var stoppedAt: Date?

    var body: some View {
        Form {
            Section("1 · Probe du device") {
                Button("Sonder SFSpeechRecognizer (ar)") { runProbe() }
                Text(verbatim: probeReport)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Section("2 · Mesure sur récitation") {
                Toggle("Forcer on-device (règle privacy)", isOn: $forceOnDevice)
                    .disabled(isListening)

                Button {
                    if isListening {
                        stopListening()
                    } else {
                        Task { await startListening() }
                    }
                } label: {
                    Label(isListening ? "Arrêter et matcher" : "Réciter un verset",
                          systemImage: isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .foregroundStyle(isListening ? .red : .teal)
                }

                LabeledContent("État", value: status)
                    .font(.caption)

                if !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transcript")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(verbatim: transcript)
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                }
            }

            if !matches.isEmpty || latencyMS != nil {
                Section("3 · Résultat matcher") {
                    if let latencyMS {
                        LabeledContent("Latence stop → résultat", value: "\(latencyMS) ms")
                            .monospacedDigit()
                    }
                    LabeledContent("Confiant (auto-sélection)", value: isConfident ? "OUI ✅" : "non")
                    ForEach(Array(matches.enumerated()), id: \.element.id) { rank, m in
                        HStack {
                            Text(verbatim: "#\(rank + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: "\(m.ref.sura):\(m.ref.ayah)  score \(String(format: "%.2f", m.score))  ×\(m.occurrences.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .monospacedDigit()
                                Text(verbatim: m.displayText)
                                    .font(.system(size: 14))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                            }
                        }
                    }
                    if matches.isEmpty {
                        Text("Aucun verset trouvé")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Text("Protocole : ~30 versets récités réellement (courts/moyens/longs, tajwid naturel ET posé). GO si top-3 ≥ 70 % en naturel, latence ≤ 5 s. Cf. PLAN_FEATURE_QURAN_SPOTLIGHT.md.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Spike ASR Coran")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopListening() }
    }

    // MARK: - Probe

    private func runProbe() {
        let arLocales = SFSpeechRecognizer.supportedLocales()
            .filter { $0.identifier.hasPrefix("ar") }
            .map(\.identifier)
            .sorted()

        var lines: [String] = []
        lines.append("Locales ar : \(arLocales.isEmpty ? "AUCUNE" : arLocales.joined(separator: ", "))")
        for id in arLocales {
            if let r = SFSpeechRecognizer(locale: Locale(identifier: id)) {
                lines.append("\(id) → dispo=\(r.isAvailable ? "OUI" : "non") onDevice=\(r.supportsOnDeviceRecognition ? "OUI" : "NON")")
            }
        }
        if let fr = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")) {
            lines.append("fr-FR (réf.) → dispo=\(fr.isAvailable ? "OUI" : "non") onDevice=\(fr.supportsOnDeviceRecognition ? "OUI" : "NON")")
        }
        lines.append("Verdict : onDevice ar = NON ⇒ SFSpeech éliminé (règle on-device only).")
        probeReport = lines.joined(separator: "\n")
    }

    // MARK: - Écoute

    private func startListening() async {
        // Autorisations : speech puis micro (pattern QuranRecorder).
        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechAuth == .authorized else {
            status = "Reconnaissance vocale refusée (Réglages)"
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            status = "Micro refusé (Réglages)"
            return
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA")) else {
            status = "SFSpeechRecognizer(ar-SA) indisponible"
            return
        }
        guard recognizer.isAvailable else {
            status = "Recognizer ar-SA non disponible (réseau ? assets ?)"
            return
        }

        transcript = ""
        matches = []
        latencyMS = nil
        stoppedAt = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.requiresOnDeviceRecognition = forceOnDevice
            req.taskHint = .dictation

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            engine.prepare()
            try engine.start()

            self.engine = engine
            self.request = req
            self.isListening = true
            self.status = forceOnDevice ? "Écoute (on-device forcé)…" : "Écoute (serveur autorisé)…"

            self.task = recognizer.recognitionTask(with: req) { result, error in
                Task { @MainActor in
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal {
                            await self.runMatch()
                        }
                    }
                    if let error {
                        self.status = "Erreur : \(error.localizedDescription)"
                        self.teardownAudio()
                        // Transcript partiel éventuellement exploitable quand même.
                        if !self.transcript.isEmpty { await self.runMatch() }
                    }
                }
            }
        } catch {
            status = "Échec audio : \(error.localizedDescription)"
            teardownAudio()
        }
    }

    private func stopListening() {
        guard isListening else { return }
        stoppedAt = Date()
        status = "Analyse…"
        request?.endAudio()
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        isListening = false
        // Le résultat final arrive via le callback (isFinal) ; filet de sécurité
        // si le serveur/moteur ne conclut pas sous 3 s : matcher le partiel.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if latencyMS == nil, !transcript.isEmpty { await runMatch() }
        }
    }

    private func teardownAudio() {
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        request = nil
        task?.cancel()
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Matching

    private func runMatch() async {
        guard latencyMS == nil else { return } // une seule mesure par essai
        guard let index = await QuranSearchCorpusLoader.shared.loadIndex() else {
            status = "Index de recherche indisponible"
            return
        }
        let found = index.match(query: transcript)
        matches = found
        isConfident = QuranVerseIndex.isConfident(found)
        if let stoppedAt {
            latencyMS = Int(Date().timeIntervalSince(stoppedAt) * 1000)
        }
        status = "Terminé — \(found.count) candidat(s)"
        teardownAudio()
    }
}
#endif
