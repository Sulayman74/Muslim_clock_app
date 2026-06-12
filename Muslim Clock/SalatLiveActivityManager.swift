//
//  SalatLiveActivityManager.swift
//  Muslim Clock
//
//  Démarre / met à jour / termine la Live Activity "Prochaine Salât".
//  Déclenché par PrayerTimesViewModel après chaque recalcul, et par
//  Muslim_ClockApp au passage `.scenePhase == .active`.
//

import Foundation
import ActivityKit

/// Singleton gérant le cycle de vie de la Live Activity de prière.
///
/// Politique :
/// - Démarre une activity quand `targetTime - now <= 30 min` (fenêtre d'annonce).
/// - Ne démarre rien si l'utilisateur a désactivé les Live Activities en réglages.
/// - Si une activity est déjà active pour une AUTRE prière → l'arrête puis en démarre une nouvelle.
/// - Si la même prière → no-op (évite spam).
/// - `endIfExpired()` clôture les activities dont `targetTime` est passé, avec une fenêtre
///   d'affichage post-prière de 5 min (`dismissalPolicy: .after(...)`).
@MainActor
final class SalatLiveActivityManager {

    static let shared = SalatLiveActivityManager()

    /// Fenêtre d'annonce : on déclenche la Live Activity quand la prochaine prière est dans <= 30 min.
    private static let announceWindow: TimeInterval = 30 * 60

    /// Délai d'affichage post-prière (la bannière reste visible 5 min après l'heure de la prière).
    private static let postPrayerLinger: TimeInterval = 5 * 60

    /// Tâches d'auto-update/end programmées par prière (clé = `prayerKey`).
    /// Permet de cancel proprement quand on remplace une activity avant terme.
    private var scheduledTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - API publique

    /// Met à jour la Live Activity en fonction de la prochaine prière.
    /// À appeler à chaque recalcul de `nextPrayerDate` (PrayerTimesViewModel).
    func refresh(
        prayerKey: String,
        frenchName: String,
        targetTime: Date
    ) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let timeUntil = targetTime.timeIntervalSinceNow

        // Hors fenêtre d'annonce → on ne démarre rien. On garde l'activity actuelle si elle existe
        // (elle se termine d'elle-même via endIfExpired ou la `staleDate`).
        guard timeUntil > 0, timeUntil <= Self.announceWindow else {
            return
        }

        // Si une activity est déjà active pour cette même prière → mettre à jour le targetTime
        // si jamais il a changé (ex: temkine modifié). Sinon, no-op.
        if let existing = currentActivity(forPrayerKey: prayerKey) {
            let currentTarget = existing.content.state.targetTime
            if abs(currentTarget.timeIntervalSince(targetTime)) > 1 {
                Task { await update(existing, targetTime: targetTime) }
            }
            return
        }

        // Une activity pour une autre prière est encore active (cas rare) → la terminer immédiatement.
        for activity in Activity<SalatLiveActivityAttributes>.activities
            where activity.attributes.prayerKey != prayerKey {
            Task { await endActivity(activity, immediate: true) }
        }

        // Démarrer la nouvelle activity
        start(prayerKey: prayerKey, frenchName: frenchName, targetTime: targetTime)
    }

    /// Synchronise l'état des Live Activities en cours avec l'heure réelle.
    ///
    /// À appeler au passage `scenePhase = .active` pour rattraper les transitions
    /// que la `Task` d'auto-update aurait pu rater si iOS a suspendu l'app
    /// (le `Task.sleep` ne court pas en background).
    ///
    /// Politique appliquée par activity :
    /// - `now >= targetTime + 5min` → fin immédiate (fenêtre lingering dépassée).
    /// - `now >= targetTime` (encore dans les 5 min de linger) → si `isPrayerTime`
    ///   est encore `false`, bascule à `true` (UI affiche « C'est l'heure ») et
    ///   reprogramme une fin à `targetTime + 5min`.
    /// - `now < targetTime` → no-op (la Task originale fera son travail si l'app
    ///   reste vivante ; sinon le prochain `scenePhase = .active` rattrapera).
    func syncActiveActivitiesState() {
        guard #available(iOS 16.2, *) else { return }
        let now = Date()
        for activity in Activity<SalatLiveActivityAttributes>.activities {
            let target = activity.content.state.targetTime
            let lingerEnd = target.addingTimeInterval(Self.postPrayerLinger)

            if now >= lingerEnd {
                // Fenêtre lingering dépassée → fermer immédiatement.
                Task { await endActivity(activity, immediate: true) }
            } else if now >= target {
                // Dans la fenêtre 5 min : s'assurer que isPrayerTime est passé à true.
                if !activity.content.state.isPrayerTime {
                    Task { await markAsPrayerTime(activity) }
                }
            }
            // else : prière encore à venir, rien à faire ici.
        }
    }

    // MARK: - Privé

    @available(iOS 16.2, *)
    private func currentActivity(forPrayerKey key: String) -> Activity<SalatLiveActivityAttributes>? {
        Activity<SalatLiveActivityAttributes>.activities.first { $0.attributes.prayerKey == key }
    }

    @available(iOS 16.2, *)
    private func start(prayerKey: String, frenchName: String, targetTime: Date) {
        // Pendant Ramadan, le countdown vers Maghrib devient « Iftar » et vers Fajr
        // devient « Suhoor » (fin du repas avant l'aube). La LA ne s'arme que dans
        // les 30 min précédant la prière — fenêtre exacte du sahari côté Fajr. La
        // clé canonique reste inchangée pour préserver le mapping.
        let displayName = IslamicSeasonInfo.displayPrayerLabel(
            for: frenchName,
            at: targetTime,
            context: .liveActivity
        )
        let attributes = SalatLiveActivityAttributes(
            prayerKey: prayerKey,
            frenchName: displayName,
            arabicName: Self.arabicName(for: prayerKey),
            iconName: Self.iconName(for: prayerKey)
        )
        let state = SalatLiveActivityAttributes.ContentState(targetTime: targetTime, isPrayerTime: false)
        // `staleDate` à T=0 → iOS marque l'activity comme stale dès que la prière commence,
        // ce qui aide à déclencher un re-render naturel avec le nouveau ContentState.
        let content = ActivityContent(
            state: state,
            staleDate: targetTime.addingTimeInterval(Self.postPrayerLinger)
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            scheduleAutoTransitions(for: activity, targetTime: targetTime)
        } catch {
            print("⚠️ [LiveActivity] Échec du démarrage : \(error.localizedDescription)")
        }
    }

    /// Met à jour le `targetTime` d'une activity existante (cas typique : temkine modifié).
    ///
    /// Reset volontaire `isPrayerTime = false` : ce path n'est utilisé que par `refresh()`
    /// qui filtre amont (`timeUntil > 0`), donc la prière n'a pas encore eu lieu.
    /// L'assert garantit cette invariante en DEBUG.
    @available(iOS 16.2, *)
    private func update(_ activity: Activity<SalatLiveActivityAttributes>, targetTime: Date) async {
        assert(targetTime > Date(), "update() ne doit être appelé que pour une prière à venir — utiliser markAsPrayerTime/endActivity sinon")
        let state = SalatLiveActivityAttributes.ContentState(targetTime: targetTime, isPrayerTime: false)
        let content = ActivityContent(
            state: state,
            staleDate: targetTime.addingTimeInterval(Self.postPrayerLinger)
        )
        await activity.update(content)
        scheduleAutoTransitions(for: activity, targetTime: targetTime)
    }

    /// Bascule une activity sur l'état « C'est l'heure de la prière » et reprogramme
    /// sa fin à `targetTime + 5 min`. Appelée par `syncActiveActivitiesState` pour
    /// rattraper le bascule raté quand l'app a été suspendue avant `targetTime`.
    @available(iOS 16.2, *)
    private func markAsPrayerTime(_ activity: Activity<SalatLiveActivityAttributes>) async {
        let target = activity.content.state.targetTime
        let state = SalatLiveActivityAttributes.ContentState(targetTime: target, isPrayerTime: true)
        let content = ActivityContent(
            state: state,
            staleDate: target.addingTimeInterval(Self.postPrayerLinger)
        )
        await activity.update(content)

        // Reprogrammer la fin (la Task d'auto-transition originale est probablement morte
        // si on est arrivé là via syncActiveActivitiesState).
        let key = activity.attributes.prayerKey
        scheduledTasks[key]?.cancel()
        scheduledTasks[key] = Task { @MainActor in
            let untilLingerEnd = max(0, target.addingTimeInterval(Self.postPrayerLinger).timeIntervalSinceNow)
            if untilLingerEnd > 0 {
                try? await Task.sleep(nanoseconds: UInt64(untilLingerEnd * 1_000_000_000))
            }
            if Task.isCancelled { return }
            await activity.end(content, dismissalPolicy: .immediate)
            scheduledTasks[key] = nil
        }
    }

    /// Programme deux transitions automatiques pour une activity en cours :
    /// 1. À `targetTime` → push une update avec `isPrayerTime = true` (UI bascule sur le label).
    /// 2. À `targetTime + postPrayerLinger` → ferme l'activity immédiatement.
    ///
    /// Note : marche seulement tant que le process reste vivant. En production, la fenêtre
    /// d'annonce (30 min) + la durée post-prière (5 min) sont courtes — l'app a de bonnes
    /// chances de rester active. Pour un fallback robuste 100 % background, il faudrait
    /// `BGTaskScheduler` ou des pushes ActivityKit (hors scope actuel).
    @available(iOS 16.2, *)
    private func scheduleAutoTransitions(
        for activity: Activity<SalatLiveActivityAttributes>,
        targetTime: Date
    ) {
        let key = activity.attributes.prayerKey
        // Cancel l'ancienne planification éventuelle pour cette prière (cas d'un update du targetTime).
        scheduledTasks[key]?.cancel()

        scheduledTasks[key] = Task { @MainActor in
            // Phase 1 : attendre l'heure de la prière.
            let untilArrival = max(0, targetTime.timeIntervalSinceNow)
            if untilArrival > 0 {
                try? await Task.sleep(nanoseconds: UInt64(untilArrival * 1_000_000_000))
            }
            if Task.isCancelled { return }

            // Marquer la prière comme commencée → l'UI affiche "C'est l'heure de la prière".
            let arrivedState = SalatLiveActivityAttributes.ContentState(
                targetTime: targetTime,
                isPrayerTime: true
            )
            let arrivedContent = ActivityContent(
                state: arrivedState,
                staleDate: targetTime.addingTimeInterval(Self.postPrayerLinger)
            )
            await activity.update(arrivedContent)

            // Phase 2 : attendre la fenêtre d'affichage post-prière puis fermer.
            try? await Task.sleep(nanoseconds: UInt64(Self.postPrayerLinger * 1_000_000_000))
            if Task.isCancelled { return }

            await activity.end(arrivedContent, dismissalPolicy: .immediate)
            scheduledTasks[key] = nil
        }
    }

    @available(iOS 16.2, *)
    private func endActivity(_ activity: Activity<SalatLiveActivityAttributes>, immediate: Bool) async {
        // Cancel l'éventuelle Task d'auto-transition pour éviter qu'elle ne déclenche un end()
        // ou un update() sur une activity déjà fermée.
        scheduledTasks[activity.attributes.prayerKey]?.cancel()
        scheduledTasks[activity.attributes.prayerKey] = nil

        let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
        let policy: ActivityUIDismissalPolicy = immediate
            ? .immediate
            : .after(.now + Self.postPrayerLinger)
        await activity.end(finalContent, dismissalPolicy: policy)
    }

    // MARK: - Mapping nom / icône

    /// Retourne le nom arabe d'une prière pour une clé donnée.
    static func arabicName(for prayerKey: String) -> String {
        switch prayerKey.lowercased() {
        case "fajr":    return "الفجر"
        case "dhuhr":   return "الظهر"
        case "asr":     return "العصر"
        case "maghrib": return "المغرب"
        case "isha":    return "العشاء"
        case "jumuah":  return "الجمعة"
        default:        return ""
        }
    }

    /// Retourne le SF Symbol associé à une prière.
    static func iconName(for prayerKey: String) -> String {
        switch prayerKey.lowercased() {
        case "fajr":    return "sunrise.fill"
        case "dhuhr":   return "sun.max.fill"
        case "asr":     return "sun.min.fill"
        case "maghrib": return "sunset.fill"
        case "isha":    return "moon.stars.fill"
        case "jumuah":  return "building.columns.fill"
        default:        return "moon.fill"
        }
    }

    /// Convertit un nom FR (tel qu'utilisé par `PrayerTimesViewModel.nextPrayerName`) en clé canonique.
    /// "Jumu'ah" et "Dhuhr" partagent la nature de la prière mais ont des clés distinctes
    /// pour la cohérence visuelle et le dispatch SF Symbol.
    static func prayerKey(from frenchName: String) -> String {
        switch frenchName {
        case "Fajr":    return "fajr"
        case "Dhuhr":   return "dhuhr"
        case "Jumu'ah": return "jumuah"
        case "Asr":     return "asr"
        case "Maghrib": return "maghrib"
        case "Isha":    return "isha"
        default:        return frenchName.lowercased()
        }
    }
}
