//
//  WuduWindowMath.swift
//  Muslim Clock — fenêtre d'apparition de la carte « Se préparer à la prière »
//
//  Fonction PURE (pattern DhuhrCountdownMath) : détermine si on approche d'une
//  prière et laquelle — wudû' standard, ou ghusl si la prochaine est Jumu'ah.
//  Aucune I/O, aucun DEBUG override ici : les toggles de forçage vivent au call
//  site (pattern RamadanDuaCardView).
//

import Foundation

nonisolated enum WuduWindowMath {

    /// Fenêtre standard : [prochaine − 45 min, prochaine) — le temps de se préparer.
    static let defaultLeadMinutes = 45
    /// Fenêtre du vendredi : le ghusl se fait dans la matinée, bien avant Jumu'ah.
    static let fridayGhuslLeadMinutes = 180

    enum Variant: Equatable {
        /// Approche d'une prière ordinaire — wudû'.
        case wudu(prayer: String, time: Date)
        /// Approche de Jumu'ah — ghusl + bienséances du vendredi.
        case fridayGhusl(time: Date)
    }

    /// Variante à afficher, ou `nil` (hors fenêtre). Borne haute EXCLUE : à
    /// l'adhan la carte s'éteint (même convention que DhuhrCountdownMath).
    ///
    /// - Parameters:
    ///   - prayers: prières du jour (nom, heure) — le nom « Jumu'ah » est déjà
    ///     porté par le VM le vendredi ; `isFriday` couvre le fallback « Dhuhr ».
    static func target(
        prayers: [(name: String, time: Date)],
        now: Date,
        isFriday: Bool,
        leadMinutes: Int = defaultLeadMinutes,
        fridayLeadMinutes: Int = fridayGhuslLeadMinutes
    ) -> Variant? {
        // Prochaine prière = la plus proche strictement à venir.
        guard let next = prayers
            .filter({ now < $0.time })
            .min(by: { $0.time < $1.time }) else { return nil }

        let isJumuah = next.name == "Jumu'ah" || (isFriday && next.name == "Dhuhr")
        let lead = TimeInterval((isJumuah ? fridayLeadMinutes : leadMinutes) * 60)

        guard now >= next.time.addingTimeInterval(-lead) else { return nil }
        return isJumuah ? .fridayGhusl(time: next.time)
                        : .wudu(prayer: next.name, time: next.time)
    }
}
