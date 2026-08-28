//
//  IqamahMath.swift
//  Muslim Clock
//
//  Fonctions pures de la fenêtre Adhan → Iqamah : détection de la prière dont
//  la fenêtre contient l'instant présent, et progression dans cette fenêtre.
//
//  Les délais viennent des réglages « Ma mosquée » (iqamahXxxDelay, minutes).
//  Même pattern testable que `IlmMath`/`PodcastMath`/`SmartSetupMath`.
//

import Foundation

enum IqamahMath {

    /// La prière dont la fenêtre `[adhan, adhan + délai)` contient `now`, ou `nil`.
    ///
    /// - La borne basse est incluse (à l'adhan pile, la fenêtre commence),
    ///   la borne haute exclue (à l'iqamah pile, la fenêtre est finie).
    /// - « Jumu'ah » hérite du délai de « Dhuhr » (convention du projet,
    ///   cf. `QuranReminderScheduler`).
    /// - Un délai manquant ou ≤ 0 désactive la fenêtre pour cette prière.
    ///
    /// - Parameters:
    ///   - prayers: Prières du jour (nom FR + heure d'adhan), ex. `dailyPrayers`.
    ///   - delaysMinutes: Délai iqamah par prière (clé = nom FR).
    ///   - now: Instant à tester.
    static func iqamahTarget(
        prayers: [(name: String, adhan: Date)],
        delaysMinutes: [String: Int],
        now: Date
    ) -> (name: String, adhan: Date, iqamah: Date)? {
        for prayer in prayers {
            let delayKey = prayer.name == "Jumu'ah" ? "Dhuhr" : prayer.name
            guard let delay = delaysMinutes[delayKey], delay > 0 else { continue }
            let iqamah = prayer.adhan.addingTimeInterval(TimeInterval(delay * 60))
            if now >= prayer.adhan && now < iqamah {
                return (prayer.name, prayer.adhan, iqamah)
            }
        }
        return nil
    }

    /// Progression dans la fenêtre, bornée à `[0, 1]` (0 = adhan, 1 = iqamah).
    /// Fenêtre dégénérée (iqamah ≤ adhan) → 1 (considérée finie).
    static func progress(adhan: Date, iqamah: Date, now: Date) -> Double {
        let total = iqamah.timeIntervalSince(adhan)
        guard total > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(adhan)
        return min(1, max(0, elapsed / total))
    }
}
