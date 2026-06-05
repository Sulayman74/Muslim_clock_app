//
//  QuranRecorder.swift
//  Muslim Clock — module Quran Library
//
//  Service d'enregistrement de récitation : capture audio M4A (AAC mono ~32 kbps),
//  playback du résultat, et exposition d'une URL prête pour `ShareLink`.
//
//  Durée hard-cap : 10 min. Stockage : `URL.temporaryDirectory` (auto-nettoyé au
//  prochain `start()` ou `discard()`).
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class QuranRecorder: NSObject {

    /// Limite de durée d'enregistrement (10 minutes).
    static let maxRecordingDuration: TimeInterval = 10 * 60

    /// Format audio : AAC mono 44.1 kHz 32 kbps → ≈240 Ko/min.
    private static let recordSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        AVEncoderBitRateKey: 32_000,
    ]

    /// État courant exposé à l'UI (SwiftUI re-render via @Observable).
    enum State: Equatable {
        case idle
        case requestingPermission
        case permissionDenied
        case recording(elapsed: TimeInterval)
        case recorded(url: URL, duration: TimeInterval)
        case playingBack(progress: Double, duration: TimeInterval)
        case error(message: String)
    }

    private(set) var state: State = .idle

    // MARK: - Privé

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var tickTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var lastRecordedURL: URL?
    private var lastRecordedDuration: TimeInterval = 0
    /// Nom de la sourate au moment du `start()` — sert au nommage de fichier.
    private var currentSuraSlug: String = "recitation"

    // MARK: - API

    /// Demande l'autorisation micro (iOS 17+).
    func requestPermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        state = .requestingPermission
        let granted = await AVAudioApplication.requestRecordPermission()
        if !granted {
            state = .permissionDenied
        } else {
            state = .idle
        }
        return granted
    }

    /// Démarre un nouvel enregistrement. `suraSlug` est utilisé pour le nom de fichier (ex: "AlFatiha").
    /// Discard implicite de l'enregistrement précédent.
    func start(suraSlug: String) {
        // Reset état précédent + cleanup fichier précédent.
        cleanupLastRecording()
        currentSuraSlug = suraSlug.isEmpty ? "Recitation" : suraSlug

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: [])
        } catch {
            state = .error(message: "Impossible d'activer le micro : \(error.localizedDescription)")
            return
        }

        let url = makeFileURL(suraSlug: currentSuraSlug)
        do {
            let recorder = try AVAudioRecorder(url: url, settings: Self.recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = false
            guard recorder.prepareToRecord(), recorder.record(forDuration: Self.maxRecordingDuration) else {
                state = .error(message: "Le micro n'a pas pu démarrer.")
                return
            }
            self.recorder = recorder
            self.recordingStartedAt = Date()
            self.lastRecordedURL = url
            state = .recording(elapsed: 0)
            startTick()
        } catch {
            state = .error(message: "Échec d'initialisation du recorder : \(error.localizedDescription)")
        }
    }

    /// Arrête l'enregistrement en cours. Bascule sur `.recorded` si succès.
    func stop() {
        guard let recorder, recorder.isRecording else { return }
        recorder.stop()
        stopTick()
        let duration = recorder.currentTime > 0 ? recorder.currentTime : (recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0)
        lastRecordedDuration = duration
        if let url = lastRecordedURL {
            state = .recorded(url: url, duration: duration)
        } else {
            state = .error(message: "Fichier introuvable après enregistrement.")
        }
        self.recorder = nil
        deactivateSession()
    }

    /// Lance la lecture du dernier enregistrement.
    func play() {
        guard case .recorded(let url, let duration) = state else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true, options: [])

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            guard player.prepareToPlay(), player.play() else {
                state = .error(message: "Impossible de démarrer la lecture.")
                return
            }
            self.player = player
            state = .playingBack(progress: 0, duration: duration)
            startPlaybackTick()
        } catch {
            state = .error(message: "Lecture impossible : \(error.localizedDescription)")
        }
    }

    /// Met en pause la lecture (retour à `.recorded` figé sur la position courante).
    func pausePlayback() {
        guard case .playingBack = state, let player else { return }
        player.pause()
        stopTick()
        if let url = lastRecordedURL {
            state = .recorded(url: url, duration: lastRecordedDuration)
        }
        self.player = nil
        deactivateSession()
    }

    /// Jette l'enregistrement courant (fichier + état). Retour à `.idle`.
    func discard() {
        stopTick()
        recorder?.stop()
        recorder = nil
        player?.stop()
        player = nil
        cleanupLastRecording()
        deactivateSession()
        state = .idle
    }

    // MARK: - Privé : timer & cleanup

    private func startTick() {
        tickTask?.cancel()
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                guard let recorder, recorder.isRecording,
                      let start = recordingStartedAt else { break }
                let elapsed = min(Date().timeIntervalSince(start), Self.maxRecordingDuration)
                state = .recording(elapsed: elapsed)
                if elapsed >= Self.maxRecordingDuration {
                    stop()
                    break
                }
            }
        }
    }

    private func startPlaybackTick() {
        tickTask?.cancel()
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                guard let player, player.isPlaying else { break }
                let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                state = .playingBack(progress: progress, duration: player.duration)
            }
        }
    }

    private func stopTick() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func cleanupLastRecording() {
        if let url = lastRecordedURL {
            try? FileManager.default.removeItem(at: url)
        }
        lastRecordedURL = nil
        lastRecordedDuration = 0
        recordingStartedAt = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Construit l'URL du fichier d'enregistrement dans le répertoire temporaire.
    /// Format : `Recitation-{slug}-{yyyyMMdd-HHmm}.m4a` — ASCII-safe pour partage cross-plateforme.
    private func makeFileURL(suraSlug: String) -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmm"
        let stamp = fmt.string(from: Date())
        let safeSlug = suraSlug.replacingOccurrences(of: " ", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let filename = "Recitation-\(safeSlug.isEmpty ? "Coran" : safeSlug)-\(stamp).m4a"
        return URL.temporaryDirectory.appendingPathComponent(filename)
    }
}

// MARK: - AVAudioRecorderDelegate

extension QuranRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            // Cas où l'enregistrement se termine sur la limite hard (10 min) ou interruption système.
            if flag, case .recording = state {
                stop()
            } else if !flag {
                state = .error(message: "Enregistrement interrompu.")
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension QuranRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopTick()
            self.player = nil
            if let url = lastRecordedURL {
                state = .recorded(url: url, duration: lastRecordedDuration)
            }
            deactivateSession()
        }
    }
}
