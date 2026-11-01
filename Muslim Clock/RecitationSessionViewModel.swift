//
//  RecitationSessionViewModel.swift
//  Muslim Clock — Correcteur de récitation (phase 6)
//
//  Une séance : écoute → alignement → conseils → progression. Les vues ne
//  font qu'afficher. Le correcteur n'écrit JAMAIS dans le plan Coran, la
//  khatma ou le journal de lecture : uniquement `recitation_progress`.
//

import Foundation
import SwiftUI
import os

@MainActor
@Observable
final class RecitationSessionViewModel {

    private(set) var reference: RecitationReference
    let transcriber = RecitationTranscriber()
    let audio = RecitationAudioAdvisor()

    private(set) var alignment: RecitationAlignment?
    private(set) var tips: [CoachTip] = []
    /// Conseil reformulé par le modèle local, si disponible.
    private(set) var rephrasedAdvice: String?
    private(set) var isLoadingReference = false
    private(set) var loadError: String?
    /// Calibration par le récitateur en cours d'attente (après l'écoute).
    private(set) var isCalibrating = false
    /// Calibration appliquée au dernier résultat (pour l'afficher honnêtement).
    private(set) var calibration: RecitationCalibration = .none

    /// Phrase d'état de la calibration, affichée sous le résultat. `nil` quand
    /// il n'y a rien à dire (riwaya sans audio).
    var calibrationSummary: String? {
        switch calibration.status {
        case .notApplicable:
            return nil
        case .recognizerUnavailable:
            return String(localized: "Calibration sur le récitateur indisponible sur cet appareil : score non calibré.")
        case .failed:
            return String(localized: "Calibration sur le récitateur impossible (réseau ou audio) : score non calibré.")
        case .ready:
            var parts: [String] = []
            if !calibration.unusableAyahs.isEmpty {
                let list = calibration.unusableAyahs.sorted().map(String.init).joined(separator: ", ")
                parts.append(String(format: String(localized: "La reconnaissance échoue aussi sur le récitateur pour le(s) verset(s) %@ : non noté(s)."), list))
            }
            if !calibration.unjudgeable.isEmpty {
                parts.append(String(format: String(localized: "Calibré sur le récitateur : %lld mot(s) non vérifiable(s)."), calibration.unjudgeable.count))
            } else if calibration.unusableAyahs.isEmpty {
                parts.append(String(localized: "Calibré sur le récitateur."))
            }
            if !calibration.failedAyahs.isEmpty {
                let list = calibration.failedAyahs.sorted().map(String.init).joined(separator: ", ")
                parts.append(String(format: String(localized: "Verset(s) %@ non calibré(s) (réseau)."), list))
            }
            return parts.joined(separator: " ")
        }
    }

    /// Calibration par le récitateur (formes du moteur + mots non jugeables) —
    /// lancée en parallèle de l'écoute, attendue au moment de l'analyse.
    private var calibrationTask: Task<RecitationCalibration, Never>?

    /// Segments tajwid du texte de référence (affichage, Hafs uniquement).
    private(set) var tajweed: [Int: [TajweedRun]] = [:]

    /// Familles de règles présentes dans le passage (légende).
    var tajweedFamilies: [TajweedFamily] {
        Array(Set(tajweed.values.flatMap(\.families))).sorted()
    }

    /// Charge (ou recharge après un `retry`) les couleurs tajwid du passage.
    func loadTajweed() async {
        let reference = reference
        tajweed = await TajweedLoader.runs(riwaya: reference.riwaya, surah: reference.surah, ayahRange: reference.ayahRange)
    }

    init(reference: RecitationReference) {
        self.reference = reference
    }

    var hasResult: Bool { alignment != nil }

    // MARK: - Écoute

    func startListening() async {
        alignment = nil
        tips = []
        rephrasedAdvice = nil
        audio.stop()
        // La calibration tourne pendant que l'utilisateur récite : au stop,
        // elle est généralement déjà prête (cache après la première séance).
        startCalibrationIfNeeded()
        await RecitationTranscriber.logEngineCapabilities()
        // Les mots du passage servent d'indices au moteur (calibrage de l'écoute).
        await transcriber.start(hints: reference.recognitionHints)
    }

    private func startCalibrationIfNeeded() {
        guard calibrationTask == nil else { return }
        let reference = reference
        calibrationTask = Task { await RecitationCalibrator.calibration(for: reference) }
    }

    func stopListening() async {
        await transcriber.stop()
        await analyzeIfFinished()
    }

    /// Appelé quand le transcripteur termine seul (silence, plafond).
    func analyzeIfFinished() async {
        guard transcriber.state == .finished, alignment == nil, let transcript = transcriber.transcript else { return }
        isCalibrating = true
        let calibration = await calibrationTask?.value ?? .none
        isCalibrating = false
        // Re-vérifie après l'await : un retry/cancel a pu passer entre-temps.
        guard alignment == nil, transcriber.state == .finished else { return }

        self.calibration = calibration
        let result = RecitationAligner.align(reference: reference, transcript: transcript, calibration: calibration)
        alignment = result
        logAnalysis(transcript: transcript, result: result)
        tips = RecitationCoach.tips(for: result, reference: reference)

        var progress = RecitationProgressStore.load()
        progress.record(alignment: result, reference: reference)
        RecitationProgressStore.save(progress)
    }

    /// Reformulation optionnelle (Apple Intelligence local), lancée après le résultat.
    func rephraseAdvice(languageCode: String) async {
        guard let alignment, !alignment.isLowConfidence else { return }
        rephrasedAdvice = await RecitationCoachLLM.rephrase(tips: tips, languageCode: languageCode)
    }

    func cancel() {
        transcriber.cancel()
        audio.stop()
    }

    // MARK: - Debug console

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "RecitationSession")

    /// Trace de diagnostic (console Xcode) : moteur, texte entendu, calibration,
    /// verdict mot à mot. Pas de données personnelles au-delà de la récitation
    /// elle-même, qui ne quitte pas l'appareil.
    private func logAnalysis(transcript: RecitationTranscript, result: RecitationAlignment) {
        let heard = transcript.tokens.map(\.text).joined(separator: " ")
        let engine = transcriber.engine.map { "\($0)" } ?? "aucun"
        Self.logger.info("Séance \(self.reference.surah):\(self.reference.ayahRange.lowerBound)-\(self.reference.ayahRange.upperBound) — moteur \(engine, privacy: .public)")
        Self.logger.info("Entendu : \(heard, privacy: .public)")
        Self.logger.info("Calibration : \(String(describing: self.calibration.status), privacy: .public) — non vérifiables \(self.calibration.unjudgeable.count), formes récitateur \(self.calibration.reciterForms.count), versets inutilisables \(self.calibration.unusableAyahs.sorted(), privacy: .public), échecs \(self.calibration.failedAyahs.sorted(), privacy: .public)")
        let verdicts = result.items.map { item -> String in
            let reference = item.reference?.display ?? "∅"
            let heardText = item.heard?.text ?? "∅"
            return "\(reference)→\(heardText):\(item.kind.rawValue)"
        }.joined(separator: " | ")
        Self.logger.info("Verdicts : \(verdicts, privacy: .public)")
        Self.logger.info("Score \(Int((result.accuracy * 100).rounded()))% — confiance faible : \(result.isLowConfidence)")
    }

    // MARK: - Réessayer

    /// Verset le plus faible de la séance (le plus de mots non justes).
    var weakestAyah: Int? {
        guard let alignment, !alignment.isLowConfidence else { return nil }
        var misses: [Int: Int] = [:]
        for item in alignment.items {
            guard let ayah = item.reference?.ayah, item.kind != .matched else { continue }
            misses[ayah, default: 0] += 1
        }
        return misses.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
    }

    /// Recharge la référence sur un seul verset (ou sur toute la plage) et remet à zéro.
    func retry(ayah: Int? = nil) async {
        resetSession()
        guard let ayah, reference.ayahRange != ayah...ayah else { return }
        await load(surah: reference.surah, ayahRange: ayah...ayah)
    }

    // MARK: - Navigation entre sourates

    var hasPreviousSurah: Bool { reference.surah > 1 }
    var hasNextSurah: Bool { reference.surah < QuranConstants.totalChapters }

    /// Passe à la sourate voisine, depuis son premier verset : toute la sourate
    /// si elle tient dans une séance (cas des sourates courtes), sinon les
    /// `maxAyahsPerSession` premiers versets.
    func moveToSurah(_ surah: Int) async {
        guard (1...QuranConstants.totalChapters).contains(surah) else { return }
        resetSession()
        isLoadingReference = true
        defer { isLoadingReference = false }
        guard let count = await RecitationReferenceLoader.ayahCount(surah: surah, riwaya: reference.riwaya) else {
            loadError = RecitationReferenceError.surahNotFound(surah).localizedDescription
            return
        }
        await load(surah: surah, ayahRange: 1...min(count, RecitationReferenceLoader.maxAyahsPerSession))
    }

    /// Abandonne l'écoute et le résultat en cours (nouvelle référence à venir).
    private func resetSession() {
        cancel()
        alignment = nil
        tips = []
        rephrasedAdvice = nil
        transcriber.acknowledge()
    }

    private func load(surah: Int, ayahRange: ClosedRange<Int>) async {
        isLoadingReference = true
        defer { isLoadingReference = false }
        do {
            reference = try await RecitationReferenceLoader.load(riwaya: reference.riwaya, surah: surah, ayahRange: ayahRange)
            // La référence a changé : la calibration sera relancée (cache chaud).
            calibrationTask?.cancel()
            calibrationTask = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    // MARK: - Récitateur de référence

    /// Pistes du récitateur pour la plage (Hafs uniquement), dans l'ordre.
    func reciterTracks(only ayah: Int? = nil) async -> [(ayah: Int, url: URL)] {
        guard reference.riwaya == .hafs else { return [] }
        var offset = 0
        for surah in 1..<reference.surah {
            offset += await RecitationReferenceLoader.ayahCount(surah: surah, riwaya: .hafs) ?? 0
        }
        let ayahs = ayah.map { [$0] } ?? Array(reference.ayahRange)
        return ayahs.compactMap { a in
            RecitationAudioAdvisor.reciterURL(riwaya: .hafs, globalAyahNumber: offset + a).map { (a, $0) }
        }
    }

    var hasReferenceReciter: Bool { reference.riwaya == .hafs }
}
