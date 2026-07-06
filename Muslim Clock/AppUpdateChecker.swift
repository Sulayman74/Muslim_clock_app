//
//  AppUpdateChecker.swift
//  Muslim Clock
//
//  Vérifie si une mise à jour est disponible sur l'App Store via l'API iTunes Lookup.
//  Affiche une bannière compacte et non-intrusive si c'est le cas.
//

import SwiftUI
import Combine   // Requis pour @Published/ObservableObject (pas de nouveau code Combine ici)

// MARK: - Clés UserDefaults

private let updateCheckDateKey = "lastUpdateCheckDate"
private let dismissedVersionKey = "dismissedUpdateVersion"
private let availableVersionKey = "availableUpdateVersion"
private let availableStoreURLKey = "availableUpdateStoreURL"

// MARK: - Service

@MainActor
final class AppUpdateChecker: ObservableObject {

    @Published var updateAvailable = false
    @Published private(set) var latestVersion = ""
    @Published private(set) var storeURL: URL?

    /// `nil` plutôt que "0" : un Info.plist corrompu ne doit pas déclencher
    /// une fausse bannière (toute version Store serait > "0").
    var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Anti-réentrance : `.task` et `.onChange(scenePhase, initial: true)`
    /// peuvent appeler checkForUpdate() quasi simultanément au lancement.
    private var checkInFlight = false

    init() {
        restorePersistedUpdate()
    }

    // MARK: - Vérification

    /// Restaure une MAJ détectée lors d'un lancement précédent : le @StateObject est
    /// recréé à chaque lancement mais le throttling 24h persiste — sans restauration,
    /// la bannière disparaît pendant 24h alors que la MAJ existe toujours.
    /// Purge l'état persisté s'il n'est plus pertinent (app mise à jour ou version ignorée).
    private func restorePersistedUpdate() {
        let defaults = UserDefaults.standard
        guard let persisted = defaults.string(forKey: availableVersionKey),
              let current = currentVersion else { return }

        let dismissed = defaults.string(forKey: dismissedVersionKey)
        guard persisted != dismissed,
              persisted.compare(current, options: .numeric) == .orderedDescending else {
            defaults.removeObject(forKey: availableVersionKey)
            defaults.removeObject(forKey: availableStoreURLKey)
            return
        }

        latestVersion = persisted
        storeURL = defaults.string(forKey: availableStoreURLKey).flatMap { URL(string: $0) }
        updateAvailable = true   // sans animation : état initial, pas une transition
    }

    /// Vérifie l'App Store au maximum une fois par jour.
    func checkForUpdate() async {
        guard !checkInFlight else { return }
        checkInFlight = true
        defer { checkInFlight = false }

        let defaults = UserDefaults.standard
        let lastCheck = defaults.double(forKey: updateCheckDateKey)
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastCheck

        // Une vérification par jour. `elapsed < 0` = horloge reculée → date invalide, on re-check.
        guard lastCheck == 0 || elapsed >= 86_400 || elapsed < 0 else { return }

        guard let current = currentVersion,
              let bundleId = Bundle.main.bundleIdentifier else { return }

        // Storefront local : sans `country`, le lookup interroge le store US
        // et peut renvoyer `results` vide pour une app non distribuée aux US.
        var urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)"
        if let region = Locale.current.region?.identifier.lowercased() {
            urlString += "&country=\(region)"
        }
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return }

            // Réponse valide (même avec results vide) → date enregistrée, sinon
            // on refait une requête réseau à chaque lancement.
            defaults.set(now, forKey: updateCheckDateKey)

            guard let info = results.first,
                  let latest = info["version"] as? String else { return }

            guard latest.compare(current, options: .numeric) == .orderedDescending else {
                // À jour → purge un éventuel état persisté obsolète.
                defaults.removeObject(forKey: availableVersionKey)
                defaults.removeObject(forKey: availableStoreURLKey)
                return
            }

            // Persiste la détection pour survivre au throttling 24h (cf. restorePersistedUpdate).
            let trackURL = info["trackViewUrl"] as? String
            defaults.set(latest, forKey: availableVersionKey)
            defaults.set(trackURL, forKey: availableStoreURLKey)

            // Affiche la bannière uniquement si l'user ne l'a pas déjà ignorée
            guard latest != defaults.string(forKey: dismissedVersionKey) else { return }

            self.latestVersion = latest
            self.storeURL = trackURL.flatMap { URL(string: $0) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.updateAvailable = true
            }
            print("✅ [UpdateChecker] Nouvelle version disponible : \(latest) (actuelle : \(current))")
        } catch {
            // Erreur réseau : on n'écrit PAS la date → nouvel essai au prochain lancement.
            print("⚠️ [UpdateChecker] \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    /// Ouvre la page de l'app sur l'App Store.
    func openAppStore() {
        guard let url = storeURL else { return }
        UIApplication.shared.open(url)
    }

    /// Ignore définitivement cette version (ne remontre plus la bannière pour cette version).
    func dismiss() {
        UserDefaults.standard.set(latestVersion, forKey: dismissedVersionKey)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            updateAvailable = false
        }
    }

    /// Force l'affichage de la bannière avec une version factice pour preview/QA.
    /// N'écrit rien dans UserDefaults — le `dismiss()` suivant n'aura aucun effet
    /// sur la vraie détection (la version "aperçu" n'a aucune chance d'être réelle).
    func simulatePreview() {
        self.latestVersion = "aperçu"
        self.storeURL = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.updateAvailable = true
        }
    }
}

// MARK: - Bannière

struct AppUpdateBannerView: View {
    @ObservedObject var checker: AppUpdateChecker

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mise à jour disponible")
                    .font(.footnote.bold())
                    .foregroundColor(.primary)
                Text("Version \(checker.latestVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                checker.openAppStore()
            } label: {
                Text("Mettre à jour")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            Button {
                checker.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .cardStyle()
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
