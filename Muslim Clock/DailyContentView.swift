import SwiftUI
import AVFoundation
import Combine

struct DailyContentView: View {
    @EnvironmentObject private var service: DailyContentService
    @StateObject private var ayahPlayer = AyahAudioPlayerManager()
    
    @State private var showAyahArabic = false
    @State private var showHadithArabic = false
    
    private var isFriday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 6
    }

    var body: some View {
        VStack(spacing: 20) {

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // BANNIERE VENDREDI — Salawat
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            if isFriday {
                FridaySalawatBanner()
            }

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // CARTE CORAN
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 14))
                    Text("Verset")
                        .font(.caption.bold())
                    
                    Spacer(minLength: 4)
                    
                    // 🎧 BOUTON LECTURE AUDIO
                    if let audioURL = service.dailyAyahAudioURL {
                        Button {
                            ayahPlayer.togglePlay(url: audioURL)
                        } label: {
                            HStack(spacing: 4) {
                                if ayahPlayer.isLoading {
                                    ProgressView().tint(.white)
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: ayahPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                
                                Text(ayahPlayer.isPlaying ? String(localized: "Pause") : String(localized: "Lire"))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(ayahPlayer.isPlaying ? Color.orange.gradient : Color.indigo.gradient)
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                        }
                        .disabled(ayahPlayer.isLoading)
                    }
                    
                    // 🔄 BOUTON RAFRAÎCHIR
                    Button {
                        Task {
                            await service.fetchRandomQuranVerse()
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .rotationEffect(Angle(degrees: service.isFetchingQuran ? 360 : 0))
                            .animation(
                                service.isFetchingQuran ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: service.isFetchingQuran
                            )
                    }
                    .disabled(service.isFetchingQuran)
                    
                    // TOGGLE LANGUE
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAyahArabic.toggle()
                        }
                    } label: {
                        Text(verbatim: showAyahArabic ? "FR" : "عربي")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    // PARTAGE
                    ShareLink(item: "\(service.dailyAyah)\n\n\(service.dailyAyahArabic)\n\n— \(service.dailyAyahSource)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.indigo)
                
                if showAyahArabic {
                    Text(verbatim: service.dailyAyahArabic)
                        .font(.system(size: 22, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(verbatim: service.dailyAyah)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Text(verbatim: "— \(service.dailyAyahSource)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // ✅ iOS 18 standard
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4) // Ombre subtile
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // CARTE HADITH
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "quote.opening")
                    Text("Hadith du moment")
                        .font(.caption.bold())
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showHadithArabic.toggle()
                        }
                    } label: {
                        Text(verbatim: showHadithArabic ? "FR" : "عربي")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    ShareLink(item: "\(service.dailyHadith)\n\n\(service.dailyHadithArabic)\n\n— \(service.dailyHadithSource)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.teal)
                
                if showHadithArabic {
                    Text(verbatim: service.dailyHadithArabic)
                        .font(.system(size: 22, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(verbatim: service.dailyHadith)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Text(verbatim: "— \(service.dailyHadithSource)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // ✅ iOS 18 standard
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4) // Ombre subtile
        }
        .redacted(reason: service.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.2), value: service.isLoading)
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // CARTE AUDIO / PODCAST
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        PodcastCarouselView()
            .padding(.top, 10)
    }
}

// MARK: - Banniere Vendredi — Salawat sur le Prophete

struct FridaySalawatBanner: View {
    var body: some View {
        VStack(spacing: 10) {
            // Titre
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("Jour du Vendredi")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.green)

            // Salawat en arabe
            Text(verbatim: "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ")
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            // Traduction
            Text("O Allah, accorde Ta priere et Ton salut a notre Prophete Muhammad")
                .font(.system(size: 13, design: .serif))
                .italic()
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))

            // Hadith sur le merite
            VStack(spacing: 4) {
                Text(verbatim: "« Multipliez la priere sur moi le jour du vendredi, car vos prieres me sont presentees. »")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.7))

                Text(verbatim: "— Sunan Abu Dawud 1047")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green.opacity(0.7))
            }

            // Rappels du vendredi
            HStack(spacing: 16) {
                FridayReminderChip(icon: "book.fill", text: "Sourate Al-Kahf")
                FridayReminderChip(icon: "hands.sparkles.fill", text: "Heure exaucee")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FridayReminderChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.green.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Mini rappel Salawat (tab Salat)

struct FridaySalawatMiniReminder: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)

            Text(verbatim: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ ﷺ")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text("Vendredi")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.green.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
        .clipShape(Capsule())
    }
}

// 🎧 NOUVEAU GESTIONNAIRE AUDIO (A mettre à la fin du fichier ou dans un fichier séparé)
@MainActor
class AyahAudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    
    private func setupAudioSession() {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("❌ [Audio Ayah] AVAudioSession : \(error.localizedDescription)")
            }
        }
    
    /// Alterne entre lecture et pause. Charge l'URL si nécessaire.
    func togglePlay(url: URL) {
        setupAudioSession()
        // 1. Si on a déjà un player et que l'URL est la même
        if let currentItem = playerItem, currentItem.asset is AVURLAsset, (currentItem.asset as! AVURLAsset).url == url {
            if player?.timeControlStatus == .playing {
                player?.pause()
                isPlaying = false
            } else {
                player?.play()
                isPlaying = true
            }
            return
        }
        
        // 2. Sinon, on doit charger une nouvelle URL
        stop() // Nettoyage de l'ancien
        
        self.isLoading = true
        self.playerItem = AVPlayerItem(url: url)
        self.player = AVPlayer(playerItem: playerItem)
        
        // 👀 Écoute des états du player pour l'UI
        
        // A. Écoute la fin de lecture
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                // Revient au début et reset l'UI
                self?.player?.seek(to: .zero)
                self?.isPlaying = false
            }
            .store(in: &cancellables)
        
        // B. Écoute le statut de chargement (KVO)
        playerItem?.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.isLoading = false
                    // Lancement automatique dès que prêt
                    self?.player?.play()
                    self?.isPlaying = true
                } else if status == .failed {
                    self?.isLoading = false
                    print("❌ Échec du chargement audio")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Arrête complètement la lecture
    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        isLoading = false
        cancellables.removeAll()
    }
}

// ═══════════════════════════════════════════════════
// PODCAST CAROUSEL — Design "Liquid Glass" Premium
// ═══════════════════════════════════════════════════

struct PodcastCarouselView: View {
    @EnvironmentObject var podcastManager: PodcastManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // ── 1. EN-TÊTE PREMIUM ──
            HStack(spacing: 12) {
                // Pochette avec effet Glow
                ZStack {
                    // Ombre lumineuse (Glow)
                    if podcastManager.podcastArtworkURL != nil {
                        Color.orange.opacity(0.4)
                            .frame(width: 64, height: 64)
                            .blur(radius: 15)
                    }
                    
                    AsyncImage(url: podcastManager.podcastArtworkURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 64, height: 64)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        case .failure:
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                                .frame(width: 64, height: 64)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        @unknown default: EmptyView()
                        }
                    }
                }
                .frame(width: 64, height: 64) // ✅ FIXE LA TAILLE
                
                // ── MENU DÉROULANT (avec flex limité) ──
                Menu {
                    ForEach(Array(podcastManager.curatedSeriesList.enumerated()), id: \.element.id) { index, series in
                        Button {
                            podcastManager.changeSeries(to: index)
                        } label: {
                            if podcastManager.activeSeriesIndex == index {
                                Label(series.name, systemImage: "checkmark")
                            } else {
                                Text(verbatim: series.name)
                            }
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("SÉRIE AUDIO")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.orange.gradient)
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                        
                        Text(verbatim: podcastManager.podcastTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2) // ✅ LIMITE À 2 LIGNES
                        
                        Text(verbatim: podcastManager.podcastAuthor)
                            .font(.system(size: 13))
                            .foregroundStyle(.orange.gradient)
                            .lineLimit(1) // ✅ LIMITE À 1 LIGNE
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // ✅ PREND LA LARGEUR DISPO
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // ── 2. PROGRESSION GLOWING ──
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Progression")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange.gradient)
                    Spacer()
                    
                    // ✅ AFFICHAGE DYNAMIQUE DU NOMBRE D'ÉPISODES LUS
                    let playedCount = podcastManager.episodes.filter { podcastManager.isEpisodePlayed(episode: $0) }.count
                    let totalCount = podcastManager.episodes.count
                    
                    HStack(spacing: 4) {
                        Text(verbatim: "\(playedCount)/\(totalCount)")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(.indigo.opacity(0.7))
                        
                        Text(podcastManager.seriesProgress, format: .percent.precision(.fractionLength(0)))
                            .font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Fond de la piste
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 6)
                            // Bordure intérieure sombre pour le relief
                            .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
                        
                        // Jauge de remplissage avec Lueur
                        Capsule()
                            .fill(LinearGradient(colors: [.orange.opacity(0.6), .orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geometry.size.width * CGFloat(podcastManager.seriesProgress)), height: 6)
                            .shadow(color: .orange.opacity(0.6), radius: 4, x: 0, y: 0) // Lueur
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 20)
            
            // ── 3. CAROUSEL LIQUID GLASS ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Marge initiale pour aligner avec le reste du design
                    Spacer().frame(width: 4)
                    
                    ForEach(podcastManager.episodes) { episode in
                        let isPlayed = podcastManager.isEpisodePlayed(episode: episode)
                        let isCurrent = podcastManager.currentlyPlayingID == episode.id
                        
                        // CARTE ÉPISODE
                        VStack(alignment: .trailing, spacing: 0) {
                            
                            // Haut : Titre aligné à droite
                            Text(verbatim: episode.title)
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .multilineTextAlignment(.trailing)
                                .lineLimit(3)
                                .foregroundColor(isPlayed ? .white.opacity(0.4) : .white)
                                .frame(maxWidth: .infinity, alignment: .topTrailing)
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                            
                            Spacer()
                            
                            // Bas : Contrôles (Play à gauche, Check à droite)
                            HStack {
                                // Bouton Play Magique
                                Button {
                                    podcastManager.togglePlay(episode: episode)
                                } label: {
                                    ZStack {
                                        if isCurrent && podcastManager.isBuffering {
                                            ProgressView().tint(.orange)
                                                .frame(width: 44, height: 44)
                                        } else {
                                            Circle()
                                                .fill(isCurrent ? Color.orange : Color.white.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                                .shadow(color: isCurrent ? .orange.opacity(0.4) : .clear, radius: 8, y: 4)
                                            
                                            Image(systemName: isCurrent && podcastManager.isPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(isCurrent ? .white : (isPlayed ? .white.opacity(0.3) : .white))
                                                // Léger décalage visuel pour le triangle "play"
                                                .offset(x: isCurrent && podcastManager.isPlaying ? 0 : 2)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // ✅ BOUTON MENU POUR MARQUER COMME LU
                                if !isPlayed {
                                    Menu {
                                        Button {
                                            podcastManager.markAsPlayed(episode: episode)
                                        } label: {
                                            Label("Marquer comme lu", systemImage: "checkmark.circle")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .foregroundColor(.white.opacity(0.3))
                                            .font(.system(size: 20))
                                    }
                                }
                                
                                // Checkmark de validation
                                if isPlayed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green.opacity(0.8))
                                        .font(.system(size: 22))
                                        .background(Circle().fill(Color.black).frame(width: 14, height: 14)) // Masque le filigranne derrière l'icône
                                }
                            }
                            .padding(.bottom, 16)
                            .padding(.horizontal, 16)
                        }
                        .frame(width: 200, height: 170)
                        // LE SECRET DU LIQUID GLASS :
                        .background(
                            isPlayed ? .ultraThinMaterial : .regularMaterial
                        )
                        // Bordure lumineuse dynamique
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous) // ✅ iOS 18 standard
                                .stroke(
                                    LinearGradient(
                                        colors: isCurrent ? [.orange, .orange.opacity(0.2)] : [.white.opacity(0.3), .white.opacity(0.01)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isCurrent ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // ✅ iOS 18 standard
                        // Ombre de la carte
                        .shadow(color: Color.black.opacity(isCurrent ? 0.3 : 0.15), radius: 10, x: 0, y: 5)
                        // Animation au clic / changement d'état
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrent)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPlayed)
                    }
                    
                    // Marge finale
                    Spacer().frame(width: 4)
                }
            }
        }
        .task {
            await podcastManager.loadSmartPodcast()
        }
    }
}
