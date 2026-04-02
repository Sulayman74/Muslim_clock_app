import SwiftUI

// MARK: - ═══════════════════════════════════════════════════
// EN-TÊTE DES DATES (Grégorien & Hégirien)
// Réutilisable sur les 3 écrans
// ═══════════════════════════════════════════════════════════

struct WidgetDateHeader: View {
    var date: Date
    
    /// Style compact pour la Qibla (juste Hégirien arabe + français, pas de grégorien)
    var compact: Bool = false
    
    var gregorianFr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    var hijriFr: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var hijriAr: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var body: some View {
        if compact {
            // Mode compact : centré, juste les deux lignes hégiriennes
            VStack(spacing: 3) {
                Text(hijriAr)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange.opacity(0.9))
                    .environment(\.layoutDirection, .rightToLeft)
                
                Text(hijriFr)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        } else {
            // Mode complet : grégorien à gauche, hégirien arabe à droite
            VStack(spacing: 2) {
                HStack(alignment: .bottom) {
                    Text(gregorianFr)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Text(hijriAr)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange.opacity(0.9))
                        .environment(\.layoutDirection, .rightToLeft)
                }
                
                HStack {
                    Text(hijriFr)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// MAIN VIEW
// ═══════════════════════════════════════════════════════════

struct MainView: View {
    @StateObject var manager = CompassManager()
    @StateObject var prayerVM = PrayerTimesViewModel()
    @StateObject var podcastManager = PodcastManager()
    @StateObject var weatherVM = WeatherViewModel()
    // Variables pour la détection du changement de saison
    @AppStorage("lastSmartSetupDate") private var lastSmartSetupDate: Double = 0
    @AppStorage("lastDSTState") private var lastDSTState: Bool = TimeZone.current.isDaylightSavingTime(for: Date())
    @State private var showSeasonalUpdatePopup = false
    
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    /// Saison islamique courante (recalculée à chaque apparition)
        private var currentSeason: IslamicSeasonInfo {
            IslamicSeasonInfo.current()
        }
    private var tabColor: Color {
            switch selectedTab {
            case 0: return .red      // Tab Salat
            case 1: return .orange   // Tab Rappel
            case 2: return .teal     // Tab Qibla
            case 3: return .blue     // Tab Réglages
            default: return .white
            }
        }
    var body: some View {
            
            TabView(selection: $selectedTab) {
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ONGLET 1 : SALAT
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                NavigationStack {
                    ZStack {
                        CosmicBackground(season: currentSeason)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                // L'horloge
                                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                    Text(context.date.formatted(.dateTime.hour().minute()))
                                        .font(.system(size: 65, weight: .thin, design: .rounded))
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .padding(.top, 60)
                                        .foregroundColor(.white)
                                }
                                
                                // ✅ DATE HEADER — juste sous l'horloge
                                WidgetDateHeader(date: .now)
                                    .padding(.top, -8)
                                
                                SeasonBannerView(season: currentSeason)
                                .padding(.top, -6)
                                
                                VStack(spacing: 20) {
                                    HStack {
                                        WeatherMiniWidget(location: manager.userLocation, cityName: manager.cityName)
                                        NextPrayerWidget()
                                    }
                                    PrayerListView()
                                    AdhkarQuickAccessButton()
                                    // Elle s'alimente directement avec la prochaine prière prévue
                                    RawatibCardView(nextPrayer: prayerVM.nextPrayerName)
                                    MoonWidgetView(moonSymbol: weatherVM.moonSymbol, date: .now)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .containerRelativeFrame(.horizontal)
                        }
                    }
                }
                .tabItem {
                    Label("Salat", systemImage: "timer")
                }
                .tag(0)
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ONGLET 2 : RAPPEL
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                NavigationStack {
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.05), Color(red: 0.2, green: 0.1, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .ignoresSafeArea()
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                // ✅ DATE HEADER — en haut de l'écran Rappel
                                WidgetDateHeader(date: .now)
                                    .padding(.top, 20)
                                
                                SeasonBannerView(season: currentSeason)
                                .padding(.top, -6)
                                
                                DailyContentView()
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                    }
                }
                .tabItem {
                    Label("Rappel", systemImage: "book.fill")
                }
                .tag(1)
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ONGLET 3 : QIBLA
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                ZStack{
                    CosmicBackground(season: currentSeason)
                    QiblaView(manager: manager)
                }
                    .tabItem {
                        Label("Qiblah", systemImage: "safari.fill")
                    }
                    .tag(2)
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ONGLET 4 : RÉGLAGES & INFOS
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                SettingsView()
                    .tabItem {
                        Label("Réglages", systemImage: "gearshape.fill")
                    }
                    .tag(3)
                    .foregroundColor(.primary)
            }
            .tint(tabColor)
            .symbolEffect(.bounce.up.byLayer, value: selectedTab)
            .tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // MINI PLAYER FLOTTANT
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            .tabViewBottomAccessory(isEnabled: podcastManager.currentlyPlayingID != nil ) {
                MiniPlayerBar(manager: podcastManager)
            }
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // FULL PLAYER — sheet gérée ici, PAS dans l'accessory
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                .sheet(isPresented: $podcastManager.showFullPlayer) {
                    FullPlayerView(manager: podcastManager)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.ultraThinMaterial)
                }
        .onChange(of: scenePhase, initial: false) {
            if scenePhase == .background || scenePhase == .inactive {
                podcastManager.savePlaybackPositionNow()
            }
        }
        .environmentObject(podcastManager)
        .environmentObject(prayerVM)
        .task {
            if let loc = manager.userLocation {
                await weatherVM.fetchWeather(for: loc)
            }
            
        }
        .onAppear {
                    checkSeasonalChanges()
                }
                .sheet(isPresented: $showSeasonalUpdatePopup) {
                    SeasonalUpdatePopupView(isPresented: $showSeasonalUpdatePopup, lastSetupTimestamp: $lastSmartSetupDate)
                        .presentationDetents([.fraction(0.6)])
                        .presentationBackground(.ultraThinMaterial)
                        .presentationCornerRadius(30)
                }
    }
    private func checkSeasonalChanges() {
            let now = Date()
            let currentDST = TimeZone.current.isDaylightSavingTime(for: now)
            
            // Déclencheur 1 : Changement d'heure (Été / Hiver)
            if currentDST != lastDSTState {
                showSeasonalUpdatePopup = true
                lastDSTState = currentDST
                return
            }
            
            // Déclencheur 2 : Pas de vérification depuis 4 mois (120 jours)
            if lastSmartSetupDate != 0 {
                let lastDate = Date(timeIntervalSince1970: lastSmartSetupDate)
                let daysPassed = Calendar.current.dateComponents([.day], from: lastDate, to: now).day ?? 0
                if daysPassed > 120 {
                    showSeasonalUpdatePopup = true
                    return
                }
            }
        }
}
