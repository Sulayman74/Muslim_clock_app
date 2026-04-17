import SwiftUI
import Combine
import WatchConnectivity
import WidgetKit

@main
struct WatchExtension_Watch_AppApp: App {
    // L'initialisation du receiver démarre la session WCSession
    @StateObject private var sessionReceiver = WatchSessionReceiver.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionReceiver)
        }
    }
}

// MARK: - WatchSessionReceiver

/// Reçoit les horaires de prière envoyés par l'app iPhone
/// via WatchConnectivity et les écrit dans l'App Group local.
final class WatchSessionReceiver: NSObject, ObservableObject {
    static let shared = WatchSessionReceiver()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

extension WatchSessionReceiver: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    /// Réception des horaires envoyés par l'iPhone (transferUserInfo — livraison garantie)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let defaults = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
        for (key, value) in userInfo {
            if let doubleValue = value as? Double {
                defaults?.set(doubleValue, forKey: key)
            }
        }
        // Recharge les complications immédiatement
        WidgetCenter.shared.reloadAllTimelines()
    }
}
