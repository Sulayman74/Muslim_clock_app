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

    /// Réception des horaires et réglages envoyés par l'iPhone (transferUserInfo — livraison garantie)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        for (key, value) in userInfo {
            // Supporter Double (horaires), Bool (toggles), Int (heures/minutes)
            switch value {
            case let d as Double:  defaults?.set(d, forKey: key)
            case let b as Bool:    defaults?.set(b, forKey: key)
            case let i as Int:     defaults?.set(i, forKey: key)
            case let s as String:  defaults?.set(s, forKey: key)
            default: break
            }
        }
        // Recharge les complications immédiatement
        WidgetCenter.shared.reloadAllTimelines()
    }
}
