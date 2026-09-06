//
//  QuranVerseIdentifier.swift
//  Muslim Clock — Spotlight du Coran (Phase 2 : saisie vocale)
//
//  Reconnaissance vocale arabe ON-DEVICE ONLY (règle privacy actée au plan :
//  l'audio ne quitte jamais l'appareil — `requiresOnDeviceRecognition` en dur).
//  Le service ne fait QUE produire le transcript en streaming : la vue
//  l'injecte dans le champ de recherche, et le pipeline de recherche existant
//  (normaliseur + matcher) fait le reste — le transcript reste visible et
//  éditable, c'est le filet de sécurité du cadrage Spotlight.
//
//  Validé par le spike GO/NO-GO (33 essais, iPhone 14) : top-1 91 %,
//  top-3 94 %, 0 % de faux positifs confiants, ~40 ms — cf.
//  PLAN_FEATURE_QURAN_SPOTLIGHT.md §Phase 2.
//

import Foundation
import Speech
import AVFoundation

@MainActor
@Observable
final class QuranVerseIdentifier {

    enum PermissionKind: Equatable {
        case microphone
        case speech
    }

    enum State: Equatable {
        case idle
        case listening
        case denied(PermissionKind)
    }

    private(set) var state: State = .idle

    /// Transcript arabe courant (partiels streaming). La vue le copie dans le
    /// champ de recherche à chaque évolution.
    private(set) var transcript = ""

    /// Écoute plafonnée (marge sous toute limite système, et un verset se
    /// récite en bien moins).
    static let maxListeningSeconds: TimeInterval = 30
    /// Arrêt automatique après ce silence (aucun nouveau partiel).
    static let silenceStopSeconds: TimeInterval = 2.5

    /// Recognizer partagé — l'instancier tôt amortit le warmup du premier
    /// usage (~900 ms mesurées au spike).
    private static let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))

    /// `true` si la reconnaissance arabe ON-DEVICE existe sur ce device.
    /// Conditionne l'affichage du bouton micro — on ne propose JAMAIS le mode
    /// serveur (le PrivacyInfo « zéro collecte » est un différenciateur).
    static var isSupported: Bool {
        guard let recognizer else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    // MARK: - Privé

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var watchdog: Task<Void, Never>?
    private var startedAt: Date?
    private var lastPartialAt: Date?

    // MARK: - API

    /// Démarre l'écoute. Demande les autorisations au premier usage.
    func start() async {
        guard state != .listening else { return }

        let speechAuth = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechAuth == .authorized else {
            state = .denied(.speech)
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .denied(.microphone)
            return
        }
        guard let recognizer = Self.recognizer, recognizer.isAvailable else {
            // isSupported a déjà filtré l'affichage — ceci couvre un état
            // transitoire (assets en cours d'installation).
            state = .idle
            return
        }

        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Règle privacy NON NÉGOCIABLE : jamais de reco serveur.
            request.requiresOnDeviceRecognition = true
            request.taskHint = .dictation

            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024,
                             format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()

            self.engine = engine
            self.request = request
            self.startedAt = Date()
            self.lastPartialAt = nil
            self.state = .listening

            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        self.lastPartialAt = Date()
                        if result.isFinal { self.stop() }
                    }
                    if error != nil {
                        // Fin de flux ou erreur moteur : le transcript partiel
                        // reste dans le champ — l'utilisateur peut l'éditer.
                        self.stop()
                    }
                }
            }

            startWatchdog()
        } catch {
            print("⚠️ [VerseIdentifier] Échec audio : \(error.localizedDescription)")
            stop()
        }
    }

    /// Arrête l'écoute (manuel, silence, cap ou fin de flux). Idempotent.
    func stop() {
        watchdog?.cancel()
        watchdog = nil
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        if state == .listening { state = .idle }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Sort d'un état `denied` après l'alerte.
    func acknowledgeDenied() {
        if case .denied = state { state = .idle }
    }

    // MARK: - Watchdog silence / cap

    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard let self, self.state == .listening else { return }
                let now = Date()
                if let started = self.startedAt,
                   now.timeIntervalSince(started) > Self.maxListeningSeconds {
                    self.stop()
                    return
                }
                // Silence : on ne coupe que si on a déjà entendu quelque chose —
                // laisser le temps de commencer à réciter.
                if let last = self.lastPartialAt,
                   !self.transcript.isEmpty,
                   now.timeIntervalSince(last) > Self.silenceStopSeconds {
                    self.stop()
                    return
                }
            }
        }
    }
}
