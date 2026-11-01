//
//  QuranPlanSynchronizer.swift
//  Muslim Clock — publication de la progression Khatma vers l'App Group.
//
//  Même rôle que `PrayerSynchronizer` pour le plan Coran : cette couche fait
//  UNIQUEMENT l'I/O de partage (UserDefaults App Group + WidgetCenter). Le calcul
//  reste dans `QuranPlanMath` ; l'appel vient de `QuranPlanViewModel.refresh`.
//
//  Le widget « Khatma » lit les clés `StorageKeys.khatma*`. Clés absentes = pas
//  de plan actif (le widget affiche « Créer un plan »).
//

import Foundation
import WidgetKit

enum QuranPlanSynchronizer {

    /// Publie le snapshot de progression dans l'App Group et recharge le widget.
    /// No-op si rien n'a changé — `refresh(entries:)` est appelé à chaque apparition
    /// des vues Coran, il ne faut pas recharger la timeline du widget en boucle.
    static func publish(
        progress: QuranPlanProgress,
        streak: Int,
        defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)
    ) {
        guard let d = defaults else { return }

        let changed = d.integer(forKey: StorageKeys.khatmaPagesRead) != progress.pagesReadActual
            || d.integer(forKey: StorageKeys.khatmaTotalPages) != progress.totalPages
            || d.integer(forKey: StorageKeys.khatmaPagesPerDay) != progress.pagesPerDay
            || d.integer(forKey: StorageKeys.khatmaStreak) != streak
        guard changed else { return }

        d.set(progress.pagesReadActual, forKey: StorageKeys.khatmaPagesRead)
        d.set(progress.totalPages, forKey: StorageKeys.khatmaTotalPages)
        d.set(progress.pagesPerDay, forKey: StorageKeys.khatmaPagesPerDay)
        d.set(streak, forKey: StorageKeys.khatmaStreak)

        WidgetCenter.shared.reloadTimelines(ofKind: StorageKeys.khatmaWidgetKind)
    }

    /// Purge la progression publiée (plan supprimé) : le widget repasse à l'état
    /// « Créer un plan ».
    static func clear(defaults: UserDefaults? = UserDefaults(suiteName: AppGroup.identifier)) {
        guard let d = defaults, d.object(forKey: StorageKeys.khatmaTotalPages) != nil else { return }
        d.removeObject(forKey: StorageKeys.khatmaPagesRead)
        d.removeObject(forKey: StorageKeys.khatmaTotalPages)
        d.removeObject(forKey: StorageKeys.khatmaPagesPerDay)
        d.removeObject(forKey: StorageKeys.khatmaStreak)
        WidgetCenter.shared.reloadTimelines(ofKind: StorageKeys.khatmaWidgetKind)
    }
}
