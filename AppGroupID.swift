//
//  AppGroupID.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 08/06/2026.
//

import Foundation

/// Identifiant du App Group partagé iOS ↔ Watch ↔ Widget ↔ Complication.
///
/// `nonisolated` permet l'accès depuis les contextes nonisolated
/// (ex: `AppIntent.perform()` en Swift 6) malgré le défaut MainActor du projet.
/// Doit rester aligné avec les fichiers `.entitlements` des 4 targets.
enum AppGroup {
    nonisolated static let identifier = "group.kappsi.Muslim-Clock"
}
