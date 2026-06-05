import SwiftUI
import StoreKit

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
                Text(verbatim: hijriAr)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange.opacity(0.9))
                    .environment(\.layoutDirection, .rightToLeft)
                
                Text(verbatim: hijriFr)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        } else {
            // Mode complet : grégorien à gauche, hégirien arabe à droite
            VStack(spacing: 2) {
                HStack(alignment: .bottom) {
                    Text(verbatim: gregorianFr)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                    
                    Text(verbatim: hijriAr)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange.opacity(0.9))
                        .environment(\.layoutDirection, .rightToLeft)
                }
                
                HStack {
                    Text(verbatim: hijriFr)
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

// MARK: - Bannière réseau (offline / reconnecté)

private struct NetworkStatusBanner: View {
    let isConnected: Bool
    @State private var showReconnected = false

    var body: some View {
        Group {
            if !isConnected {
                offlinePill
            } else if showReconnected {
                reconnectedPill
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isConnected)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showReconnected)
        .onChange(of: isConnected) { _, nowConnected in
            if nowConnected {
                withAnimation { showReconnected = true }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { showReconnected = false }
                }
            }
        }
    }

    private var offlinePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash").font(.system(size: 11, weight: .bold))
            Text("Hors ligne").font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("· météo et audio en cache")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(
            Capsule().fill(Color.red.opacity(0.88))
                .shadow(color: .red.opacity(0.3), radius: 6, y: 3)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var reconnectedPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi").font(.system(size: 11, weight: .bold))
            Text("Reconnecté · Actualisation…")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(
            Capsule().fill(Color.green.opacity(0.88))
                .shadow(color: .green.opacity(0.3), radius: 6, y: 3)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Main View

struct MainView: View {
    @StateObject var manager = CompassManager()
    @StateObject var prayerVM = PrayerTimesViewModel()
    @StateObject var podcastManager = PodcastManager()
    @StateObject var weatherVM = WeatherViewModel()
    @StateObject private var updateChecker = AppUpdateChecker()
    @StateObject private var dailyContentService = DailyContentService()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    // Variables pour la détection du changement de saison
    @AppStorage("lastSmartSetupDate") private var lastSmartSetupDate: Double = 0
    @AppStorage("lastDSTState") private var lastDSTState: Bool = TimeZone.current.isDaylightSavingTime(for: Date())
    #if DEBUG
    /// Observé uniquement pour déclencher un redraw quand le panneau debug change la saison
    @AppStorage("debugSeasonDate") private var _debugSeasonDate: Double = 0
    #endif
    @State private var showSeasonalUpdatePopup = false
    
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase

    // ✨ NOUVEAU : État pour l'overlay Adhan
    @State private var showAdhanOverlay = false
    @State private var adhanPrayerName = ""
    @State private var adhanPrayerTime = Date()

    /// Pop-up "Quoi de neuf" — affichée une fois après chaque mise à jour de version.
    /// Compare la version actuelle du Bundle à la dernière vue par l'utilisateur.
    @State private var showWhatsNew = false
    @AppStorage("lastSeenAppVersion") private var lastSeenAppVersion: String = ""

    /// Sheet Adhkar déclenchée par le Control Widget "Adhkar du moment".
    /// Indépendant du bouton AdhkarQuickAccessButton qui a son propre state local.
    @State private var showAdhkarFromControl = false

    /// Sheet QuranLibrary déclenchée par le Control Widget "Lire le Coran".
    @State private var showQuranFromControl = false
    
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
                                        .font(.system(size: 65, weight: .semibold, design: .monospaced))
                                        .monospacedDigit()
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .padding(.top, 20)
                                        .foregroundColor(.white)
                                }

                                // ✅ DATE HEADER — juste sous l'horloge
                                WidgetDateHeader(date: .now)
                                    .padding(.top, -8)

                                GPSRelocationIndicator()
                                    .padding(.top, -4)

                                SeasonBannerView(season: currentSeason)
                                    .padding(.top, -6)

                                // Rappel Salawat le vendredi (compact)
                                if Calendar.current.component(.weekday, from: Date()) == 6 {
                                    FridaySalawatMiniReminder()
                                        .padding(.top, -6)
                                }

                                VStack(spacing: 20) {
                                    HStack {
                                        WeatherMiniWidget(location: manager.userLocation, cityName: manager.cityName)
                                        NextPrayerWidget()
                                    }
                                    CurrentPrayerGaugeView()
                                    PrayerListView()
                                    AdhkarQuickAccessButton()
                                    RawatibCardView(prayerContext: {
                                        if prayerVM.currentPrayerWindow != .none {
                                            if prayerVM.currentPrayerWindow == .dhuhr && prayerVM.isFridayJumuah {
                                                return "Jumu'ah"
                                            }
                                            return prayerVM.currentPrayerWindow.rawValue
                                        }
                                        return prayerVM.nextPrayerName
                                    }())
                                    MoonWidgetView(date: .now)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .containerRelativeFrame(.horizontal)
                        }
                        .refreshable {
                            if let loc = manager.userLocation {
                                await weatherVM.forceRefresh(for: loc)
                            }
                        }
                    }
                }
                .tabItem {
                    Label("Salat", systemImage: "timer")  // Proper noun
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
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                        .refreshable {
                            await dailyContentService.fetchDailyContent()
                            await podcastManager.retryLoadIfNeeded()
                        }
                    }
                }
                .tabItem {
                    Label("Rappel", systemImage: "book.fill")  // Translatable
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
            .tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
            // ✨ FEEDBACK HAPTIQUE AU CHANGEMENT DE TAB
            .sensoryFeedback(.selection, trigger: selectedTab)
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // MINI PLAYER FLOTTANT
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            .tabViewBottomAccessory(isEnabled: podcastManager.currentlyPlayingID != nil ) {
                MiniPlayerBar(manager: podcastManager, tintColor: tabColor)
            }
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // FULL PLAYER — sheet gérée ici, PAS dans l'accessory
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                .sheet(isPresented: $podcastManager.showFullPlayer) {
                    FullPlayerView(manager: podcastManager, tintColor: tabColor)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(.ultraThinMaterial)
                }
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ✨ POP-UP DE FÉLICITATIONS + REVIEW
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                .alert("🎉 Série terminée !", isPresented: $podcastManager.showReviewPopup) {
                    let remainingReviews = remainingReviewCount()
                    
                    if remainingReviews > 0 {
                        Button("⭐ Donner mon avis") {
                            requestReviewIfNeeded()
                        }
                        Button("Plus tard") { }
                    } else {
                        Button("OK") { }
                    }
                } message: {
                    let remainingReviews = remainingReviewCount()
                    
                    if remainingReviews > 0 {
                        Text("Félicitations ! Vous avez terminé la série « \(podcastManager.completedSeriesName) ».\n\nSi vous aimez Muslim Clock, un avis sur l'App Store nous aiderait énormément ! 🌙")
                    } else {
                        Text("Félicitations ! Vous avez terminé la série « \(podcastManager.completedSeriesName) » ! Continuez votre apprentissage avec la série suivante. 📚")
                    }
                }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 4) {
                if updateChecker.updateAvailable {
                    AppUpdateBannerView(checker: updateChecker)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .overlay(alignment: .top) {
            NetworkStatusBanner(isConnected: networkMonitor.isConnected)
                .padding(.top, updateChecker.updateAvailable ? 60 : 12)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: updateChecker.updateAvailable)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: networkMonitor.isConnected)
        .onChange(of: scenePhase, initial: false) {
            if scenePhase == .background || scenePhase == .inactive {
                podcastManager.savePlaybackPositionNow()
            }
        }
        // Routage des Control Widgets (Centre de Contrôle / Lock Screen / bouton Action).
        // Lit la clé `controlDeepLinkTarget` dans l'App Group, route, puis efface la clé.
        // Re-évalue aussi la Live Activity : si on entre dans la fenêtre 30 min avant la
        // prochaine prière pendant que l'app passe à .active, on démarre la bannière.
        .onChange(of: scenePhase, initial: true) {
            print("📱 [ScenePhase] phase=\(scenePhase)")
            if scenePhase == .active {
                handleControlDeepLink()
                prayerVM.refreshLiveActivity()
            }
        }
        .environmentObject(podcastManager)
        .environmentObject(prayerVM)
        .environmentObject(weatherVM)
        .environmentObject(dailyContentService)
        .task {
            if let loc = manager.userLocation {
                await weatherVM.fetchWeather(for: loc)
            }
            await updateChecker.checkForUpdate()
            await dailyContentService.fetchDailyContent()
        }
        // ── Auto-retry sur retour de connexion ──────────────────────────
        .onReceive(networkMonitor.onReconnect) {
            Task {
                if let loc = manager.userLocation {
                    await weatherVM.forceRefresh(for: loc)
                }
                if dailyContentService.hasNetworkError {
                    await dailyContentService.fetchDailyContent()
                }
                await podcastManager.retryLoadIfNeeded()
                podcastManager.resumeBufferingIfStalled()
            }
        }
        .onChange(of: manager.userLocation) { oldLocation, newLocation in
                    if let loc = newLocation {
                        Task {
                            await weatherVM.fetchWeather(for: loc)
                        }
                    }
                }
        .onAppear {
                    checkSeasonalChanges()
                    checkWhatsNew()
                }
                .sheet(isPresented: $showSeasonalUpdatePopup) {
                    SeasonalUpdatePopupView(isPresented: $showSeasonalUpdatePopup, lastSetupTimestamp: $lastSmartSetupDate)
                        .presentationDetents([.fraction(0.6)])
                        .presentationBackground(.ultraThinMaterial)
                        .presentationCornerRadius(30)
                }
                .sheet(isPresented: $showWhatsNew) {
                    WhatsNewView()
                        .presentationDetents([.large])
                        .presentationCornerRadius(30)
                }
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ✨ OVERLAY ADHAN (plein écran)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                .overlay {
                    if showAdhanOverlay {
                        AdhanOverlayView(
                            prayerName: adhanPrayerName,
                            prayerTime: adhanPrayerTime
                        ) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                showAdhanOverlay = false
                                
                                // ✅ BONUS : Reprendre le podcast automatiquement
                                if podcastManager.currentlyPlayingID != nil && !podcastManager.isPlaying {
                                    if let id = podcastManager.currentlyPlayingID,
                                       let ep = podcastManager.episodes.first(where: { $0.id == id }) {
                                        Task {
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            podcastManager.togglePlay(episode: ep)
                                        }
                                    }
                                }
                            }
                        }
                        .zIndex(1000) // Au-dessus de tout
                    }
                }
                // Sheet Adhkar déclenchée par le Control Widget "Adhkar du moment".
                .sheet(isPresented: $showAdhkarFromControl) {
                    ZStack {
                        LinearGradient(
                            colors: [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                        AdhkarView()
                    }
                    .environmentObject(prayerVM)
                    .presentationDragIndicator(.visible)
                }
                // Sheet Quran Library déclenchée par le Control Widget "Lire le Coran".
                .sheet(isPresented: $showQuranFromControl) {
                    QuranLibraryView()
                }
                // Notif Quran tapée → switch automatique vers tab Rappel (où la card vit).
                .onReceive(NotificationCenter.default.publisher(for: .quranReadingTapped)) { _ in
                    selectedTab = 1
                }
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // DÉCLENCHEUR D'ADHAN (écoute les notifications)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AdhanTriggered"))) { notification in
                    guard let userInfo = notification.userInfo,
                          let prayerName = userInfo["prayerName"] as? String,
                          let prayerTime = userInfo["prayerTime"] as? Date else { return }
                    
                    // ✅ Pause automatique du podcast pendant l'Adhan
                    if podcastManager.isPlaying {
                        if let id = podcastManager.currentlyPlayingID,
                           let ep = podcastManager.episodes.first(where: { $0.id == id }) {
                            podcastManager.togglePlay(episode: ep)
                        }
                    }
                    
                    // ✅ Affichage de l'overlay
                    withAnimation(.easeIn(duration: 0.4)) {
                        self.adhanPrayerName = prayerName
                        self.adhanPrayerTime = prayerTime
                        self.showAdhanOverlay = true
                    }
                }
    }
    /// Lit la clé `controlDeepLinkTarget` écrite par un Control Widget (Qibla / Adhkar)
    /// dans l'App Group, route vers la destination, puis efface la clé.
    ///
    /// Retry intégré : `openAppWhenRun=true` lance l'app en parallèle de l'AppIntent.perform()
    /// du widget. L'app peut passer à `.active` AVANT que la clé soit écrite côté widget.
    /// On retente 3 fois à 250ms d'intervalle pour couvrir cette race condition.
    private func handleControlDeepLink(retryCount: Int = 0) {
        let shared = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
        let target = shared?.string(forKey: "controlDeepLinkTarget")
        let timestamp = shared?.double(forKey: "controlDeepLinkTimestamp") ?? 0
        let ageSeconds = Date().timeIntervalSince1970 - timestamp
        print("🔍 [DeepLink] try=\(retryCount) target=\(target ?? "nil") timestamp=\(timestamp) age=\(String(format: "%.2f", ageSeconds))s")

        if shared == nil {
            print("❌ [DeepLink] UserDefaults(suiteName:) returned nil — App Group inaccessible from app !")
            return
        }

        // Ignore les anciens triggers (> 30s) pour ne pas rejouer un deep-link périmé
        // (ex: utilisateur ouvre l'app normalement après un control widget oublié).
        if let target, ageSeconds <= 30 {
            switch target {
            case "qibla":
                print("✅ [DeepLink] Routing to Qibla tab (selectedTab = 2)")
                selectedTab = 2
            case "adhkar":
                print("✅ [DeepLink] Routing to Adhkar sheet")
                showAdhkarFromControl = true
            case "quran":
                print("✅ [DeepLink] Routing to Quran Library sheet")
                showQuranFromControl = true
            default:
                print("⚠️ [DeepLink] Unknown target: \(target)")
            }
            shared?.removeObject(forKey: "controlDeepLinkTarget")
            shared?.removeObject(forKey: "controlDeepLinkTimestamp")
            print("🧹 [DeepLink] Keys cleared")
            return
        }

        // Pas de target trouvé : retry possible (race condition avec AppIntent.perform du widget).
        if retryCount < 3 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                handleControlDeepLink(retryCount: retryCount + 1)
            }
        } else {
            print("🔍 [DeepLink] No target after 3 retries — likely a normal app open (not from control widget)")
        }
    }

    /// Affiche la sheet « Quoi de neuf » une seule fois après chaque mise à jour de version.
    /// Si `lastSeenAppVersion` est vide (1er lancement après installation), on ne montre pas
    /// la sheet pour ne pas saturer un nouvel utilisateur ; on enregistre juste la version.
    private func checkWhatsNew() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty else { return }

        if lastSeenAppVersion.isEmpty {
            // Première install ou première fois avec ce système → ne pas embêter, juste mémoriser.
            lastSeenAppVersion = currentVersion
            return
        }

        if lastSeenAppVersion != currentVersion {
            showWhatsNew = true
            lastSeenAppVersion = currentVersion
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
