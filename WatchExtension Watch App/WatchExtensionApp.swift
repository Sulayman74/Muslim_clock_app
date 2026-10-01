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

/// Reçoit position, réglages et horaires envoyés par l'app iPhone via
/// WatchConnectivity et les écrit dans l'App Group local (mêmes clés que côté
/// iOS). L'app Watch et la complication recalculent ensuite les horaires avec
/// `SharedPrayerSchedule`, sans dépendre d'un nouvel envoi chaque jour.
final class WatchSessionReceiver: NSObject, ObservableObject {
    static let shared = WatchSessionReceiver()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Écrit tel quel chaque couple clé/valeur (types property-list garantis par
    /// WatchConnectivity : Double, Int, Bool, String) puis recharge les complications.
    private func store(_ values: [String: Any]) {
        guard !values.isEmpty else { return }
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        for (key, value) in values {
            defaults?.set(value, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension WatchSessionReceiver: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // Le dernier contexte publié par l'iPhone est conservé par le système même
        // si l'app Watch n'était pas lancée à sa réception : on le rejoue ici.
        store(session.receivedApplicationContext)
    }

    // Note : `sessionDidBecomeInactive`/`sessionDidDeactivate` ne sont définis que
    // côté iOS (jamais appelés sur watchOS). On les omet ici pour rester clean.

    /// Horaires et réglages en file d'attente (transferUserInfo — livraison garantie).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        store(userInfo)
    }

    /// Dernier état complet publié par l'iPhone (updateApplicationContext) :
    /// position + réglages + horaires du jour.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        store(applicationContext)
    }
}
