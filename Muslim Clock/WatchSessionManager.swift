import Foundation
import WatchConnectivity

/// Gère la session WatchConnectivity côté iPhone.
/// Envoie les horaires de prière vers la Apple Watch via transferUserInfo
/// (livraison garantie même si la Watch est hors de portée).
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Envoie un dictionnaire d'horaires vers la Watch.
    /// Utilise transferUserInfo qui met les données en file d'attente
    /// et les livre dès que la Watch est disponible.
    func sendPrayerTimes(_ payload: [String: Double]) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(payload)
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
