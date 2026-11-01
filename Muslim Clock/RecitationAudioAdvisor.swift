//
//  RecitationAudioAdvisor.swift
//  Muslim Clock — Correcteur de récitation (phase 6)
//
//  Sorties audio de l'écran de résultat : récitateur de référence verset par
//  verset, réécoute de sa propre récitation. Une seule source à la fois.
//  (La lecture vocale du conseil a été retirée : le conseil reste écrit.)
//

import Foundation
import AVFoundation
import os

@MainActor
@Observable
final class RecitationAudioAdvisor: NSObject {

    enum Playing: Equatable {
        case none
        case reciter(ayah: Int)
        case ownRecording
    }

    private(set) var playing: Playing = .none

    private var player: AVPlayer?
    private var recordingPlayer: AVAudioPlayer?
    private var queue: [(ayah: Int, url: URL)] = []
    private var endObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.kappsi.muslimclock", category: "Recitation")

    // MARK: - Récitateur de référence

    /// Récite les versets donnés à la suite (Hafs, Mishary Alafasy — même source
    /// que le verset du jour). `nil` pour les autres riwayat : aucune source par
    /// verset n'est garantie dans leur numérotation.
    nonisolated static func reciterURL(riwaya: Riwaya, globalAyahNumber: Int) -> URL? {
        guard riwaya == .hafs, (1...Riwaya.hafs.totalAyahs).contains(globalAyahNumber) else { return nil }
        return URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(globalAyahNumber).mp3")
    }

    func playReciter(_ items: [(ayah: Int, url: URL)]) {
        stop()
        guard !items.isEmpty else { return }
        activateSession()
        queue = items
        playNextInQueue()
    }

    private func playNextInQueue() {
        guard !queue.isEmpty else {
            stop()
            return
        }
        let item = queue.removeFirst()
        let playerItem = AVPlayerItem(url: item.url)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: playerItem, queue: .main
        ) { [weak self] _ in
            // Observateur sur la file principale : on est déjà sur le MainActor.
            MainActor.assumeIsolated { self?.playNextInQueue() }
        }
        let player = player ?? AVPlayer()
        player.replaceCurrentItem(with: playerItem)
        self.player = player
        playing = .reciter(ayah: item.ayah)
        player.play()
    }

    // MARK: - Réécoute

    func playRecording(at url: URL) {
        stop()
        activateSession()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            recordingPlayer = player
            playing = .ownRecording
            player.play()
        } catch {
            logger.error("Réécoute impossible : \(error.localizedDescription)")
            playing = .none
        }
    }

    // MARK: - Arrêt

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        queue = []
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        recordingPlayer?.stop()
        recordingPlayer = nil
        playing = .none
    }

    private func activateSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            logger.error("Session audio : \(error.localizedDescription)")
        }
    }
}

extension RecitationAudioAdvisor: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if self.playing == .ownRecording { self.playing = .none }
        }
    }
}
