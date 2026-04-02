import SwiftUI
import Combine

struct DailyContentView: View {
    @StateObject private var service = DailyContentService()
    
    @State private var showAyahArabic = false
    @State private var showHadithArabic = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // CARTE CORAN
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "book.fill")
                    Text("Verset du moment")
                        .font(.caption.bold())
                    
                    Spacer()
                    // 🔄 BOUTON RAFRAÎCHIR
                        Button {
                            Task {
                                // Va chercher un nouveau verset au hasard !
                                await service.fetchRandomQuranVerse()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                // L'icône tourne pendant que la requête réseau s'exécute !
                                .rotationEffect(Angle(degrees: service.isFetchingQuran ? 360 : 0))
                                .animation(
                                    service.isFetchingQuran ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                    value: service.isFetchingQuran
                                )
                        }
                        .disabled(service.isFetchingQuran) // Empêche de spammer le bouton
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAyahArabic.toggle()
                        }
                    } label: {
                        Text(showAyahArabic ? "FR" : "عربي")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    
                    ShareLink(item: "\(service.dailyAyah)\n\n\(service.dailyAyahArabic)\n\n— \(service.dailyAyahSource)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.indigo)
                
                if showAyahArabic {
                    Text(service.dailyAyahArabic)
                        .font(.system(size: 22, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(service.dailyAyah)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Text("— \(service.dailyAyahSource)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .cornerRadius(25)
            .clipped()
            
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
                        Text(showHadithArabic ? "FR" : "عربي")
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
                    Text(service.dailyHadithArabic)
                        .font(.system(size: 22, weight: .regular))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(10)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Text(service.dailyHadith)
                        .font(.system(.body, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
                
                Text("— \(service.dailyHadithSource)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .cornerRadius(25)
            .clipped()
        }
        .redacted(reason: service.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.2), value: service.isLoading)
        .task {
            await service.fetchDailyContent()
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // CARTE AUDIO / PODCAST
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        PodcastCarouselView()
            .padding(.top, 10)
    }
}

// ═══════════════════════════════════════════════════
// PODCAST CAROUSEL — Design "Liquid Glass" Premium
// ═══════════════════════════════════════════════════

struct PodcastCarouselView: View {
    @EnvironmentObject var podcastManager: PodcastManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // ── 1. EN-TÊTE PREMIUM ──
            HStack(spacing: 16) {
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
                                // Bordure "Glass" subtile
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
                
                // ── LA ZONE DE TITRE DEVIENT UN MENU DÉROULANT ──
                                Menu {
                                    // On boucle sur toutes les séries disponibles
                                    ForEach(Array(podcastManager.curatedSeriesList.enumerated()), id: \.element.id) { index, series in
                                        Button {
                                            // Au clic, on change la série !
                                            podcastManager.changeSeries(to: index)
                                        } label: {
                                            // On affiche un checkmark sur la série en cours
                                            if podcastManager.activeSeriesIndex == index {
                                                Label(series.name, systemImage: "checkmark")
                                            } else {
                                                Text(series.name)
                                            }
                                        }
                                    }
                                } label: {
                                    // Le design visuel du bouton (L'ancien VStack)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text("SÉRIE AUDIO")
                                                .font(.system(size: 10, weight: .black, design: .rounded))
                                                .tracking(1.5)
                                                .foregroundStyle(.orange.gradient)
                                            
                                            // Petite icône subtile pour indiquer que c'est un menu
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.orange.opacity(0.8))
                                        }
                                        
                                        Text(podcastManager.podcastTitle)
                                            .font(.system(.title3, design: .rounded).weight(.bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        Text(podcastManager.podcastAuthor)
                                            .font(.subheadline)
                                            .foregroundStyle(.orange.gradient)
                                            .lineLimit(1)
                                    }
                                }
                                // Pour s'assurer que le menu ne déforme pas le bouton
                                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // ── 2. PROGRESSION GLOWING ──
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Progression")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange.gradient)
                    Spacer()
                    Text("\(Int(podcastManager.seriesProgress * 100))%")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundStyle(.orange)
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
                            Text(episode.title)
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
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: isCurrent ? [.orange, .orange.opacity(0.2)] : [.white.opacity(0.3), .white.opacity(0.01)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isCurrent ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
