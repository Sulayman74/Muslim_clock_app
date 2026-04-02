import SwiftUI

struct MainView: View {
    @StateObject var manager = CompassManager()
    @StateObject var prayerVM = PrayerTimesViewModel()
    @StateObject var podcastManager = PodcastManager()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // Sous iOS 26, le TabView prend automatiquement le style Liquid Glass Pilule
            TabView {
                // --- ONGLET 1 : ACCUEIL ---
                NavigationStack {
                    ZStack {
                        LinearGradient(colors: [.blue.opacity(0.4), .indigo.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea()
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 35) {
                                // --- L'HORLOGE NATIVE SYNCHRONISÉE ---
                                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                    Text(context.date.formatted(.dateTime.hour().minute()))
                                        .font(.system(size: 65, weight: .thin, design: .rounded))
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .padding(.top, 60)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 20) {
                                    HStack {
                                        WeatherMiniWidget(location: manager.userLocation, cityName: manager.cityName)
                                        NextPrayerWidget(prayerVM: prayerVM, location: manager.userLocation)
                                    }
                                    DailyContentView()
                                    PrayerListView(prayerVM: prayerVM, location: manager.userLocation)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .containerRelativeFrame(.horizontal)
                            // Padding en bas pour ne pas que le contenu passe sous le mini player
                            .padding(.bottom, podcastManager.currentlyPlayingID != nil ? 90 : 0)
                        }
                        .clipped()
                        .mask(LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.85),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom)
                        )
                    }
                }
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
                
                // --- ONGLET 2 : BOUSSOLE ---
                QiblaView(manager: manager)
                    .tabItem {
                        Label("Qiblah", systemImage: "safari.fill")
                    }
                    .tag(1)
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .environment(\.colorScheme, .dark)
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // MINI PLAYER FLOTTANT — au-dessus de la TabBar
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            MiniPlayerBar(manager: podcastManager)
                .padding(.bottom, 56) // Au-dessus de la pilule TabBar
        }
        // On injecte le podcastManager dans l'environnement
        // pour que PodcastCarouselView puisse l'utiliser
        .environmentObject(podcastManager)
    }
}

#Preview {
    MainView()
}
