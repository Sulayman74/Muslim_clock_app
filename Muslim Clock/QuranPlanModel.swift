//
//  QuranPlan.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Modèle persisté dans UserDefaults (Codable). Singleton du plan courant.
//  Cf. AUDIT_QURAN_PLAN.md §2.1 pour la justification SwiftData vs UserDefaults.
//

import Foundation

/// Type d'objectif choisi par l'utilisateur lors de la création du plan.
enum PlanGoalType: String, Codable, CaseIterable, Identifiable {
    case byDuration   // L'utilisateur fixe une durée en jours
    case byPages      // L'utilisateur fixe un nombre total de pages
    case byDate       // L'utilisateur fixe une date cible

    var id: String { rawValue }

    var label: String {
        switch self {
        case .byDuration: return String(localized: "Par durée")
        case .byPages:    return String(localized: "Par pages")
        case .byDate:     return String(localized: "Par date cible")
        }
    }
}

/// Plan de lecture courant.
///
/// Stocké dans UserDefaults via clé `quranPlan` (encodage JSON).
/// Un seul plan actif à la fois — le passé est tracé via `ReadingEntry` SwiftData.
struct QuranPlan: Codable, Equatable, Identifiable {

    var id: UUID
    var goalType: PlanGoalType
    /// Valeur de l'objectif. Interprétation selon `goalType` :
    /// - `.byDuration` → nombre de jours (Int dans Double)
    /// - `.byPages` → nombre total de pages à lire (Int dans Double)
    /// - `.byDate` → timestamp Unix de la date cible (`.timeIntervalSince1970`)
    var goalValue: Double
    var startDate: Date
    /// Page de départ dans le Mushaf Madinah (1...604).
    var startPage: Int
    /// Page d'arrivée (1...604, ≥ startPage).
    var endPage: Int
    /// Sous-ensemble des 5 prières qui déclencheront un rappel de lecture.
    var prayersToUse: Set<String>
    /// Si vrai, `QuranReminderScheduler` programme des notifs post-prière.
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        goalType: PlanGoalType,
        goalValue: Double,
        startDate: Date = .now,
        startPage: Int = 1,
        endPage: Int = 604,
        prayersToUse: Set<String> = Self.allPrayers,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.goalType = goalType
        self.goalValue = goalValue
        self.startDate = startDate
        self.startPage = max(1, min(604, startPage))
        self.endPage = max(self.startPage, min(604, endPage))
        self.prayersToUse = prayersToUse
        self.notificationsEnabled = notificationsEnabled
    }

    /// Nom canonique des 5 prières (aligné avec `PrayerTimesViewModel.dailyPrayers`).
    static let allPrayers: Set<String> = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
}

// MARK: - Presets indicatifs

/// Presets de rythme pour pré-remplir le formulaire de création.
/// Calculs basés sur 604 pages (Mushaf Madinah complet).
enum QuranPlanPreset: String, CaseIterable, Identifiable {
    case oneJuzPerDay        // ~30 jours, 1 juz/jour ≈ 20 pages
    case halfJuzPerDay       // ~60 jours, ½ juz/jour ≈ 10 pages
    case quarterJuzPerDay    // ~120 jours, ¼ juz/jour ≈ 5 pages
    case ramadanKhatma       // 29-30 jours pour terminer dans Ramadan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneJuzPerDay:     return String(localized: "1 Juz / jour (≈ 1 mois)")
        case .halfJuzPerDay:    return String(localized: "½ Juz / jour (≈ 2 mois)")
        case .quarterJuzPerDay: return String(localized: "¼ Juz / jour (≈ 4 mois)")
        case .ramadanKhatma:    return String(localized: "Khatma de Ramadan (~30 jours)")
        }
    }

    /// Durée indicative en jours pour terminer le Mushaf complet.
    var defaultDurationDays: Int {
        switch self {
        case .oneJuzPerDay:     return 30
        case .halfJuzPerDay:    return 60
        case .quarterJuzPerDay: return 120
        case .ramadanKhatma:    return 30
        }
    }

    /// Crée un `QuranPlan` Codable pré-rempli à partir du preset.
    func makePlan(startingFrom startDate: Date = .now) -> QuranPlan {
        QuranPlan(
            goalType: .byDuration,
            goalValue: Double(defaultDurationDays),
            startDate: startDate
        )
    }
}

// MARK: - Persistence

/// Helper de lecture/écriture du plan courant dans UserDefaults.
enum QuranPlanStorage {
    private static let key = "quranPlan"

    static func load() -> QuranPlan? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(QuranPlan.self, from: data)
    }

    static func save(_ plan: QuranPlan) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
