//
//  ReviewHelper.swift
//  Muslim Clock
//
//  Gestion des demandes d'avis App Store avec fenêtre glissante de 365 jours.
//  Apple autorise 3 demandes par an ; ce fichier est la source de vérité unique.
//

import Foundation
import StoreKit

// MARK: - Clés & constantes

private let reviewDatesKey = "reviewRequestDates"
private let reviewLimit = 3

// MARK: - Helpers internes

/// Retourne les timestamps des demandes effectuées dans les 365 derniers jours.
private func reviewDatesWithinYear() -> [Double] {
    let stored = UserDefaults.standard.array(forKey: reviewDatesKey) as? [Double] ?? []
    let oneYearAgo = Date().addingTimeInterval(-365 * 24 * 3600).timeIntervalSince1970
    return stored.filter { $0 > oneYearAgo }
}

/// Enregistre un timestamp et purge les entrées obsolètes (> 1 an).
private func recordReviewRequest() {
    var recent = reviewDatesWithinYear()
    recent.append(Date().timeIntervalSince1970)
    UserDefaults.standard.set(recent, forKey: reviewDatesKey)
}

// MARK: - API publique

/// Nombre de demandes d'avis restantes sur les 12 prochains mois.
func remainingReviewCount() -> Int {
    return max(0, reviewLimit - reviewDatesWithinYear().count)
}

/// Demande un avis App Store si le quota annuel n'est pas atteint.
/// - Returns: `true` si la demande a été effectuée.
@discardableResult
func requestReviewIfNeeded() -> Bool {
    let remaining = remainingReviewCount()
    guard remaining > 0 else {
        print("⚠️ [Review] Limite de \(reviewLimit) demandes atteinte pour les 12 derniers mois")
        return false
    }
    recordReviewRequest()
    if let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        AppStore.requestReview(in: scene)
        let used = reviewLimit - remaining + 1
        print("✅ [Review] Demande d'avis effectuée (\(used)/\(reviewLimit))")
        return true
    }
    return false
}

/// Force une demande d'avis depuis les Réglages.
/// - Returns: `true` si la demande a été effectuée.
@discardableResult
func forceRequestReview() -> Bool {
    let remaining = remainingReviewCount()
    guard remaining > 0 else { return false }
    recordReviewRequest()
    if let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
        AppStore.requestReview(in: scene)
        let used = reviewLimit - remaining + 1
        print("✅ [Review] Demande manuelle d'avis effectuée (\(used)/\(reviewLimit))")
        return true
    }
    return false
}
