//
//  SmartSetupAnalyzer.swift
//  Muslim Clock
//
//  « Configuration Magique » — l'observation (horaires de la mosquée un jour
//  donné, à une position donnée) est la donnée de référence, persistée telle
//  quelle. Tout le reste (méthode, offsets, mode Isha) en est DÉRIVÉ, pour
//  n'importe quelle méthode choisie par l'utilisateur : changer d'angle après
//  l'analyse recalcule les offsets au lieu de les laisser calés sur l'ancien.
//

import Foundation
import Adhan

// MARK: - Observation

/// Horaires d'adhan relevés dans la mosquée (Mawaqit, affichage…) un jour donné.
/// `nonisolated` : type de domaine pur (comparé/encodé hors MainActor, tests inclus).
nonisolated struct MosqueObservation: Codable, Equatable {
    var date: Date
    var latitude: Double
    var longitude: Double
    var fajr: Date
    var dhuhr: Date
    var asr: Date
    var maghrib: Date
    var isha: Date

    static func load(from defaults: UserDefaults = .standard) -> MosqueObservation? {
        guard let data = defaults.data(forKey: StorageKeys.smartSetupObservation) else { return nil }
        do {
            return try JSONDecoder().decode(MosqueObservation.self, from: data)
        } catch {
            print("⚠️ [SmartSetup] Observation illisible, ignorée : \(error.localizedDescription)")
            return nil
        }
    }

    func save(to defaults: UserDefaults = .standard) {
        do {
            defaults.set(try JSONEncoder().encode(self), forKey: StorageKeys.smartSetupObservation)
        } catch {
            print("⚠️ [SmartSetup] Observation non sauvegardée : \(error.localizedDescription)")
        }
    }
}

// MARK: - Proposition

/// Une méthode candidate évaluée contre l'observation.
struct MethodCandidate: Identifiable, Equatable {
    let name: String
    let fajrAngle: Double
    /// Écarts bruts `mosquée − calcul` (min), avant bornage.
    let fajrOffset: Int
    let ishaOffset: Int
    /// `false` si l'angle n'est pas atteint ce jour-là (été, latitude élevée) :
    /// Adhan a substitué une règle de haute latitude, les écarts n'ont pas de sens.
    let isReachable: Bool
    let score: Int

    var id: String { name }
}

/// Réglages prêts à être appliqués pour une méthode donnée.
struct AppliedSettings: Equatable {
    let method: String
    let fajrOffset: Int
    let dhuhrOffset: Int
    let asrOffset: Int
    let maghribOffset: Int
    let ishaMode: SmartSetupMath.IshaMode
    /// Avertissements spécifiques à cette méthode (bornages Fajr/Isha, Isha incertaine).
    let warnings: [String]
}

/// Résultat de l'analyse d'une observation : candidats scorés, recommandation,
/// offsets indépendants de l'angle, et dérivation des réglages pour tout choix.
struct SmartSetupProposal: Equatable {
    let observation: MosqueObservation
    let candidates: [MethodCandidate]
    let recommendedMethod: String
    let dhuhrOffset: Int
    let asrOffset: Int
    let maghribOffset: Int
    /// Écart saisi Maghrib → Isha (min).
    let maghribToIsha: Int
    /// Avertissements indépendants de la méthode (bornages Dhuhr/Asr/Maghrib).
    let warnings: [String]

    func candidate(named name: String) -> MethodCandidate? {
        candidates.first { $0.name == name }
    }

    /// Réglages à appliquer pour `method` (recommandée ou choisie par l'utilisateur).
    func settings(for method: String) -> AppliedSettings {
        let normalized = PrayerCalculationEngine.normalizedMethod(method)
        let candidate = candidate(named: normalized) ?? candidate(named: recommendedMethod) ?? candidates[0]
        var warnings: [String] = []

        let fajr = SmartSetupMath.clamped(candidate.fajrOffset, to: SmartSetupMath.fajrOffsetRange)
        if fajr.wasClamped {
            warnings.append(SmartSetupAnalyzer.clampWarning("Fajr", raw: candidate.fajrOffset, kept: fajr.value))
        }

        let isha = SmartSetupMath.ishaMode(maghribToIsha: maghribToIsha, astronomicalOffset: candidate.ishaOffset)
        if isha.isUncertain, case .fixed(let duration) = isha.mode {
            warnings.append(String(localized: "ℹ️ Isha : écart Maghrib → Isha de \(maghribToIsha) min, arrondi à un intervalle fixe de \(duration) min. Vérifiez sur quelques jours."))
        }
        if case .astronomical(let offset) = isha.mode, offset != candidate.ishaOffset {
            warnings.append(SmartSetupAnalyzer.clampWarning("Isha", raw: candidate.ishaOffset, kept: offset))
        }
        if !candidate.isReachable {
            warnings.append(String(localized: "⚠️ \(candidate.name) : angle non atteint à cette date et cette latitude, les écarts Fajr/Isha ne sont pas fiables."))
        }

        return AppliedSettings(
            method: candidate.name,
            fajrOffset: fajr.value,
            dhuhrOffset: dhuhrOffset,
            asrOffset: asrOffset,
            maghribOffset: maghribOffset,
            ishaMode: isha.mode,
            warnings: warnings
        )
    }
}

// MARK: - Analyse

enum SmartSetupAnalyzer {

    /// Analyse une observation : offsets indépendants de l'angle, écarts Fajr/Isha
    /// par méthode classique, faisabilité des angles, recommandation (score
    /// conjoint + préférence régionale).
    ///
    /// - Returns: `nil` si Adhan ne peut pas calculer (coordonnées invalides).
    static func analyze(_ observation: MosqueObservation, calendar: Calendar = .current) -> SmartSetupProposal? {
        let coordinates = Coordinates(latitude: observation.latitude, longitude: observation.longitude)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: observation.date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: observation.date) ?? 1

        // 1. Dhuhr / Asr / Maghrib : indépendants de l'angle → méthode de référence.
        guard let base = PrayerTimes(
            coordinates: coordinates, date: dateComponents,
            calculationParameters: zeroOffsetParameters(method: SmartSetupMath.referenceMethod)
        ) else { return nil }

        var warnings: [String] = []
        func minorOffset(_ label: String, calc: Date, user: Date, hanafiHint: Bool = false) -> Int {
            let raw = minutesBetween(calculated: calc, user: user, calendar: calendar)
            let bounded = SmartSetupMath.clamped(raw, to: SmartSetupMath.minorOffsetRange)
            if bounded.wasClamped {
                var text = clampWarning(label, raw: raw, kept: bounded.value)
                if hanafiHint {
                    text += " " + String(localized: "Un grand écart sur Asr peut indiquer une mosquée de rite Hanafi.")
                }
                warnings.append(text)
            }
            return bounded.value
        }
        let dhuhrOffset = minorOffset("Dhuhr", calc: base.dhuhr, user: observation.dhuhr)
        let asrOffset = minorOffset("Asr", calc: base.asr, user: observation.asr, hanafiHint: true)
        let maghribOffset = minorOffset("Maghrib", calc: base.maghrib, user: observation.maghrib)

        // 2. Isha fixe ou astronomique ? L'écart saisi sert au scoring : si l'Isha
        //    est manifestement un lissage, elle ne dit rien sur l'angle.
        let maghribToIsha = minutesBetween(calculated: observation.maghrib, user: observation.isha, calendar: calendar)
        let ishaLooksFixed = SmartSetupMath.isFixedIsha(maghribToIsha)

        // 3. Candidats : écarts Fajr / Isha par méthode, faisabilité, score conjoint.
        var candidates: [MethodCandidate] = []
        for (name, angle) in SmartSetupMath.candidateMethods {
            guard let times = PrayerTimes(
                coordinates: coordinates, date: dateComponents,
                calculationParameters: zeroOffsetParameters(method: name)
            ) else { continue }

            let fajrOffset = minutesBetween(calculated: times.fajr, user: observation.fajr, calendar: calendar)
            let ishaOffset = minutesBetween(calculated: times.isha, user: observation.isha, calendar: calendar)
            let reachable = SmartSetupMath.isTwilightAngleReachable(
                angle: angle, latitude: observation.latitude, dayOfYear: dayOfYear
            )
            // Isha participe au score seulement si elle est astronomique OU si elle
            // colle à l'angle (une mosquée « fixe à 90 » dont l'Isha tombe sur l'angle
            // suit en réalité l'angle).
            let ishaInformative = !ishaLooksFixed || abs(ishaOffset) <= SmartSetupMath.ishaAngleMatchTolerance
            let score = SmartSetupMath.jointScore(fajrOffset: fajrOffset, ishaOffset: ishaInformative ? ishaOffset : nil)

            candidates.append(MethodCandidate(
                name: name, fajrAngle: angle,
                fajrOffset: fajrOffset, ishaOffset: ishaOffset,
                isReachable: reachable, score: score
            ))
        }
        guard !candidates.isEmpty else { return nil }

        let recommended = SmartSetupMath.bestMethod(
            candidates.map { (name: $0.name, score: $0.score, isReliable: $0.isReachable) },
            preferenceOrder: SmartSetupMath.preferenceOrder(latitude: observation.latitude, longitude: observation.longitude)
        )

        return SmartSetupProposal(
            observation: observation,
            candidates: candidates,
            recommendedMethod: recommended,
            dhuhrOffset: dhuhrOffset,
            asrOffset: asrOffset,
            maghribOffset: maghribOffset,
            maghribToIsha: maghribToIsha,
            warnings: warnings
        )
    }

    // MARK: - Helpers

    /// Paramètres Adhan d'une méthode SANS offsets : exactement ceux que le moteur
    /// appliquera ensuite (`PrayerCalculationEngine.parameters`), pour que l'écart
    /// mesuré soit l'offset réellement nécessaire — aucune construction parallèle.
    static func zeroOffsetParameters(method: String) -> CalculationParameters {
        PrayerCalculationEngine.parameters(
            method: method,
            fajrOffset: 0, dhuhrOffset: 0, asrOffset: 0, maghribOffset: 0, ishaOffset: 0,
            isIshaFixed: false, ishaFixedDuration: 0
        )
    }

    /// Adaptateur Date → (heure, minute) vers `SmartSetupMath.minutesBetween`.
    static func minutesBetween(calculated: Date, user: Date, calendar: Calendar) -> Int {
        let calc = calendar.dateComponents([.hour, .minute], from: calculated)
        let usr = calendar.dateComponents([.hour, .minute], from: user)
        return SmartSetupMath.minutesBetween(
            calc: (calc.hour ?? 0, calc.minute ?? 0),
            user: (usr.hour ?? 0, usr.minute ?? 0)
        )
    }

    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    static func clampWarning(_ prayer: String, raw: Int, kept: Int) -> String {
        String(localized: "⚠️ \(prayer) : écart de \(signed(raw)) min peu plausible, ramené à \(signed(kept)). Vérifiez l'heure saisie et votre position.")
    }
}
