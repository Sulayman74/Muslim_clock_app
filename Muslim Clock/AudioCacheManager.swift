import Foundation
import AVFoundation

// MARK: - AudioCacheManager
// "Download once, play forever" — cache agressif des fichiers audio.
// Fonctionne pour les podcasts Apple ET les playlists custom (S3/Firebase).
//
// Stockage : Documents/AudioCache/ (jamais purge par iOS)
// Purge auto : quand le cache depasse maxCacheBytes, les fichiers les plus anciens sont supprimes.

final class AudioCacheManager {

    static let shared = AudioCacheManager()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let session: URLSession

    // Limite du cache : 500 Mo par defaut
    var maxCacheBytes: Int64 = 500_000_000

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = docs.appendingPathComponent("AudioCache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    // MARK: - Chemin local pour une URL distante

    func localURL(for remoteURL: URL) -> URL {
        // Extraire l'extension depuis le path (avant les query params)
        let pathOnly = remoteURL.path
        let ext = (pathOnly as NSString).pathExtension
        let safeExt = ext.isEmpty ? "mp3" : ext
        let hash = stableHash(remoteURL.absoluteString)
        return cacheDirectory.appendingPathComponent("\(hash).\(safeExt)")
    }

    // MARK: - Verifier si deja en cache

    func isCached(_ remoteURL: URL) -> Bool {
        fileManager.fileExists(atPath: localURL(for: remoteURL).path)
    }

    // MARK: - Obtenir l'URL de lecture (locale si cachee, distante sinon)

    func playableURL(for remoteURL: URL) -> URL {
        let local = localURL(for: remoteURL)
        if fileManager.fileExists(atPath: local.path) {
            print("[AudioCache] Lecture locale : \(local.lastPathComponent)")
            return local
        }
        // Pas en cache : stream distant + download en fond
        print("[AudioCache] Pas en cache, stream + download en fond : \(remoteURL.lastPathComponent)")
        Task { await downloadIfNeeded(remoteURL) }
        return remoteURL
    }

    // MARK: - Telecharger et sauvegarder

    func downloadIfNeeded(_ remoteURL: URL) async {
        let local = localURL(for: remoteURL)
        guard !fileManager.fileExists(atPath: local.path) else { return }

        print("[AudioCache] Telechargement : \(remoteURL.absoluteString.prefix(120))...")
        do {
            let (tempURL, response) = try await session.download(from: remoteURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[AudioCache] Echec HTTP \(code) pour \(remoteURL.lastPathComponent)")
                return
            }

            if fileManager.fileExists(atPath: local.path) {
                try? fileManager.removeItem(at: local)
            }
            try fileManager.moveItem(at: tempURL, to: local)

            let size = fileSizeMB(local)
            print("[AudioCache] Sauvegarde OK : \(local.lastPathComponent) (\(size) Mo)")

            // Purge auto si le cache depasse la limite
            evictIfNeeded()
        } catch {
            print("[AudioCache] Erreur download : \(error.localizedDescription)")
        }
    }

    // MARK: - Pre-telecharger un lot d'episodes

    func prefetch(_ urls: [URL]) {
        Task {
            for url in urls {
                await downloadIfNeeded(url)
            }
        }
    }

    // MARK: - Purge automatique (LRU — supprime les plus anciens)

    private func evictIfNeeded() {
        let currentSize = cacheSizeBytes()
        guard currentSize > maxCacheBytes else { return }

        print("[AudioCache] Cache \(formatBytes(currentSize)) > limite \(formatBytes(maxCacheBytes)), purge...")

        // Lister les fichiers tries par date d'acces (les plus anciens d'abord)
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey]) else { return }

        let sorted = files.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return dateA < dateB
        }

        var freed: Int64 = 0
        let target = currentSize - maxCacheBytes + (maxCacheBytes / 10) // Liberer 10% de marge

        for file in sorted {
            guard freed < target else { break }
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                try? fileManager.removeItem(at: file)
                freed += Int64(size)
                print("[AudioCache] Purge : \(file.lastPathComponent) (\(size / 1_000_000) Mo)")
            }
        }
        print("[AudioCache] Purge terminee, \(formatBytes(freed)) liberes.")
    }

    // MARK: - Stats

    func cacheSizeBytes() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    func cacheSizeFormatted() -> String {
        formatBytes(cacheSizeBytes())
    }

    func cachedFileCount() -> Int {
        (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil))?.count ?? 0
    }

    // MARK: - Vider le cache manuellement

    func clearCache() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
        print("[AudioCache] Cache vide.")
    }

    // MARK: - Helpers

    private func stableHash(_ string: String) -> String {
        var hash: UInt64 = 5381
        for char in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(char)
        }
        return String(hash, radix: 16)
    }

    private func fileSizeMB(_ url: URL) -> String {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return "?" }
        return String(format: "%.1f", Double(size) / 1_000_000)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1_000_000 {
            return "\(bytes / 1_000) Ko"
        } else if bytes < 1_000_000_000 {
            return String(format: "%.1f Mo", Double(bytes) / 1_000_000)
        } else {
            return String(format: "%.2f Go", Double(bytes) / 1_000_000_000)
        }
    }
}
