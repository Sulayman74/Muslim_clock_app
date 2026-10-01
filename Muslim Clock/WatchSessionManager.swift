import Foundation
import WatchConnectivity

/// Gère la session WatchConnectivity côté iPhone.
///
/// Deux canaux complémentaires :
/// - `transferUserInfo` : file d'attente, livraison garantie même Watch hors de
///   portée (horaires, réglages) ;
/// - `updateApplicationContext` : « dernier état connu », remplacé à chaque envoi
///   et disponible dès le lancement de l'app Watch. C'est lui qui donne à la
///   montre la position + les réglages nécessaires pour recalculer les horaires
///   toute seule (cf. `SharedPrayerSchedule`).
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    /// L'activation de la session est asynchrone : au cold start, un envoi peut
    /// arriver avant. On réessaie quelques fois plutôt que de le perdre en silence.
    private static let maxActivationRetries = 3
    private static let activationRetryDelay: Duration = .seconds(1)

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Envoie un dictionnaire d'horaires vers la Watch (file d'attente garantie).
    func sendPrayerTimes(_ payload: [String: Double]) {
        transfer(payload)
    }

    /// Envoie les réglages utilisateur (position, méthode, offsets, Jumu'ah…) vers la Watch.
    func sendSettings(_ payload: [String: Any]) {
        transfer(payload)
    }

    /// Publie le dernier état complet (position + réglages + horaires du jour).
    /// Remplace le contexte précédent ; la Watch le reçoit même si elle était
    /// éteinte au moment de l'envoi.
    func updateContext(_ context: [String: Any]) {
        perform(retries: Self.maxActivationRetries) { session in
            do {
                try session.updateApplicationContext(context)
            } catch {
                print("⚠️ [WatchSession] updateApplicationContext a échoué : \(error.localizedDescription)")
            }
        }
    }

    private func transfer(_ payload: [String: Any]) {
        perform(retries: Self.maxActivationRetries) { session in
            session.transferUserInfo(payload)
        }
    }

    /// Exécute `action` sur la session une fois activée.
    private func perform(retries: Int, _ action: @escaping (WCSession) -> Void) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState == .activated {
            action(session)
            return
        }
        guard retries > 0 else {
            print("⚠️ [WatchSession] session non activée, envoi abandonné")
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: Self.activationRetryDelay)
            self.perform(retries: retries - 1, action)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Réactivation après un changement de Watch
        session.activate()
    }
}
