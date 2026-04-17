import Network
import Combine
import Foundation

/// Surveillance de la connectivité réseau — singleton `@MainActor`-safe.
///
/// Usage :
/// ```swift
/// @ObservedObject private var network = NetworkMonitor.shared
/// ```
/// Abonnement aux retours de connexion :
/// ```swift
/// .onReceive(NetworkMonitor.shared.onReconnect) { ... }
/// ```
@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    /// `true` si une connexion réseau est disponible
    @Published private(set) var isConnected: Bool = true

    /// `true` si la connexion passe par le réseau cellulaire (potentiellement limité)
    @Published private(set) var isExpensive: Bool = false

    /// Émet `Void` à chaque transition **offline → online**
    let onReconnect = PassthroughSubject<Void, Never>()

    private let monitor     = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "kappsi.NetworkMonitor", qos: .background)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                let nowConnected = path.status == .satisfied
                self.isConnected  = nowConnected
                self.isExpensive  = path.isExpensive
                if !wasConnected && nowConnected {
                    self.onReconnect.send()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit { monitor.cancel() }
}
