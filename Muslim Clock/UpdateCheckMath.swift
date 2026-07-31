//
//  UpdateCheckMath.swift
//  Muslim Clock
//
//  Fonctions pures des décisions de mise à jour : bannière App Store
//  (AppUpdateChecker) et pop-up « Quoi de neuf » (MainView.checkWhatsNew).
//
//  Extraites pour être testables sans UserDefaults/Bundle/URLSession —
//  même pattern que `IlmMath`/`PodcastMath`/`SmartSetupMath`.
//

import Foundation

enum UpdateCheckMath {

    // MARK: - Comparaison de versions

    /// Vrai si `latest` est strictement plus récente que `current`, en comparaison
    /// **numérique** ("1.10" > "1.9", contrairement à l'ordre lexicographique).
    static func isNewer(latest: String, current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }

    // MARK: - Throttle du check App Store

    /// Vrai si une vérification App Store est due (au plus une par 24 h).
    ///
    /// - `lastCheck == 0` : jamais vérifié → oui.
    /// - `elapsed < 0` : horloge reculée, date invalide → oui (re-check).
    static func isCheckDue(lastCheck: TimeInterval, now: TimeInterval) -> Bool {
        let elapsed = now - lastCheck
        return lastCheck == 0 || elapsed >= 86_400 || elapsed < 0
    }

    // MARK: - Bannière de mise à jour

    /// Vrai si la bannière doit s'afficher : version Store plus récente que
    /// l'app **et** pas déjà ignorée par l'utilisateur pour cette version.
    /// Sert aussi à décider la restauration d'un état persisté au lancement.
    static func shouldShowBanner(latest: String, current: String, dismissed: String?) -> Bool {
        isNewer(latest: latest, current: current) && latest != dismissed
    }

    // MARK: - Pop-up « Quoi de neuf »

    /// Décision au lancement pour la pop-up « Quoi de neuf ».
    enum WhatsNewAction: Equatable {
        /// Vraie mise à jour → afficher la sheet (la version vue est écrite au dismiss).
        case show
        /// Première installation ou downgrade (TestFlight) → mémoriser la version
        /// sans afficher (ne pas saturer un nouvel utilisateur).
        case recordOnly
        /// Même version (ou version courante illisible) → ne rien faire.
        case nothing
    }

    static func whatsNewAction(current: String, lastSeen: String) -> WhatsNewAction {
        guard !current.isEmpty else { return .nothing }
        if lastSeen.isEmpty { return .recordOnly }
        switch current.compare(lastSeen, options: .numeric) {
        case .orderedDescending: return .show
        case .orderedAscending:  return .recordOnly
        case .orderedSame:       return .nothing
        }
    }
}
