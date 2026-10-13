//
//  RecitationTranscriber.swift
//  Muslim Clock — Correcteur de récitation (phase 5 : capture)
//
//  Écoute la récitation et produit une `RecitationTranscript`.
//  Règle NON NÉGOCIABLE : reconnaissance ON-DEVICE uniquement, l'audio ne
//  quitte jamais l'appareil (sauf partage explicite du fichier par l'utilisateur).
//
//  Moteurs, par ordre de préférence :
//  1. `SpeechAnalyzer` + `DictationTranscriber` (ar-SA) — horodatage par segment,
//     donc détection des hésitations ;
//  2. `SFSpeechRecognizer` on-device — horodatage par mot via les segments de
//     transcription (mode dégradé si 1 indisponible).
//  Un seul tap micro alimente la reconnaissance ET un fichier audio local
//  (réécoute / partage) : pas de second enregistreur concurrent.
//

import Foundation
import AVFoundation
import Speech
import os

@MainActor
@Observable
final class RecitationTranscriber {

    enum Engine: Equatable {
        case analyzer
        case legacy
    }

    enum PermissionKind: Equatable {
        case microphone
        case speech
    }

    enum State: Equatable {
        case idle
        /// Téléchargement du modèle de langue arabe (une fois, fourni par le système).
        case preparing
        case listening
        /// Fin d'écoute : transcription finalisée.
        case finished
        case denied(PermissionKind)
        /// Aucune reconnaissance arabe sur l'appareil — on ne bascule JAMAIS vers un serveur.
        case unsupported
        case failed(String)
    }

    /// Plafond d'écoute (même limite que l'enregistreur de récitation).
    static let maxListeningSeconds: TimeInterval = QuranRecorder.maxRecordingDuration
    /// Arrêt automatique après ce silence, une fois que quelque chose a été entendu.
    /// Plus long que la recherche vocale : on respire entre deux versets.
    static let silenceStopSeconds: TimeInterval = 5
    static let locale = Locale(identifier: "ar-SA")

    private(set) var state: State = .idle
    private(set) var engine: Engine?
    /// Nombre de mots entendus jusqu'ici (indicateur « j'écoute » — jamais le texte brut).
    private(set) var heardWordCount = 0
    private(set) var elapsed: TimeInterval = 0
    /// Fichier audio de la dernière écoute (réécoute, partage).
    private(set) var recordingURL: URL?
    /// Résultat final, disponible en état `.finished`.
    private(set) var transcript: RecitationTranscript?

    private let logger = Logger(subsystem: "com.kappsi.muslimclock", category: "Recitation")

    private var audioEngine: AVAudioEngine?
    private var capture: AudioCapture?
    private var watchdog: Task<Void, Never>?
    private var startedAt: Date?
    private var lastHeardAt: Date?

    // SpeechAnalyzer
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var finalizedSegments: [(text: String, range: ClosedRange<TimeInterval>?)] = []

    // SFSpeechRecognizer
    private var legacyRequest: SFSpeechAudioBufferRecognitionRequest?
    private var legacyTask: SFSpeechRecognitionTask?
    private var legacyTranscript: RecitationTranscript?

    // MARK: - Capacité

    /// Meilleur moteur disponible pour l'arabe sur cet appareil, `nil` si aucun.
    static func availableEngine() async -> Engine? {
        if await DictationTranscriber.supportedLocale(equivalentTo: locale) != nil {
            return .analyzer
        }
        if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition {
            return .legacy
        }
        return nil
    }

    // MARK: - Cycle de vie

    /// Demande les autorisations, prépare le moteur et commence l'écoute.
    func start() async {
        guard state != .listening, state != .preparing else { return }
        reset()

        guard await AVAudioApplication.requestRecordPermission() else {
            state = .denied(.microphone)
            return
        }
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechAuth == .authorized else {
            state = .denied(.speech)
            return
        }
        guard let engine = await Self.availableEngine() else {
            state = .unsupported
            return
        }
        self.engine = engine

        do {
            switch engine {
            case .analyzer: try await startAnalyzer()
            case .legacy: try startLegacy()
            }
            startedAt = Date()
            state = .listening
            startWatchdog()
        } catch {
            logger.error("Démarrage de l'écoute impossible : \(error.localizedDescription)")
            teardownAudio()
            state = .failed(error.localizedDescription)
        }
    }

    /// Arrête l'écoute et finalise la transcription. Idempotent.
    func stop() async {
        guard state == .listening else { return }
        watchdog?.cancel()
        watchdog = nil
        teardownAudio()

        switch engine {
        case .analyzer:
            inputContinuation?.finish()
            inputContinuation = nil
            do {
                try await analyzer?.finalizeAndFinishThroughEndOfInput()
            } catch {
                logger.error("Finalisation SpeechAnalyzer : \(error.localizedDescription)")
            }
            await resultsTask?.value
            resultsTask = nil
            analyzer = nil
            transcript = RecitationTranscript.fromSegments(finalizedSegments)
        case .legacy:
            legacyRequest?.endAudio()
            // Laisse le moteur livrer son dernier résultat (borné).
            for _ in 0..<10 where legacyTask?.state == .running || legacyTask?.state == .finishing {
                try? await Task.sleep(for: .milliseconds(100))
            }
            legacyTask?.cancel()
            legacyTask = nil
            legacyRequest = nil
            transcript = legacyTranscript ?? RecitationTranscript(tokens: [])
        case nil:
            transcript = RecitationTranscript(tokens: [])
        }
        state = .finished
    }

    /// Abandonne l'écoute sans résultat (fermeture de l'écran). Idempotent.
    func cancel() {
        watchdog?.cancel()
        watchdog = nil
        teardownAudio()
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        analyzer = nil
        legacyTask?.cancel()
        legacyTask = nil
        legacyRequest = nil
        if state == .listening || state == .preparing { state = .idle }
    }

    func acknowledge() {
        switch state {
        case .denied, .failed, .unsupported, .finished: state = .idle
        default: break
        }
    }

    private func reset() {
        heardWordCount = 0
        elapsed = 0
        transcript = nil
        finalizedSegments = []
        legacyTranscript = nil
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil
    }

    // MARK: - SpeechAnalyzer

    private func startAnalyzer() async throws {
        let transcriber = DictationTranscriber(
            locale: Self.locale,
            contentHints: [],
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        // Modèle arabe : fourni par le système, téléchargé une seule fois.
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            state = .preparing
            try await request.downloadAndInstall()
        }

        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = continuation

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    self?.handle(result)
                }
            } catch {
                self?.logResultsError(error)
            }
        }

        try startAudio(converterFormat: analyzerFormat) { buffer in
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
        try await analyzer.start(inputSequence: stream)
    }

    private func handle(_ result: DictationTranscriber.Result) {
        let wordCount = String(result.text.characters).split(whereSeparator: \.isWhitespace).count
        lastHeardAt = Date()
        guard result.isFinal else {
            heardWordCount = finalizedWordCount + wordCount
            return
        }
        // Un segment par run horodaté : les pauses entre runs sont préservées.
        var segments: [(text: String, range: ClosedRange<TimeInterval>?)] = []
        for run in result.text.runs {
            let text = String(result.text[run.range].characters)
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let range = run.audioTimeRange.map { r -> ClosedRange<TimeInterval> in
                let start = r.start.seconds
                let end = r.end.seconds
                return start...max(start, end)
            }
            segments.append((text, range))
        }
        if segments.isEmpty {
            segments = [(String(result.text.characters), nil)]
        }
        finalizedSegments += segments
        heardWordCount = finalizedWordCount
    }

    private var finalizedWordCount: Int {
        finalizedSegments.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    private func logResultsError(_ error: Error) {
        logger.error("Résultats SpeechAnalyzer : \(error.localizedDescription)")
    }

    // MARK: - SFSpeechRecognizer (repli)

    private func startLegacy() throws {
        guard let recognizer = SFSpeechRecognizer(locale: Self.locale), recognizer.isAvailable else {
            throw RecitationCaptureError.recognizerUnavailable
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Règle privacy NON NÉGOCIABLE : jamais de reconnaissance serveur.
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        legacyRequest = request

        try startAudio(converterFormat: nil) { buffer in
            request.append(buffer)
        }

        legacyTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let result else {
                if let error {
                    Task { @MainActor in self?.logResultsError(error) }
                }
                return
            }
            // Segments mot à mot horodatés (secondes depuis le début de la requête).
            let tokens = result.bestTranscription.segments.map { segment in
                (text: segment.substring,
                 range: Optional(segment.timestamp...(segment.timestamp + segment.duration)))
            }
            let transcript = RecitationTranscript.fromSegments(tokens)
            Task { @MainActor in
                guard let self else { return }
                self.legacyTranscript = transcript
                self.heardWordCount = transcript.tokens.count
                self.lastHeardAt = Date()
            }
        }
    }

    // MARK: - Audio

    /// Démarre le micro. Chaque buffer est écrit dans le fichier de réécoute puis,
    /// converti si besoin au format du moteur, transmis à `deliver`.
    private func startAudio(converterFormat: AVAudioFormat?, deliver: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        let url = URL.temporaryDirectory.appending(path: "recitation-\(UUID().uuidString).m4a")
        let capture = try AudioCapture(inputFormat: inputFormat, targetFormat: converterFormat, fileURL: url, deliver: deliver)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: capture.makeTapBlock())
        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.capture = capture
        self.recordingURL = url
    }

    private func teardownAudio() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        capture?.close()
        capture = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Désactivation de la session audio : \(error.localizedDescription)")
        }
    }

    // MARK: - Watchdog (silence, plafond)

    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, self.state == .listening, let started = self.startedAt else { return }
                let now = Date()
                self.elapsed = now.timeIntervalSince(started)
                if self.elapsed >= Self.maxListeningSeconds {
                    await self.stop()
                    return
                }
                // On ne coupe sur silence qu'après avoir entendu quelque chose.
                if let last = self.lastHeardAt, self.heardWordCount > 0,
                   now.timeIntervalSince(last) >= Self.silenceStopSeconds {
                    await self.stop()
                    return
                }
            }
        }
    }
}

nonisolated enum RecitationCaptureError: LocalizedError {
    case recognizerUnavailable
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            String(localized: "La reconnaissance vocale arabe n'est pas disponible pour le moment.")
        case .converterUnavailable:
            String(localized: "Format audio du micro non pris en charge.")
        }
    }
}

/// Traitement des buffers micro, hors MainActor (thread audio temps réel) :
/// écriture du fichier de réécoute + conversion au format du moteur.
private nonisolated final class AudioCapture: @unchecked Sendable {
    private let file: AVAudioFile
    private let converter: AVAudioConverter?
    private let targetFormat: AVAudioFormat?
    private let deliver: @Sendable (AVAudioPCMBuffer) -> Void
    private let lock = NSLock()
    private var isClosed = false

    init(inputFormat: AVAudioFormat, targetFormat: AVAudioFormat?, fileURL: URL,
         deliver: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        // AAC mono 32 kb/s, comme QuranRecorder (≈240 Ko/min).
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
        file = try AVAudioFile(forWriting: fileURL, settings: settings,
                               commonFormat: .pcmFormatFloat32, interleaved: false)
        self.targetFormat = targetFormat
        if let targetFormat, targetFormat != inputFormat {
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw RecitationCaptureError.converterUnavailable
            }
            self.converter = converter
        } else {
            self.converter = nil
        }
        self.deliver = deliver
    }

    func makeTapBlock() -> AVAudioNodeTapBlock {
        { [self] buffer, _ in process(buffer) }
    }

    func close() {
        lock.lock()
        isClosed = true
        lock.unlock()
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed else { return }

        do {
            try file.write(from: monoView(of: buffer))
        } catch {
            Logger(subsystem: "com.kappsi.muslimclock", category: "Recitation")
                .error("Écriture audio : \(error.localizedDescription)")
        }

        guard let converter, let targetFormat else {
            deliver(buffer)
            return
        }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let error {
            Logger(subsystem: "com.kappsi.muslimclock", category: "Recitation")
                .error("Conversion audio : \(error.localizedDescription)")
            return
        }
        if converted.frameLength > 0 { deliver(converted) }
    }

    /// Le fichier est mono : on n'écrit que le premier canal du micro.
    private func monoView(of buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard buffer.format.channelCount > 1,
              let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate,
                                       channels: 1, interleaved: false),
              let out = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buffer.frameLength),
              let src = buffer.floatChannelData, let dst = out.floatChannelData else {
            return buffer
        }
        out.frameLength = buffer.frameLength
        dst[0].update(from: src[0], count: Int(buffer.frameLength))
        return out
    }
}
