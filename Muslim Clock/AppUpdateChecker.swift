//
//  AppUpdateChecker.swift
//  Muslim Clock
//
//  Vérifie si une mise à jour est disponible sur l'App Store via l'API iTunes Lookup.
//  Affiche une bannière compacte et non-intrusive si c'est le cas.
//

import SwiftUI
import Combine

// MARK: - Clés UserDefaults

private let updateCheckDateKey = "lastUpdateCheckDate"
private let dismissedVersionKey = "dismissedUpdateVersion"

// MARK: - Service

@MainActor
final class AppUpdateChecker: ObservableObject {

    @Published var updateAvailable = false
    @Published private(set) var latestVersion = ""
    @Published private(set) var storeURL: URL?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Vérification

    /// Vérifie l'App Store au maximum une fois par jour.
    func checkForUpdate() async {
        let lastCheck = UserDefaults.standard.double(forKey: updateCheckDateKey)
        let now = Date().timeIntervalSince1970

        // Une seule vérification par jour
        guard lastCheck == 0 || (now - lastCheck) >= 86_400 else { return }

        guard let bundleId = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let info = results.first,
                  let latest = info["version"] as? String else { return }

            // Enregistre la date de vérification
            UserDefaults.standard.set(now, forKey: updateCheckDateKey)

            let dismissed = UserDefaults.standard.string(forKey: dismissedVersionKey)

            // Affiche la bannière uniquement si la version du Store est plus récente
            // et que l'user ne l'a pas déjà ignorée
            guard latest != dismissed,
                  latest.compare(currentVersion, options: .numeric) == .orderedDescending else { return }

            self.latestVersion = latest
            self.storeURL = (info["trackViewUrl"] as? String).flatMap { URL(string: $0) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                self.updateAvailable = true
            }
            print("✅ [UpdateChecker] Nouvelle version disponible : \(latest) (actuelle : \(currentVersion))")
        } catch {
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
