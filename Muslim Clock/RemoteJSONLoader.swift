//
//  RemoteJSONLoader.swift
//  Muslim Clock
//
//  Created by MacMini de Sulayman on 02/04/2026.
//

import Foundation

struct RemoteJSONLoader {
    
    /// Charge un fichier JSON depuis un CDN avec un système de cache et de secours (Bundle).
    ///
    /// - Parameters:
    ///   - filename: Nom de fichier local (utilisé pour cache + fallback bundle).
    ///   - remoteURL: URL CDN à fetcher.
    ///   - type: Type Codable à décoder.
    ///   - timeout: Timeout réseau en secondes. Défaut 5s (contenu daily). Passer 15s
    ///     pour des payloads plus gros (ex: sourate Coran complète).
    /// - Returns: Instance décodée, ou `nil` si échec total.
    static func load<T: Codable>(
        filename: String,
        remoteURL: String,
        type: T.Type,
        timeout: TimeInterval = 5.0
    ) async -> T? {

        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [OTA] documentDirectory inaccessible pour \(filename)")
            return nil
        }
        let localCacheURL = docsURL.appendingPathComponent(filename)

        // 1️⃣ TENTATIVE RÉSEAU (GitHub Pages)
        if let url = URL(string: remoteURL) {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = timeout
                request.cachePolicy = .reloadIgnoringLocalCacheData // Force à chercher la nouveauté
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // SÉCURITÉ : On essaie de décoder AVANT de sauvegarder.
                    // Si tu as fait une erreur de virgule dans ton JSON sur GitHub,
                    // le décodage va planter et l'app n'écrasera pas son bon cache !
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    
                    // Si le JSON est valide, on le sauvegarde dans le téléphone
                    try data.write(to: localCacheURL)
                    print("☁️ [OTA] \(filename) mis à jour depuis le CDN !")
                    return decoded
                }
            } catch {
                print("⚠️ [OTA] Réseau indisponible pour \(filename), passage au cache.")
            }
        }
        
        // 2️⃣ TENTATIVE CACHE LOCAL (Dernière version téléchargée)
        if let cachedData = try? Data(contentsOf: localCacheURL),
           let decoded = try? JSONDecoder().decode(T.self, from: cachedData) {
            print("📂 [OTA] Chargement de \(filename) depuis le cache local.")
            return decoded
        }
        
        // 3️⃣ TENTATIVE BUNDLE (Fichier d'origine de l'application)
        let nameWithoutExt = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        if let bundleURL = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext),
           let bundleData = try? Data(contentsOf: bundleURL),
           let decoded = try? JSONDecoder().decode(T.self, from: bundleData) {
            print("📦 [OTA] Chargement de \(filename) depuis le Bundle de base.")
            return decoded
        }
        
        print("❌ [OTA] Échec total du chargement de \(filename).")
        return nil
    }
}
