//
//  PodcastManager.swift
//  Muslim Clock
//
//  Updated — Scoped storage + Resume playback + Swift 6 safe
//

import Foundation
import Combine
import AVFoundation
import MediaPlayer
import StoreKit

struct PodcastEpisode: Identifiable {
    let id = UUID()
    var title: String
    var audioURL: URL
}

struct CuratedAudioSeries: Codable {
    let id: String
    let name: String
    let author: String
    let type: String?        // "apple" (defaut) ou "custom"
    let playlistURL: String? // URL du JSON playlist (pour type == "custom")
}

// Modele pour les playlists custom (S3 / Firebase / CDN)
struct CustomPlaylist: Codable {
    let title: String
    let author: String
    let artworkURL: String?
    let episodes: [CustomEpisode]
}

struct CustomEpisode: Codable {
    let title: String
    let audioURL: String
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Modèle de position de reprise (~80 octets en UserDefaults)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct ResumeBookmark: Codable {
    let episodeURL: String   // URL de l'épisode
    let position: Double     // Secondes écoulées
    let episodeTitle: String // Pour afficher le titre sans re-fetcher
}

@MainActor
class PodcastManager: NSObject, ObservableObject, XMLParserDelegate {
    
    // MARK: - Épisodes & Métadonnées
    @Published var episodes: [PodcastEpisode] = []
    @Published var failedToLoad: Bool = false
    @Published var podcastTitle: String = "Chargement..."
    @Published var podcastAuthor: String = ""
    @Published var podcastArtworkURL: URL? = nil
    @Published var seriesProgress: Double = 0.0
    
    // MARK: - Lecture
    @Published var isPlaying = false
    @Published var currentlyPlayingID: UUID? = nil
    @Published var currentEpisodeTitle: String = ""
    @Published var showFullPlayer:Bool = false
    @Published var curatedSeriesList: [CuratedAudioSeries] = []
    
    // MARK: - Timeline
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var isBuffering: Bool = false
    @Published var playbackRate: Float = 1.0
    @Published var isSeeking: Bool = false
    var activeSeriesIndex: Int { currentSeriesIndex }
    
    // ✨ NOUVEAU : Gestion de la pop-up de review
    @Published var showReviewPopup: Bool = false
    @Published var completedSeriesName: String = ""
    
    // MARK: - Privé
    private var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    private var timeObserver: Any?
    private var saveCounter: Int = 0  // Pour sauvegarder la position toutes les 10s, pas toutes les 0.5s
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentAudioURL = ""
    
    private var currentSeriesIndex: Int {
        get { UserDefaults.standard.integer(forKey: "current_podcast_index") }
        set { UserDefaults.standard.set(newValue, forKey: "current_podcast_index") }
    }
    
    /// L'ID Apple de la série en cours (pour scoper les clés UserDefaults)
    private var currentSeriesID: String {
        guard !curatedSeriesList.isEmpty,
              currentSeriesIndex < curatedSeriesList.count else { return "unknown" }
        return curatedSeriesList[currentSeriesIndex].id
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - CLÉS USERDEFAULTS SCOPÉES PAR SÉRIE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // Avant : "played_episodes" → tableau global qui grossit à l'infini
    // Après : "played_XXXXX" → tableau scopé par série, purgé au changement
    
    private var playedKey: String { "played_\(currentSeriesID)" }
    private var resumeKey: String { "resume_\(currentSeriesID)" }
    
    // MARK: - Fermer le lecteur
        func stopAndClose() {
            // 1. On met en pause
            player?.pause()
            isPlaying = false
            
            // 2. On réinitialise l'état visuel
            currentlyPlayingID = nil
            currentEpisodeTitle = ""
            currentTime = 0
            
            // 3. On nettoie tout pour libérer la mémoire
            cleanupObservers()
            player = nil
            
            // 4. On efface le lecteur de l'écran de verrouillage d'iOS
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            
            // ✅ 5. WAKE LOCK : Réactiver la mise en veille automatique
            disableWakeLock()
        }
    
    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // ✅ WAKE LOCK : Empêche la mise en veille pendant la lecture
            UIApplication.shared.isIdleTimerDisabled = true
        } catch {
            print("❌ [Audio] AVAudioSession : \(error.localizedDescription)")
        }
    }
    
    // MARK: - Désactiver le Wake Lock
    private func disableWakeLock() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - Fetch Podcast
    func fetchPodcast(appleID: String) async {
        guard episodes.isEmpty else { return }

        let lookupURLString = "https://itunes.apple.com/lookup?id=\(appleID)&entity=podcast"
        guard let lookupURL = URL(string: lookupURLString),
              let (data, _) = try? await URLSession.shared.data(from: lookupURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let firstResult = results.first,
              let feedUrlString = firstResult["feedUrl"] as? String,
              let feedUrl = URL(string: feedUrlString) else {
            self.failedToLoad = true
            return
        }

        self.podcastTitle = firstResult["collectionName"] as? String ?? "Série de Cours"
        self.podcastAuthor = firstResult["artistName"] as? String ?? "Cheikh"
        if let artworkString = firstResult["artworkUrl600"] as? String {
            self.podcastArtworkURL = URL(string: artworkString)
        }

        guard let (xmlData, _) = try? await URLSession.shared.data(from: feedUrl) else {
            self.failedToLoad = true
            return
        }
        self.failedToLoad = false
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.parse()
    }

    // MARK: - Fetch Custom Playlist (S3 / Firebase / CDN)
    //
    // Deux modes :
    //   1) playlistURL pointe vers un JSON de playlist -> on decode les episodes
    //   2) playlistURL pointe directement vers un fichier audio -> on cree 1 episode
    //
    func fetchCustomPlaylist(urlString: String, seriesName: String, seriesAuthor: String) async {
        print("[CustomPlaylist] Debut chargement : \(urlString)")
        guard episodes.isEmpty else {
            print("[CustomPlaylist] Episodes deja charges, skip.")
            return
        }

        // Detection : est-ce un fichier audio direct ou un JSON ?
        let lowered = urlString.lowercased()
        let audioExtensions = [".mp3", ".m4a", ".aac", ".wav", ".caf", ".ogg"]
        let isDirectAudio = audioExtensions.contains(where: { lowered.contains($0) })

        if isDirectAudio {
            // Mode fichier audio direct
            print("[CustomPlaylist] Mode AUDIO DIRECT detecte (pas un JSON)")
            guard let url = URL(string: urlString) else {
                print("[CustomPlaylist] URL invalide : \(urlString)")
                self.failedToLoad = true
                return
            }
            self.podcastTitle = seriesName
            self.podcastAuthor = seriesAuthor
            self.episodes = [PodcastEpisode(title: seriesName, audioURL: url)]
            print("[CustomPlaylist] 1 episode cree : \(seriesName) -> \(url)")
            self.failedToLoad = false
            return
        }

        // Mode JSON playlist
        print("[CustomPlaylist] Mode JSON PLAYLIST")
        let filename = "playlist_\(urlString.hashValue).json"
        print("[CustomPlaylist] Fichier cache local : \(filename)")

        // Debug : fetch brut pour voir le contenu
        if let url = URL(string: urlString) {
            do {
                let (rawData, response) = try await URLSession.shared.data(from: url)
                let httpCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let rawString = String(data: rawData, encoding: .utf8) ?? "(non-UTF8, \(rawData.count) octets — probablement un fichier audio, pas du JSON)"
                print("[CustomPlaylist] HTTP \(httpCode) — Taille: \(rawData.count) octets")
                print("[CustomPlaylist] Contenu brut (500 premiers chars):")
                print(String(rawString.prefix(500)))
            } catch {
                print("[CustomPlaylist] Erreur fetch brut : \(error)")
            }
        }

        guard let playlist = await RemoteJSONLoader.load(
            filename: filename,
            remoteURL: urlString,
            type: CustomPlaylist.self
        ) else {
            print("[CustomPlaylist] ECHEC decodage JSON.")
            print("[CustomPlaylist] Structure attendue :")
            print("""
            {
              "title": "...",
              "author": "...",
              "artworkURL": "https://...",
              "episodes": [
                { "title": "Sourate 1", "audioURL": "https://...mp3" }
              ]
            }
            """)
            self.failedToLoad = true
            return
        }

        print("[CustomPlaylist] Decode OK !")
        print("[CustomPlaylist] Titre: \(playlist.title), Auteur: \(playlist.author)")
        print("[CustomPlaylist] Nombre d'episodes: \(playlist.episodes.count)")

        self.podcastTitle = playlist.title
        self.podcastAuthor = playlist.author
        if let artworkString = playlist.artworkURL, let artworkURL = URL(string: artworkString) {
            self.podcastArtworkURL = artworkURL
        }

        self.episodes = playlist.episodes.compactMap { ep in
            guard let url = URL(string: ep.audioURL) else {
                print("[CustomPlaylist] URL invalide pour '\(ep.title)': \(ep.audioURL)")
                return nil
            }
            print("[CustomPlaylist] Episode: \(ep.title) -> \(url)")
            return PodcastEpisode(title: ep.title, audioURL: url)
        }

        print("[CustomPlaylist] Episodes charges: \(episodes.count)")
        self.failedToLoad = episodes.isEmpty
    }

    // MARK: - Reconnexion réseau

    /// Appelé quand la connexion est restaurée. Recharge si le premier chargement avait échoué.
    func retryLoadIfNeeded() async {
        guard failedToLoad || episodes.isEmpty else { return }
        episodes     = []
        failedToLoad = false
        await loadSmartPodcast()
    }

    /// Reprend le buffer audio si AVPlayer était en attente (connexion coupée pendant la lecture).
    func resumeBufferingIfStalled() {
        guard isPlaying,
              let player,
              player.timeControlStatus == .waitingToPlayAtSpecifiedRate else { return }
        let target = CMTime(seconds: currentTime, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.play()
            }
        }
    }
    
    // MARK: - XML Parser
    nonisolated func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let url = attributeDict["url"]
        Task { @MainActor in
            self.currentElement = elementName
            if elementName == "item" {
                self.currentTitle = ""
                self.currentAudioURL = ""
            } else if elementName == "enclosure", let url {
                self.currentAudioURL = url
            }
        }
    }
    
    nonisolated func parser(_ parser: XMLParser, foundCharacters string: String) {
        let chars = string
        Task { @MainActor in
            if self.currentElement == "title" {
                self.currentTitle += chars
            }
        }
    }
    
    nonisolated func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        Task { @MainActor in
            if elementName == "item" {
                let cleanTitle = self.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: self.currentAudioURL), !cleanTitle.isEmpty {
                    self.episodes.append(PodcastEpisode(title: cleanTitle, audioURL: url))
                }
            }
        }
    }
    
    // MARK: - Chargement du Podcast (OTA & Smart Setup)
        func loadSmartPodcast() async {
            
            // 1. On tente de récupérer la liste via le CDN GitHub (ou Cache/Bundle si pas d'internet)
            if curatedSeriesList.isEmpty {
                // 🔗 REMPLACE CECI PAR TON URL EXACTE GITHUB PAGES :
                let githubURL = "https://sulayman74.github.io/Muslim_clock_app/audios.json"
                
                if let remoteSeries = await RemoteJSONLoader.load(
                    filename: "audios.json",
                    remoteURL: githubURL,
                    type: [CuratedAudioSeries].self
                ) {
                    self.curatedSeriesList = remoteSeries
                } else {
                    // Secours ultime si même le fichier dans l'application est introuvable
                    self.curatedSeriesList = [CuratedAudioSeries(id: "1410186668", name: "Série par défaut", author: "", type: nil, playlistURL: nil)]
                }
            }
            
            // 2. Sécurité : si on a raccourci le JSON et que l'index actuel n'existe plus
            if currentSeriesIndex >= curatedSeriesList.count {
                currentSeriesIndex = 0
            }
            
            // 3. Affichage immédiat du nom/auteur depuis les données locales
            let targetSeries = curatedSeriesList[currentSeriesIndex]
            if podcastTitle == "Chargement..." || podcastTitle.isEmpty {
                self.podcastTitle = targetSeries.name
            }
            if podcastAuthor.isEmpty {
                self.podcastAuthor = targetSeries.author
            }
            
            // 4. Lancement du fetch : Apple Podcast ou playlist custom
            print("[LoadSmart] Serie #\(currentSeriesIndex): id=\(targetSeries.id), type=\(targetSeries.type ?? "apple"), name=\(targetSeries.name)")
            if let playlistURL = targetSeries.playlistURL {
                print("[LoadSmart] playlistURL = \(playlistURL)")
            }

            if targetSeries.type == "custom", let playlistURL = targetSeries.playlistURL {
                print("[LoadSmart] -> Mode CUSTOM")
                await fetchCustomPlaylist(
                    urlString: playlistURL,
                    seriesName: targetSeries.name,
                    seriesAuthor: targetSeries.author
                )
            } else {
                print("[LoadSmart] -> Mode APPLE PODCAST (id: \(targetSeries.id))")
                await fetchPodcast(appleID: targetSeries.id)
            }
            calculateProgress()

            // Pre-telechargement en fond des episodes non caches
            let uncachedURLs = episodes
                .map(\.audioURL)
                .filter { !AudioCacheManager.shared.isCached($0) }
            if !uncachedURLs.isEmpty {
                print("[Prefetch] \(uncachedURLs.count) episodes a cacher en fond...")
                AudioCacheManager.shared.prefetch(uncachedURLs)
            }

            // REPRISE AUTOMATIQUE : si on a un bookmark pour cette serie, on propose
            restoreBookmarkIfNeeded()
        }
    // MARK: - Changement Manuel de Série
        func changeSeries(to index: Int) {
            guard index >= 0, index < curatedSeriesList.count, index != currentSeriesIndex else { return }
            
            // 1. Arrêt propre de la lecture en cours
            stopAndClose()
            
            // 2. Mise à jour de l'index
            currentSeriesIndex = index
            
            // 3. Réinitialisation de l'interface avec les infos locales immédiates
            let targetSeries = curatedSeriesList[index]
            self.episodes = []
            self.seriesProgress = 0.0
            self.podcastTitle = targetSeries.name
            self.podcastAuthor = targetSeries.author
            self.podcastArtworkURL = nil
            
            // 4. Chargement de la nouvelle série
            Task { await loadSmartPodcast() }
        }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - PROGRESSION SCOPÉE PAR SÉRIE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func isEpisodePlayed(episode: PodcastEpisode) -> Bool {
        let playedURLs = UserDefaults.standard.stringArray(forKey: playedKey) ?? []
        return playedURLs.contains(episode.audioURL.absoluteString)
    }
    
    func markAsPlayed(episode: PodcastEpisode) {
        var playedURLs = UserDefaults.standard.stringArray(forKey: playedKey) ?? []
        let urlString = episode.audioURL.absoluteString
        if !playedURLs.contains(urlString) {
            playedURLs.append(urlString)
            UserDefaults.standard.set(playedURLs, forKey: playedKey)
            print("✅ [Progression] Épisode marqué : \(episode.title)")
            calculateProgress()
        }
    }
    
    private func calculateProgress() {
        guard !episodes.isEmpty else { return }
        let playedCount = episodes.filter { isEpisodePlayed(episode: $0) }.count
        self.seriesProgress = Double(playedCount) / Double(episodes.count)
        print("📊 [Progression] \(playedCount)/\(episodes.count) épisodes lus (\(Int(seriesProgress * 100))%)")
        
        // ✅ Si série terminée à 100%, on passe à la suivante
        if self.seriesProgress >= 1.0 {
            print("🎉 [Progression] Série complétée ! Passage à la suivante...")
            moveToNextSeries()
        }
    }
    
    private func moveToNextSeries() {
        let oldPlayedKey = playedKey
        let oldResumeKey = resumeKey
        
        // ✅ SAUVEGARDER LE NOM DE LA SÉRIE TERMINÉE
        self.completedSeriesName = podcastTitle
        
        // ✅ AFFICHER LA POP-UP DE FÉLICITATIONS
        Task { @MainActor in
            // Petit délai pour laisser l'animation de fin se terminer
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            self.showReviewPopup = true
        }
        
        if currentSeriesIndex < curatedSeriesList.count - 1 {
            currentSeriesIndex += 1
        } else {
            currentSeriesIndex = 0
        }
        
        // ✅ NETTOYAGE : on purge les clés de l'ANCIENNE série
        UserDefaults.standard.removeObject(forKey: oldPlayedKey)
        UserDefaults.standard.removeObject(forKey: oldResumeKey)
        print("🧹 [Storage] Purgé : \(oldPlayedKey) et \(oldResumeKey)")
        
        self.episodes = []
        Task { await loadSmartPodcast() }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - SAUVEGARDE / REPRISE DE POSITION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    /// Sauvegarde la position courante (appelé toutes les ~10s pendant la lecture)
    private func savePlaybackPosition() {
        guard let id = currentlyPlayingID,
              let episode = episodes.first(where: { $0.id == id }),
              currentTime > 5 else { return } // Pas la peine de sauver si < 5s
        
        let bookmark = ResumeBookmark(
            episodeURL: episode.audioURL.absoluteString,
            position: currentTime,
            episodeTitle: episode.title
        )
        
        if let data = try? JSONEncoder().encode(bookmark) {
            UserDefaults.standard.set(data, forKey: resumeKey)
        }
    }
    
    /// Sauvegarde immédiate (appelé quand l'app passe en background ou pause)
    func savePlaybackPositionNow() {
        savePlaybackPosition()
    }
    
    /// Restaure la dernière position au lancement
    private func restoreBookmarkIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: resumeKey),
              let bookmark = try? JSONDecoder().decode(ResumeBookmark.self, from: data),
              let episode = episodes.first(where: { $0.audioURL.absoluteString == bookmark.episodeURL })
        else { return }
        
        // On ne relance pas automatiquement la lecture — on prépare juste l'état
        self.currentEpisodeTitle = bookmark.episodeTitle
        self.currentTime = bookmark.position
        self.currentlyPlayingID = episode.id
        
        print("📌 [Resume] Bookmark trouvé : \(bookmark.episodeTitle) à \(Int(bookmark.position))s")
    }
    
    /// Reprend la lecture depuis le bookmark (appele par l'UI quand l'utilisateur tape "Reprendre")
    func resumeFromBookmark() {
        guard let id = currentlyPlayingID,
              let episode = episodes.first(where: { $0.id == id }) else { return }

        let savedPosition = currentTime
        print("[Resume] Reprise de \(episode.title) a \(Int(savedPosition))s")

        // Forcer la reconstruction du player (il est probablement mort)
        cleanupObservers()
        player = nil
        currentlyPlayingID = nil
        togglePlay(episode: episode)

        // Seek une fois le buffer pret
        seekWhenReady(to: savedPosition)
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - LECTURE AVEC TIMELINE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func togglePlay(episode: PodcastEpisode) {
        setupAudioSession()
        
        // Si c'est le meme episode → toggle pause/play
        if currentlyPlayingID == episode.id {
            if isPlaying {
                player?.pause()
                isPlaying = false
                savePlaybackPosition()
                disableWakeLock()
                return
            }

            // Verifier que le player est encore vivant et utilisable
            let playerAlive = player != nil
                && player?.currentItem != nil
                && player?.currentItem?.status == .readyToPlay

            if playerAlive {
                // Player encore bon → simple resume
                player?.play()
                player?.rate = playbackRate
                isPlaying = true
                setupAudioSession()
                print("[Play] Resume simple (player vivant)")
                return
            }

            // Player mort (iOS l'a kill en background) → reconstruire depuis la position sauvegardee
            print("[Play] Player mort apres background, reconstruction a \(Int(currentTime))s...")
            let savedPosition = currentTime
            cleanupObservers()
            currentlyPlayingID = nil // Force togglePlay a creer un nouveau player
            togglePlay(episode: episode)
            // Seek a la position sauvegardee une fois le buffer pret
            seekWhenReady(to: savedPosition)
            return
        }
        
        // ✅ Sauvegarde de l'ancien épisode avant de changer
        savePlaybackPosition()
        
        // Nouvel épisode → on remplace
        cleanupObservers()
        
        self.currentEpisodeTitle = episode.title
        self.currentTime = 0
        self.duration = 0
        self.isBuffering = true
        self.saveCounter = 0

        // Cache agressif : lecture locale si deja telecharge, sinon stream + download en fond
        let isCached = AudioCacheManager.shared.isCached(episode.audioURL)
        let playURL = AudioCacheManager.shared.playableURL(for: episode.audioURL)
        print("[Play] Episode: \(episode.title)")
        print("[Play] URL originale: \(episode.audioURL)")
        print("[Play] Cache: \(isCached ? "OUI (local)" : "NON (stream)")")
        print("[Play] URL lecture: \(playURL)")
        let playerItem = AVPlayerItem(url: playURL)
        
        // Observer : statut du buffer
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let dur = item.duration.seconds
            let errMsg = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.isBuffering = false
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                    self.setupNowPlaying()
                case .failed:
                    self.isBuffering = false
                    print("❌ [Audio] Échec : \(errMsg ?? "inconnu")")
                default:
                    break
                }
            }
        }
        
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
        currentlyPlayingID = episode.id
        
        // Observer périodique : timeline + sauvegarde position
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                guard let self, !self.isSeeking else { return }
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                if let currentItem = self.player?.currentItem {
                    let itemDur = currentItem.duration.seconds
                    if self.duration == 0 && itemDur.isFinite && itemDur > 0 {
                        self.duration = itemDur
                    }
                    
                    // ✅ MARQUAGE AUTOMATIQUE À 90% DE L'ÉPISODE
                    // Si l'utilisateur arrive à 90%, on considère qu'il a terminé
                    if itemDur > 0 && seconds / itemDur >= 0.9 {
                        if let id = self.currentlyPlayingID,
                           let ep = self.episodes.first(where: { $0.id == id }),
                           !self.isEpisodePlayed(episode: ep) {
                            print("✅ [Auto-Mark] Épisode marqué comme lu à 90%")
                            self.markAsPlayed(episode: ep)
                        }
                    }
                }
                
                // ✅ Sauvegarde toutes les ~10 secondes (0.5s × 20 ticks)
                self.saveCounter += 1
                if self.saveCounter >= 20 {
                    self.saveCounter = 0
                    self.savePlaybackPosition()
                }
            }
        }
        
        // Observer : fin de l'épisode
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                // ✅ MARQUER L'ÉPISODE COMME TERMINÉ
                if let currentID = self.currentlyPlayingID,
                   let completedEpisode = self.episodes.first(where: { $0.id == currentID }) {
                    self.markAsPlayed(episode: completedEpisode)
                }
                
                // ✅ Épisode terminé → on supprime le bookmark
                UserDefaults.standard.removeObject(forKey: self.resumeKey)
                self.playNextEpisode()
            }
        }
        
        // Commandes Lock Screen / Dynamic Island
        setupRemoteCommands()
    }
    
    // MARK: - Seek (scrubber)
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSeeking = false
                self?.updateNowPlayingTime()
            }
        }
    }
    
    // MARK: - Skip ±15s
    func skipForward(_ seconds: Double = 15) {
        let target = min(currentTime + seconds, duration)
        currentTime = target
        seek(to: target)
    }
    
    func skipBackward(_ seconds: Double = 15) {
        let target = max(currentTime - seconds, 0)
        currentTime = target
        seek(to: target)
    }
    
    // MARK: - Vitesse de Lecture
    func cyclePlaybackRate() {
        let rates: [Float] = [1.0, 1.25, 1.5, 2.0]
        if let currentIndex = rates.firstIndex(of: playbackRate) {
            playbackRate = rates[(currentIndex + 1) % rates.count]
        } else {
            playbackRate = 1.0
        }
        if isPlaying {
            player?.rate = playbackRate
        }
    }
    
    // MARK: - Épisode Suivant / Précédent
    func playNextEpisode() {
        guard let currentID = currentlyPlayingID,
              let currentIndex = episodes.firstIndex(where: { $0.id == currentID }),
              currentIndex + 1 < episodes.count else { return }
        togglePlay(episode: episodes[currentIndex + 1])
    }
    
    func playPreviousEpisode() {
        if currentTime > 3 {
            seek(to: 0)
            currentTime = 0
            return
        }
        guard let currentID = currentlyPlayingID,
              let currentIndex = episodes.firstIndex(where: { $0.id == currentID }),
              currentIndex - 1 >= 0 else { return }
        togglePlay(episode: episodes[currentIndex - 1])
    }
    
    // MARK: - Nettoyage
    // Seek robuste : attend que le player soit pret avant de seek
    private func seekWhenReady(to seconds: Double) {
        // Polling : verifie toutes les 200ms si le player est pret
        func attemptSeek(remaining: Int) {
            guard remaining > 0 else {
                print("[SeekWhenReady] Timeout, seek force a \(Int(seconds))s")
                self.seek(to: seconds)
                self.currentTime = seconds
                return
            }

            if player?.currentItem?.status == .readyToPlay {
                print("[SeekWhenReady] Player pret, seek a \(Int(seconds))s")
                self.seek(to: seconds)
                self.currentTime = seconds
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.seekWhenReady(to: seconds, remaining: remaining - 1)
                }
            }
        }
        attemptSeek(remaining: 25) // 25 x 200ms = 5s max
    }

    // Surcharge pour l'appel initial
    private func seekWhenReady(to seconds: Double, remaining: Int) {
        guard remaining > 0 else {
            print("[SeekWhenReady] Timeout, seek force a \(Int(seconds))s")
            self.seek(to: seconds)
            self.currentTime = seconds
            return
        }

        if player?.currentItem?.status == .readyToPlay {
            print("[SeekWhenReady] Player pret, seek a \(Int(seconds))s")
            self.seek(to: seconds)
            self.currentTime = seconds
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.seekWhenReady(to: seconds, remaining: remaining - 1)
            }
        }
    }

    private func cleanupObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    // MARK: - Now Playing (Lock Screen + Dynamic Island)
    private func setupNowPlaying() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentEpisodeTitle
        info[MPMediaItemPropertyArtist] = podcastAuthor
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func updateNowPlayingTime() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.play()
                self?.player?.rate = self?.playbackRate ?? 1.0
                self?.isPlaying = true
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player?.pause()
                self?.isPlaying = false
                self?.savePlaybackPosition()
            }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipForward() }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.skipBackward() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = posEvent.positionTime
            Task { @MainActor [weak self] in self?.seek(to: position) }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.playNextEpisode() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.playPreviousEpisode() }
            return .success
        }
    }
}



