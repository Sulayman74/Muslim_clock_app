//
//  RemoteJSONLoader.swift
//  Muslim Clock
//
//  Created by MacMini de Sulayman on 02/04/2026.
//

import Foundation

struct RemoteJSONLoader {
    
    /// Charge un fichier JSON depuis un CDN avec un système de cache et de secours (Bundle)
    static func load<T: Codable>(filename: String, remoteURL: String, type: T.Type) async -> T? {
        
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localCacheURL = docsURL.appendingPathComponent(filename)
        
        // 1️⃣ TENTATIVE RÉSEAU (GitHub Pages)
        if let url = URL(string: remoteURL) {
            do {
                // On met un timeout très court (5s) pour ne pas bloquer l'app si le réseau est mauvais
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0
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
