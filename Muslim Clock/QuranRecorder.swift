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

    // MARK: - Karaoké

    /// Un passage de verset enregistré : ayahId + timestamp (secondes depuis le start du record).
    struct VersePassage: Codable, Equatable {
        let ayahId: Int
        let timestamp: TimeInterval
    }

    /// Liste des passages marqués (par `markVerse`) durant l'enregistrement courant.
    /// Vidée à chaque `start()` ou `discard()`.
    private(set) var versePassages: [VersePassage] = []

    /// Verset courant calculé pendant la playback (mis à jour par le tick interne).
    /// `nil` hors playback ou avant tout passage. À observer côté SwiftUI pour scroll/highlight.
    private(set) var playbackAyahId: Int?

    /// Verset courant pendant l'enregistrement (= dernier ayahId marqué).
    var recordingAyahId: Int? { versePassages.last?.ayahId }

    /// Marque le passage à un verset (ajoute un VersePassage au tableau).
    /// No-op si on n'est pas en train d'enregistrer.
    func markVerse(ayahId: Int) {
        guard case .recording = state, let started = recordingStartedAt else { return }
        let timestamp = Date().timeIntervalSince(started)
        // Dédoublonnage : si on tape 2× le même ayahId rapidement, on ignore.
        if versePassages.last?.ayahId == ayahId { return }
        versePassages.append(VersePassage(ayahId: ayahId, timestamp: timestamp))
    }

    /// Retourne l'ayahId actif à `time` secondes depuis le start (le dernier passage <= time).
    func currentAyah(at time: TimeInterval) -> Int? {
        versePassages.last(where: { $0.timestamp <= time })?.ayahId
    }

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
        versePassages = []
        playbackAyahId = nil
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
    /// Idempotent : si l'enregistrement n'est plus actif (déjà stoppé par le delegate
    /// ou la limite de durée), on ne fait rien — évite la double transition d'état.
    func stop() {
        guard case .recording = state, let recorder, recorder.isRecording else { return }
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

    /// Arrête la lecture (retour à `.recorded`).
    /// Le nom historique « pause » prêtait à confusion : le player est nil-out (impossible
    /// de reprendre où on s'était arrêté). Si une vraie pause/reprise est requise un jour,
    /// conserver `player` et appeler `player.pause()` sans nil-out.
    func stopPlayback() {
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
        versePassages = []
        playbackAyahId = nil
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
                // Sync karaoké : retrouve le verset actif au temps courant.
                playbackAyahId = currentAyah(at: player.currentTime)
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
        let stamp = Self.fileTimestamp.string(from: Date())
        let safeSlug = Self.suraSlug(from: suraSlug)
        let filename = "Recitation-\(safeSlug.isEmpty ? "Coran" : safeSlug)-\(stamp).m4a"
        return URL.temporaryDirectory.appendingPathComponent(filename)
    }

    /// Normalise un nom de sourate en slug ASCII-safe pour un nom de fichier ou un identifiant.
    /// Ex: `"Al-Fâtiha"` → `"AlFatiha"`. Utilisable depuis n'importe quelle View pour produire
    /// un slug identique à celui que le recorder met dans le fichier.
    static func suraSlug(from name: String) -> String {
        name.replacingOccurrences(of: " ", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    /// DateFormatter réutilisable pour les timestamps de noms de fichiers.
    private static let fileTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f
    }()
}

// MARK: - AVAudioRecorderDelegate

extension QuranRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            // Garde anti-callback orphelin : on n'agit que si on est encore en `.recording`.
            // Sans ça, après un `discard()` manuel l'`.error` viendrait écraser `.idle`.
            guard case .recording = state else { return }
            if flag {
                stop()
            } else {
                state = .error(message: "Enregistrement interrompu.")
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension QuranRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // Garde anti-callback orphelin : on n'agit que si on est encore en `.playingBack`.
            // Sans ça, après un `stopPlayback()` ou `discard()`, on écraserait l'état courant.
            guard case .playingBack = state else { return }
            stopTick()
            self.player = nil
            if let url = lastRecordedURL {
                state = .recorded(url: url, duration: lastRecordedDuration)
            }
            deactivateSession()
        }
    }
}
