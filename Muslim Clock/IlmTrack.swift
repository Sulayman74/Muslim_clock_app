//
//  IlmTrack.swift
//  Muslim Clock — module Programme ʿIlm (apprentissage des mutūn)
//
//  Modèles Codable : contenu bundlé (tracks/leçons) + progression + plan actif.
//  Persistance UserDefaults uniquement (cf. AUDIT_ILM_PROGRAM.md §D3 — pas de SwiftData :
//  la progression est bornée par le contenu, ~70 leçons à vie).
//

import Foundation

// MARK: - Contenu (bundlé, immuable)

/// Un texte à étudier (les 3 Fondements, les 4 Règles, les 40 Nawawi).
///
/// Chargé depuis `ilm_tracks.json` par `IlmContentLoader`. Ajouter un parcours
/// = ajouter du JSON, zéro code (extension par la donnée, cf. AUDIT §D2).
struct IlmTrack: Codable, Identifiable, Equatable {
    /// Identifiant stable ("usul3", "qawaid4", "nawawi40") — clé de progression.
    let id: String
    let title: String
    let titleArabic: String
    let author: String
    /// Leçons ordonnées — l'ordre du tableau EST l'ordre canonique d'étude.
    let lessons: [IlmLesson]
}

/// Une leçon : l'unité de progression (équivalent « page Madinah » de la Khatma).
struct IlmLesson: Codable, Identifiable, Equatable {
    /// Unique global, stable (ex: "nawawi40_07") — clé du dictionnaire de progression.
    let id: String
    let title: String
    /// Texte arabe canonique — support principal de mémorisation.
    let arabic: String
    /// Traduction française.
    let text: String
    /// Référence (hadith) — `nil` pour les passages de matn sans hadith cité.
    let source: String?
    /// Note pédagogique ou degré d'authenticité — `nil` si rien à signaler.
    let note: String?
}

// MARK: - Progression (UserDefaults)

/// Progression globale, tous parcours confondus : leçon acquise → date d'acquisition,
/// plus l'état de révision espacée (boîtes de Leitner).
///
/// Dictionnaires à clé `IlmLesson.id` → tous les accès sont O(1). La taille est
/// bornée par le contenu bundlé (~70 entrées max), jamais par le temps d'usage.
struct IlmProgress: Codable, Equatable {
    var completedAt: [String: Date] = [:]

    // MARK: Révision espacée (Leitner)

    /// Boîte de Leitner courante de la leçon (1...5). Présente ⇔ leçon en révision.
    var reviewBox: [String: Int] = [:]
    /// Prochaine date de révision due (normalisée : startOfDay + intervalle de la boîte).
    var nextReviewAt: [String: Date] = [:]

    /// Intervalles en jours par boîte (index = boîte − 1) : 1j → 3j → 7j → 14j → 30j.
    static let leitnerIntervalsDays = [1, 3, 7, 14, 30]
    static var maxBox: Int { leitnerIntervalsDays.count }

    // Décodage tolérant : les champs de révision peuvent manquer dans un ilm_progress
    // persisté par une version antérieure — on ne perd jamais completedAt pour autant.
    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedAt = try container.decodeIfPresent([String: Date].self, forKey: .completedAt) ?? [:]
        reviewBox = try container.decodeIfPresent([String: Int].self, forKey: .reviewBox) ?? [:]
        nextReviewAt = try container.decodeIfPresent([String: Date].self, forKey: .nextReviewAt) ?? [:]
    }

    // MARK: Acquisition

    func isCompleted(_ lessonID: String) -> Bool {
        completedAt[lessonID] != nil
    }

    /// Marque la leçon acquise ET l'inscrit en révision (boîte 1, due demain).
    mutating func complete(_ lessonID: String, on date: Date = .now) {
        completedAt[lessonID] = date
        reviewBox[lessonID] = 1
        nextReviewAt[lessonID] = Self.reviewDate(box: 1, from: date)
    }

    /// Décoche la leçon et la sort du cycle de révision.
    mutating func uncomplete(_ lessonID: String) {
        completedAt.removeValue(forKey: lessonID)
        reviewBox.removeValue(forKey: lessonID)
        nextReviewAt.removeValue(forKey: lessonID)
    }

    // MARK: Révision

    /// Une carte est « due » si sa date de révision est atteinte.
    func isDue(_ lessonID: String, now: Date = .now) -> Bool {
        guard let next = nextReviewAt[lessonID] else { return false }
        return next <= now
    }

    /// Applique le résultat d'une révision (transition Leitner) :
    /// su → boîte suivante · presque → même boîte · oublié → retour boîte 1.
    mutating func gradeReview(_ lessonID: String, outcome: IlmReviewOutcome, on date: Date = .now) {
        let current = reviewBox[lessonID] ?? 1
        let newBox: Int
        switch outcome {
        case .known:  newBox = min(Self.maxBox, current + 1)
        case .almost: newBox = current
        case .forgot: newBox = 1
        }
        reviewBox[lessonID] = newBox
        nextReviewAt[lessonID] = Self.reviewDate(box: newBox, from: date)
    }

    /// Prochaine échéance : startOfDay(date) + intervalle de la boîte.
    private static func reviewDate(box: Int, from date: Date) -> Date {
        let cal = Calendar.current
        let days = leitnerIntervalsDays[max(1, min(maxBox, box)) - 1]
        return cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: date)) ?? date
    }
}

/// Résultat d'auto-évaluation d'une flash card.
enum IlmReviewOutcome {
    case known   // « Je savais » — la carte monte d'une boîte
    case almost  // « Presque » — reste dans sa boîte
    case forgot  // « À revoir » — retour boîte 1 (sans culpabilisation : c'est le système)
}

// MARK: - Plan actif (UserDefaults)

/// Programme en cours : quel parcours, quel rythme, quel rappel quotidien.
/// Un seul plan actif à la fois (miroir de `QuranPlan`) ; la progression, elle,
/// est conservée par parcours dans `IlmProgress`.
struct IlmPlan: Codable, Equatable {
    var trackID: String
    var startDate: Date
    /// Rythme visé (1...14 leçons/semaine).
    var lessonsPerWeek: Int
    var reminderEnabled: Bool
    /// Heure locale du rappel quotidien (défaut 20h — après Maghrib/Isha selon saison).
    var reminderHour: Int
    var reminderMinute: Int

    init(
        trackID: String,
        startDate: Date = .now,
        lessonsPerWeek: Int = 7,
        reminderEnabled: Bool = true,
        reminderHour: Int = 20,
        reminderMinute: Int = 0
    ) {
        self.trackID = trackID
        self.startDate = startDate
        self.lessonsPerWeek = max(1, min(14, lessonsPerWeek))
        self.reminderEnabled = reminderEnabled
        self.reminderHour = max(0, min(23, reminderHour))
        self.reminderMinute = max(0, min(59, reminderMinute))
    }
}

// MARK: - Presets de rythme (UI helper — miroir QuranPlanPreset)

enum IlmPlanPreset: String, CaseIterable, Identifiable {
    case oneLessonPerDay
    case oneEveryTwoDays
    case threePerWeek
    case oneLessonPerWeek

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneLessonPerDay:  return String(localized: "1 leçon / jour")
        case .oneEveryTwoDays:  return String(localized: "1 leçon tous les 2 jours")
        case .threePerWeek:     return String(localized: "3 leçons / semaine")
        case .oneLessonPerWeek: return String(localized: "1 leçon / semaine (mémorisation profonde)")
        }
    }

    var lessonsPerWeek: Int {
        switch self {
        case .oneLessonPerDay:  return 7
        case .oneEveryTwoDays:  return 4
        case .threePerWeek:     return 3
        case .oneLessonPerWeek: return 1
        }
    }
}

// MARK: - Persistence

/// Lecture/écriture du plan et de la progression dans UserDefaults (pattern `QuranPlanStorage`).
enum IlmStorage {
    private static let planKey = "ilm_plan"
    private static let progressKey = "ilm_progress"

    static func loadPlan() -> IlmPlan? {
        guard let data = UserDefaults.standard.data(forKey: planKey) else { return nil }
        return try? JSONDecoder().decode(IlmPlan.self, from: data)
    }

    static func save(_ plan: IlmPlan) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: planKey)
    }

    static func clearPlan() {
        UserDefaults.standard.removeObject(forKey: planKey)
    }

    static func loadProgress() -> IlmProgress {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let progress = try? JSONDecoder().decode(IlmProgress.self, from: data) else {
            return IlmProgress()
        }
        return progress
    }

    static func save(_ progress: IlmProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: progressKey)
    }
}
