//
//  DhuhrCountdownMath.swift
//  Muslim Clock
//
//  Fonction pure du rappel dédié avant Dhuhr / Jumu'ah : n'affiche un décompte
//  que dans la dernière heure avant l'heure de Dhuhr (fenêtre `[Dhuhr − lead, Dhuhr)`).
//
//  Distinct de `IqamahMath` (qui agit APRÈS l'adhan) : ici on est AVANT l'adhan.
//  Même pattern testable que `IqamahMath`/`LocationMath`.
//

import Foundation

enum DhuhrCountdownMath {

    /// Fenêtre d'anticipation par défaut avant Dhuhr (minutes).
    static let defaultLeadMinutes = 60

    /// Cible du rappel avant Dhuhr : `(label, heure)` si `now` est dans les
    /// `leadMinutes` précédant Dhuhr (borne haute exclue : à l'adhan, ce rappel
    /// s'éteint et le relais est pris par la fenêtre iqamah). `nil` sinon.
    ///
    /// Le vendredi, `dailyPrayers` porte déjà le label « Jumu'ah » → il est
    /// renvoyé tel quel (emphase gérée par la vue).
    ///
    /// - Parameters:
    ///   - prayers: Prières du jour (nom FR + heure), ex. `dailyPrayers`.
    ///   - now: Instant à tester.
    ///   - leadMinutes: Anticipation (défaut 60 min).
    static func target(
        prayers: [(name: String, time: Date)],
        now: Date,
        leadMinutes: Int = defaultLeadMinutes
    ) -> (label: String, time: Date)? {
        guard let dhuhr = prayers.first(where: { $0.name == "Dhuhr" || $0.name == "Jumu'ah" }) else {
            return nil
        }
        let windowStart = dhuhr.time.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard now >= windowStart, now < dhuhr.time else { return nil }
        return (dhuhr.name, dhuhr.time)
    }
}
