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
        }
    
    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [Audio] AVAudioSession : \(error.localizedDescription)")
        }
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
            return
        }
        
        self.podcastTitle = firstResult["collectionName"] as? String ?? "Série de Cours"
        self.podcastAuthor = firstResult["artistName"] as? String ?? "Cheikh"
        if let artworkString = firstResult["artworkUrl600"] as? String {
            self.podcastArtworkURL = URL(string: artworkString)
        }
        
        guard let (xmlData, _) = try? await URLSession.shared.data(from: feedUrl) else { return }
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.parse()
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
    
    // MARK: - JSON Local
    private func loadLocalAudioJSON() {
        guard let url = Bundle.main.url(forResource: "audios", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CuratedAudioSeries].self, from: data) else {
            self.curatedSeriesList = [CuratedAudioSeries(id: "1410186668", name: "Secours", author: "")]
            return
        }
        self.curatedSeriesList = decoded
    }
    
    func loadSmartPodcast() async {
        if curatedSeriesList.isEmpty { loadLocalAudioJSON() }
        if currentSeriesIndex >= curatedSeriesList.count { currentSeriesIndex = 0 }
        let targetSeries = curatedSeriesList[currentSeriesIndex]
        await fetchPodcast(appleID: targetSeries.id)
        calculateProgress()
        
        // ✅ REPRISE AUTOMATIQUE : si on a un bookmark pour cette série, on propose
        restoreBookmarkIfNeeded()
    }
    // MARK: - Changement Manuel de Série
        func changeSeries(to index: Int) {
            guard index >= 0, index < curatedSeriesList.count, index != currentSeriesIndex else { return }
            
            // 1. Arrêt propre de la lecture en cours
            stopAndClose()
            
            // 2. Mise à jour de l'index
            currentSeriesIndex = index
            
            // 3. Réinitialisation de l'interface
            self.episodes = []
            self.seriesProgress = 0.0
            self.podcastTitle = "Chargement..."
            
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
            calculateProgress()
        }
    }
    
    private func calculateProgress() {
        guard !episodes.isEmpty else { return }
        let playedCount = episodes.filter { isEpisodePlayed(episode: $0) }.count
        self.seriesProgress = Double(playedCount) / Double(episodes.count)
        if self.seriesProgress >= 1.0 { moveToNextSeries() }
    }
    
    private func moveToNextSeries() {
        let oldPlayedKey = playedKey
        let oldResumeKey = resumeKey
        
        if currentSeriesIndex < curatedSeriesList.count - 1 {
            currentSeriesIndex += 1
        } else {
            currentSeriesIndex = 0
        }
        
        // ✅ NETTOYAGE : on purge les clés de l'ANCIENNE série
        UserDefaults.standard.removeObject(forKey: oldPlayedKey)
        UserDefaults.standard.removeObject(forKey: oldResumeKey)
        print("🧹 [Storage] Purgé : \(oldPlayedKey) et \(oldResumeKey)")
        
        Task { @MainActor in
                requestReviewIfNeeded()
            }
        
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
    
    /// Reprend la lecture depuis le bookmark (appelé par l'UI quand l'utilisateur tape "Reprendre")
    func resumeFromBookmark() {
        guard let id = currentlyPlayingID,
              let episode = episodes.first(where: { $0.id == id }) else { return }
        
        let savedPosition = currentTime
        togglePlay(episode: episode)
        
        // Attendre que le buffer soit prêt, puis seek à la position sauvegardée
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.seek(to: savedPosition)
            self?.currentTime = savedPosition
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - LECTURE AVEC TIMELINE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func togglePlay(episode: PodcastEpisode) {
        setupAudioSession()
        
        // Si c'est le même épisode → toggle pause/play
        if currentlyPlayingID == episode.id {
            if isPlaying {
                player?.pause()
                isPlaying = false
                // ✅ Sauvegarde immédiate à la pause
                savePlaybackPosition()
            } else {
                player?.play()
                player?.rate = playbackRate
                isPlaying = true
            }
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
        
        let playerItem = AVPlayerItem(url: episode.audioURL)
        
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
@MainActor
func requestReviewIfNeeded() {
    let key = "lastReviewRequestDate"
    let now = Date()
    
    if let lastDate = UserDefaults.standard.object(forKey: key) as? Date {
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: now).day ?? 0
        if days < 30 { return }
    }
    
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
        UserDefaults.standard.set(now, forKey: key)
    }
}
