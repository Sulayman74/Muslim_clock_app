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

    init(reference: RecitationReference) {
        self.reference = reference
    }

    var hasResult: Bool { alignment != nil }

    /// Texte à lire pour « Écouter le conseil ».
    var adviceText: String {
        rephrasedAdvice ?? tips.map(\.textFr).joined(separator: " ")
    }

    // MARK: - Écoute

    func startListening() async {
        alignment = nil
        tips = []
        rephrasedAdvice = nil
        audio.stop()
        await transcriber.start()
    }

    func stopListening() async {
        await transcriber.stop()
        analyzeIfFinished()
    }

    /// Appelé quand le transcripteur termine seul (silence, plafond).
    func analyzeIfFinished() {
        guard transcriber.state == .finished, alignment == nil, let transcript = transcriber.transcript else { return }
        let result = RecitationAligner.align(reference: reference, transcript: transcript)
        alignment = result
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
        cancel()
        alignment = nil
        tips = []
        rephrasedAdvice = nil
        transcriber.acknowledge()
        guard let ayah, reference.ayahRange != ayah...ayah else { return }
        isLoadingReference = true
        defer { isLoadingReference = false }
        do {
            reference = try await RecitationReferenceLoader.load(riwaya: reference.riwaya, surah: reference.surah, ayahRange: ayah...ayah)
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
