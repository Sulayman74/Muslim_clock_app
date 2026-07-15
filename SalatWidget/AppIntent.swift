import AppIntents
import Foundation
import os

// MARK: - OpenIntent : Qibla / Adhkar (Control Center deep-link)

/// Cible de l'ouverture de l'app depuis un Control Widget.
/// Apple exige `OpenIntent` (et pas un AppIntent classique avec `openAppWhenRun`) pour les
/// boutons de Control Center qui ouvrent l'app. La cible est dispatched côté app via la clé
/// `controlDeepLinkTarget` dans l'App Group partagé (lu par MainView).
enum MuslimClockLaunchTarget: String, AppEnum {
    case qibla
    case adhkar
    case quran

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Destination")
    static var caseDisplayRepresentations: [MuslimClockLaunchTarget: DisplayRepresentation] = [
        .qibla:  DisplayRepresentation(title: "Qibla"),
        .adhkar: DisplayRepresentation(title: "Adhkar du moment"),
        .quran:  DisplayRepresentation(title: "Lire le Coran"),
    ]
}

/// Ouvre l'app Muslim Clock vers la destination spécifiée.
/// Conforme à `OpenIntent` — protocol Apple-recommandé pour les Control Widgets qui ouvrent l'app.
/// Le fichier qui contient cet intent DOIT être membre des targets app ET widget (cf. exception pbxproj).
struct OpenInMuslimClockIntent: OpenIntent {
    static var title: LocalizedStringResource = "Ouvrir Muslim Clock"

    /// Logger statique pour rester nonisolated (Swift 6 + @MainActor default).
    private static let log = Logger(subsystem: "kappsi.Muslim-Clock", category: "WidgetIntent")

    @Parameter(title: "Destination")
    var target: MuslimClockLaunchTarget

    init() {}

    init(target: MuslimClockLaunchTarget) {
        self.target = target
    }

    func perform() async throws -> some IntentResult {
        Self.log.info("🎯 OpenInMuslimClockIntent.perform() FIRED target=\(target.rawValue, privacy: .public)")
        let shared = UserDefaults(suiteName: AppGroup.identifier)
        if shared == nil {
            Self.log.error("❌ UserDefaults(suiteName:) returned nil — App Group inaccessible")
        }
        shared?.set(target.rawValue, forKey: "controlDeepLinkTarget")
        shared?.set(Date().timeIntervalSince1970, forKey: "controlDeepLinkTimestamp")
        Self.log.info("🎯 Key written, readback=\(shared?.string(forKey: "controlDeepLinkTarget") ?? "nil", privacy: .public)")
        return .result()
    }
}
