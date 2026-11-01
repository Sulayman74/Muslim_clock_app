//
//  RecitationCalibrator.swift
//  Muslim Clock — Correcteur de récitation, calibration par le récitateur
//
//  Idée : faire passer l'audio du récitateur de référence (récitation PARFAITE)
//  dans le MÊME moteur de reconnaissance on-device que l'écoute live, et
//  aligner ce qu'il entend sur le texte. Pour chaque mot du verset :
//  - le moteur l'entend tel quel → rien à faire ;
//  - il le rend différemment mais de façon reconnaissable
//    (« وأصلحوا » → « واصلح », « فاتقوا » → « فتق ») → cette forme devient une
//    graphie JUSTE à cette position : un utilisateur dont le moteur produit la
//    même chose a récité comme le récitateur ;
//  - il le rate (omis, ou remplacé par un autre mot) → NON VÉRIFIABLE.
//  Si le moteur rate plus de la moitié d'un verset du récitateur, il n'y
//  entend rien de fiable : le verset entier devient non vérifiable (plutôt
//  que d'afficher des erreurs rouges qu'on ne peut pas imputer à l'élève).
//
//  Règles :
//  - la calibration ne sert qu'à PARDONNER, jamais à détecter ;
//  - Hafs uniquement (seule riwaya avec audio par verset) ; tout est on-device,
//    seul le téléchargement du MP3 passe par le réseau (déjà le cas du bouton
//    « Écouter le récitateur »), mis en cache par AudioCacheManager ;
//  - résultat mis en cache par verset, estampillé par la version d'OS (le
//    modèle de reconnaissance change avec les mises à jour système) ;
//  - l'issue (calibré / inutilisable / échec) est remontée à l'UI.
//

import Foundation
import AVFoundation
import Speech
import os

/// Calibration d'UN verset, telle que persistée.
nonisolated struct AyahCalibrationRecord: Codable, Equatable, Sendable {
    /// Indices des mots ratés par le moteur sur l'audio parfait.
    var missed: [Int]
    /// Indice (en chaîne, contrainte JSON) → forme normalisée que le moteur
    /// produit pour ce mot sur le récitateur, quand elle diffère de la référence.
    var forms: [String: String]
    /// Le moteur rate plus de `maxForgivableRatio` des mots : verset non notable.
    var unusable: Bool
}

@MainActor
enum RecitationCalibrator {

    /// `_v3` : format avec `unusable` et transcription par le moteur live.
    static let storageKey = "recitation_calibration_v3"
    /// Au-delà de cette part de mots ratés sur l'audio parfait, le moteur est
    /// jugé inutilisable sur ce verset.
    nonisolated static let maxForgivableRatio = 0.5
    /// Budget max par verset (téléchargement + transcription du MP3).
    static let perAyahTimeout: TimeInterval = 30

    private static let logger = Logger(subsystem: "kappsi.Muslim-Clock", category: "RecitationCalibrator")

    // MARK: - API

    /// Calibration du passage. Le `status` dit ce qui a été possible ; sans
    /// calibration, le correcteur fonctionne comme avant, simplement plus strict.
    static func calibration(for reference: RecitationReference) async -> RecitationCalibration {
        var result = RecitationCalibration()
        guard reference.riwaya == .hafs else {
            result.status = .notApplicable
            return result
        }
        guard await RecitationTranscriber.availableEngine() != nil else {
            result.status = .recognizerUnavailable
            logger.notice("Calibration impossible : aucune reconnaissance arabe locale.")
            return result
        }

        var cache = loadCache()
        var cacheChanged = false
        var calibratedCount = 0

        for ayah in reference.ayahRange {
            let key = cacheKey(reference: reference, ayah: ayah)
            let record: AyahCalibrationRecord
            if let stored = cache[key] {
                record = stored
            } else {
                guard let computed = await withTimeout(seconds: perAyahTimeout, operation: {
                    await calibrate(reference: reference, ayah: ayah)
                }) ?? nil else {
                    // Échec ou délai : pas de pardon, pas de cache, mais on le dit.
                    result.failedAyahs.insert(ayah)
                    logger.notice("Calibration \(reference.surah):\(ayah) : échec (réseau, audio ou délai).")
                    continue
                }
                cache[key] = computed
                cacheChanged = true
                record = computed
            }
            calibratedCount += 1
            result.merge(record, ayah: ayah)
            logger.notice("Calibration \(reference.surah):\(ayah) : \(record.unusable ? "moteur inutilisable" : "\(record.missed.count) raté(s), \(record.forms.count) forme(s)").")
        }
        if cacheChanged { save(cache) }
        result.status = calibratedCount > 0 ? .ready : .failed
        return result
    }

    /// Compat : seuls les mots non jugeables.
    static func unjudgeableWords(for reference: RecitationReference) async -> Set<AyahWordKey> {
        await calibration(for: reference).unjudgeable
    }

    // MARK: - Décision (pure, testée)

    /// Déduit la calibration d'un verset de l'alignement « récitateur vs texte ».
    ///
    /// - `matched` → rien ; `approximate` → la forme entendue devient juste à
    ///   cette position ; `omitted`/`substituted` → non vérifiable.
    /// - Si plus de `maxForgivableRatio` des mots sont ratés : `unusable`, et
    ///   rien d'autre (le verset entier sera non vérifiable).
    nonisolated static func record(from alignment: RecitationAlignment, wordCount: Int) -> AyahCalibrationRecord {
        var missed: [Int] = []
        var forms: [String: String] = [:]
        for item in alignment.items {
            guard let reference = item.reference else { continue }
            switch item.kind {
            case .matched, .unverifiable, .inserted, .repeated:
                continue
            case .approximate:
                if let heard = item.heard, heard.normalized != reference.normalized {
                    forms[String(reference.index)] = heard.normalized
                }
            case .omitted, .substituted:
                missed.append(reference.index)
            }
        }
        guard wordCount > 0, Double(missed.count) / Double(wordCount) <= maxForgivableRatio else {
            return AyahCalibrationRecord(missed: [], forms: [:], unusable: true)
        }
        return AyahCalibrationRecord(missed: missed.sorted(), forms: forms, unusable: false)
    }

    // MARK: - Calibration d'un verset

    /// `nil` si la calibration n'a pas pu être faite (réseau, audio, reconnaissance).
    private static func calibrate(reference: RecitationReference, ayah: Int) async -> AyahCalibrationRecord? {
        guard let text = reference.ayahTexts[ayah],
              let global = await RecitationReferenceLoader.globalAyahNumber(
                  riwaya: reference.riwaya, surah: reference.surah, ayah: ayah),
              let remote = RecitationAudioAdvisor.reciterURL(riwaya: reference.riwaya, globalAyahNumber: global) else {
            return nil
        }

        let cacheManager = AudioCacheManager.shared
        await cacheManager.downloadIfNeeded(remote)
        guard cacheManager.isCached(remote) else {
            logger.notice("Calibration \(reference.surah):\(ayah) : MP3 du récitateur indisponible.")
            return nil
        }
        let fileURL = cacheManager.localURL(for: remote)

        let ayahReference = RecitationReferenceLoader.makeReference(
            riwaya: reference.riwaya, surah: reference.surah, ayahTexts: [ayah: text])
        guard let transcript = await transcribeFile(at: fileURL, hints: ayahReference.recognitionHints) else {
            logger.notice("Calibration \(reference.surah):\(ayah) : transcription du MP3 impossible.")
            return nil
        }
        logger.info("Calibration \(reference.surah):\(ayah) — entendu chez le récitateur : \(transcript.tokens.map(\.text).joined(separator: " "), privacy: .public)")

        let alignment = RecitationAligner.align(reference: ayahReference, transcript: transcript)
        return record(from: alignment, wordCount: ayahReference.words.count)
    }

    // MARK: - Transcription d'un fichier (même moteur que l'écoute live)

    private static func transcribeFile(at url: URL, hints: [String]) async -> RecitationTranscript? {
        if let transcript = await transcribeWithAnalyzer(url: url, hints: hints) {
            return transcript
        }
        return await transcribeWithLegacyRecognizer(url: url, hints: hints)
    }

    /// `SpeechAnalyzer` + `DictationTranscriber` sur fichier — exactement le
    /// moteur de l'écoute live, donc les mêmes « surdités ».
    private static func transcribeWithAnalyzer(url: URL, hints: [String]) async -> RecitationTranscript? {
        guard await DictationTranscriber.supportedLocale(equivalentTo: RecitationTranscriber.locale) != nil else {
            return nil
        }
        let transcriber = DictationTranscriber(
            locale: RecitationTranscriber.locale,
            contentHints: [],
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
            let analyzer = SpeechAnalyzer(modules: [transcriber])
            if !hints.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = hints
                try await analyzer.setContext(context)
            }
            // Collecte des résultats finaux ; le flux se termine avec l'analyse.
            let collector = Task { () -> [String] in
                var texts: [String] = []
                do {
                    for try await result in transcriber.results where result.isFinal {
                        texts.append(String(result.text.characters))
                    }
                } catch {
                    logger.notice("Résultats SpeechAnalyzer (fichier) : \(error.localizedDescription, privacy: .public)")
                }
                return texts
            }
            let file = try AVAudioFile(forReading: url)
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                // Fichier vide : rien à analyser, on clôt proprement.
                await analyzer.cancelAndFinishNow()
            }
            let texts = await collector.value
            return .fromPlainText(texts.joined(separator: " "))
        } catch {
            logger.notice("SpeechAnalyzer sur fichier impossible : \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Repli : `SFSpeechRecognizer` on-device (mêmes modèles de base).
    private static func transcribeWithLegacyRecognizer(url: URL, hints: [String]) async -> RecitationTranscript? {
        guard let recognizer = SFSpeechRecognizer(locale: RecitationTranscriber.locale),
              recognizer.supportsOnDeviceRecognition else { return nil }
        let request = SFSpeechURLRecognitionRequest(url: url)
        // Règle privacy NON NÉGOCIABLE : jamais de reconnaissance serveur.
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.contextualStrings = hints

        return await withCheckedContinuation { continuation in
            var task: SFSpeechRecognitionTask?
            nonisolated(unsafe) var resumed = false
            task = recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let result, result.isFinal {
                    resumed = true
                    continuation.resume(returning: .fromPlainText(result.bestTranscription.formattedString))
                } else if error != nil {
                    resumed = true
                    task?.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Cache (UserDefaults, par verset, estampillé version d'OS)

    private static func cacheKey(reference: RecitationReference, ayah: Int) -> String {
        "\(engineStamp)|\(reference.riwaya.rawValue):\(reference.surah):\(ayah)"
    }

    /// Le modèle de reconnaissance évolue avec l'OS : une calibration faite
    /// sous une autre version n'est plus valable.
    private static var engineStamp: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion)"
    }

    private static func loadCache() -> [String: AyahCalibrationRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let cache = try? JSONDecoder().decode([String: AyahCalibrationRecord].self, from: data) else { return [:] }
        // Purge des entrées d'anciennes versions d'OS (clé préfixée).
        return cache.filter { $0.key.hasPrefix("\(engineStamp)|") }
    }

    private static func save(_ cache: [String: AyahCalibrationRecord]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Timeout

    /// Exécute `operation` avec une échéance. `nil` (externe) si le délai expire.
    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @MainActor () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

extension RecitationCalibration {
    /// Intègre l'enregistrement d'un verset.
    nonisolated mutating func merge(_ record: AyahCalibrationRecord, ayah: Int) {
        if record.unusable {
            unusableAyahs.insert(ayah)
            return
        }
        for index in record.missed { unjudgeable.insert(AyahWordKey(ayah: ayah, index: index)) }
        for (indexString, form) in record.forms {
            guard let index = Int(indexString) else { continue }
            reciterForms[AyahWordKey(ayah: ayah, index: index)] = form
        }
    }
}
