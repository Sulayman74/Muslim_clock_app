import SwiftUI
import StoreKit
import UIKit

// MARK: - ═══════════════════════════════════════════════════
// EN-TÊTE DES DATES (Grégorien & Hégirien)
// Réutilisable sur les 3 écrans
// ═══════════════════════════════════════════════════════════

struct WidgetDateHeader: View {
    var date: Date
    
    /// Style compact pour la Qibla (juste Hégirien arabe + français, pas de grégorien)
    var compact: Bool = false
    
    var gregorianFr: String { Self.gregorian(date) }
    var hijriFr: String { Self.hijriFr(date) }
    var hijriAr: String { Self.hijriAr(date) }

    // Formatters partagés avec le chapeau compact de l'onglet Salat. Créés une
    // fois (plus un `DateFormatter` par rendu) ; locale de l'app, pas `fr_FR`.
    private static let gregorianFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
    private static let hijriFrFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = .current
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
    private static let hijriArFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    /// Date grégorienne dans la langue de l'app.
    static func gregorian(_ date: Date) -> String { gregorianFormatter.string(from: date).capitalized }
    /// Date hégirienne (Umm al-Qura) dans la langue de l'app.
    static func hijriFr(_ date: Date) -> String { hijriFrFormatter.string(from: date) }
    /// Date hégirienne en arabe.
    static func hijriAr(_ date: Date) -> String { hijriArFormatter.string(from: date) }
    
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

// MARK: - Chapeau Salat : horloge compacte + dates

/// Horloge 34 pt et dates sur une rangée. `.everyMinute` : un tick par
/// seconde gaspillait 59 redraws/60 ; le schedule tire pile à la frontière de
/// minute et rattrape au retour de background. Les dates suivent la même
/// horloge : elles basculent à minuit sans attendre un autre rendu.
private struct SalatClockHeader: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            HStack(alignment: .firstTextBaseline) {
                Text(context.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel(Text("Il est \(context.date.formatted(date: .omitted, time: .shortened))"))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: WidgetDateHeader.gregorian(context.date))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(verbatim: WidgetDateHeader.hijriAr(context.date))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.orange.opacity(0.9))
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(verbatim: WidgetDateHeader.hijriFr(context.date))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Main View

struct MainView: View {
    // La boussole (`CompassManager`, 60 Hz) vit dans `QiblaView` : observée ici,
    // chaque tick de cap réévaluait tout le body de MainView, cinq onglets compris.
    @StateObject var prayerVM = PrayerTimesViewModel()
    @StateObject var podcastManager = PodcastManager()
    @StateObject var weatherVM = WeatherViewModel()
    @StateObject private var updateChecker = AppUpdateChecker()
    @StateObject private var dailyContentService = DailyContentService()
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var locationManager = SharedLocationManager.shared
    /// Mode voyage (Safar) : intention (toggle) + observation GPS.
    @State private var travel = TravelModeStore()
    @AppStorage(TravelKeys.active) private var travelModeActive = false
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

    /// Si fourni, force le timing de la sheet Adhkar (deep-link notif).
    /// `nil` ⇒ auto-détection (cas Control Widget générique "adhkar").
    @State private var adhkarSheetForcedTiming: AdhkarTiming? = nil

    /// Sheet QuranLibrary déclenchée par le Control Widget "Lire le Coran".
    @State private var showQuranFromControl = false

    // Rappels Adhkar — toggles + offset (mêmes clés que SettingsView).
    @AppStorage("adhkarReminderMorningEnabled") private var adhkarMorningEnabled = false
    @AppStorage("adhkarReminderEveningEnabled") private var adhkarEveningEnabled = false
    @AppStorage("adhkarReminderOffsetMinutes") private var adhkarReminderOffsetMinutes = 5

    // Iqamah delays — lus depuis Settings pour calculer le trigger des rappels.
    @AppStorage(StorageKeys.iqamahFajrDelay) private var iqamahFajrDelay = IqamahDefaults.fajr
    @AppStorage(StorageKeys.iqamahAsrDelay) private var iqamahAsrDelay = IqamahDefaults.asr

    /// Toggle DEBUG : force le jour de la semaine à vendredi pour tester l'UI
    /// Jumu'ah + bienséances vendredi sans attendre le jour réel.
    /// N'a aucun effet en Release (clé ignorée).
    @AppStorage("debugForceFriday") private var debugForceFriday = false

    // MARK: - Helpers contextuels pour les cards (Rawatib + ProphetSunnah)

    /// Nom de la prière à utiliser pour les cards : prière en cours si dans une
    /// fenêtre, sinon prochaine. Convertit Dhuhr → Jumu'ah le vendredi si activé.
    private var prayerContextForCards: String {
        if prayerVM.currentPrayerWindow != .none {
            if prayerVM.currentPrayerWindow == .dhuhr && prayerVM.isFridayJumuah {
                return "Jumu'ah"
            }
            return prayerVM.currentPrayerWindow.rawValue
        }
        return prayerVM.nextPrayerName
    }

    /// Vendredi réel OU forcé via DEBUG.
    private var isCurrentlyFriday: Bool {
        #if DEBUG
        if debugForceFriday { return true }
        #endif
        return Calendar.current.component(.weekday, from: Date()) == 6
    }

    /// Saison islamique courante (recalculée à chaque apparition)
        private var currentSeason: IslamicSeasonInfo {
            IslamicSeasonInfo.current()
        }
    private var tabColor: Color {
            switch selectedTab {
            case 0: return salatStateTint   // Tab Salat — suit l'état de prière (le rouge était la couleur d'alerte)
            case 1: return .orange   // Tab Rappel
            case 2: return .teal     // Tab Qibla
            case 3: return .blue     // Tab Réglages
            case 4: return ModuleAccent.ilm   // Tab Apprendre
            default: return .white
            }
        }
    // MARK: - Écran Salat : zones (cf. PLAN_UX_SALAT_ZONES.md)

    /// Couleur d'état de la prière — fil conducteur visuel entre les deux zones.
    private var salatStateTint: Color {
        if prayerVM.currentPrayerWindow != .none { return PrayerStateTint.now }
        if prayerVM.nextPrayerName == "Fajr" { return PrayerStateTint.night }
        return PrayerStateTint.upcoming
    }

    /// Chapeau : horloge, dates, et bannières BLOQUANTES uniquement (GPS,
    /// relocalisation, pastille voyage, saison). Les éléments de consultation
    /// posée (fiche fiqh voyage, salawat vendredi) vivent en zone secondaire.
    private var salatHeaderBlock: some View {
        VStack(spacing: 12) {
            // Horloge compacte + dates : l'heure n'est plus l'élément dominant,
            // c'est le héros « Prochaine prière » qui porte l'information n°1.
            SalatClockHeader()

            // Ville · météo · fraîcheur (+ bouton Recalculer si on a bougé).
            SalatStatusChips(cityName: locationManager.cityName)

            // Mode voyage : pastille si actif, sinon suggestion GPS non-intrusive.
            TravelModeHeader()

            SeasonBannerView(season: currentSeason)
        }
    }

    /// Zone prioritaire — « le glance 3 secondes » : météo + prochaine prière,
    /// décomptes contextuels, et LES 5 PRIÈRES (remontées au-dessus du fold).
    @ViewBuilder
    private var salatPriorityZone: some View {
        // `spacing: 0` : chaque carte porte son propre espacement bas, posé
        // DANS sa condition d'affichage. Une carte conditionnelle absente
        // (jauge, Dhuhr, iqamah, état vide) ne laisse donc plus de trou — avec
        // un VStack espacé, un enfant de hauteur nulle gardait son spacing.
        VStack(spacing: 0) {
            // État vide nommé + action (localisation refusée / non demandée /
            // introuvable, calcul impossible). Vide quand tout va bien.
            PrayerEmptyStateCard()
            // Le héros : quelle prière, combien de temps (en cours / prochaine / nuit).
            PrayerHeroCard()
            // Décompte Adhan → Iqamah : visible uniquement pendant
            // la fenêtre (délais réglés dans « Ma mosquée »).
            IqamahCountdownCard()
            // Les 5 prières du jour — l'info n°1, fin de la zone prioritaire.
            PrayerListView()
            // Carte du'a contextuelle pendant Ramadan (Iftar / Suhoor / général) —
            // urgence temporelle, reste en zone 1 mais après la liste.
            if IslamicSeasonInfo.isRamadan() {
                RamadanDuaCardView()
                    .padding(.top, ZoneSpacing.intraZonePrimary)
            }
        }
    }

    /// Zone secondaire — « pour aller plus loin » : la décision d'affichage des
    /// cartes contextuelles (plafond + priorité) vit dans `SalatSecondaryZone`.
    private var salatSecondaryZone: some View {
        SalatSecondaryZone(
            accent: salatStateTint,
            season: currentSeason,
            isFriday: isCurrentlyFriday,
            prayerContext: prayerContextForCards,
            hasPrayers: !prayerVM.dailyPrayers.isEmpty
        )
    }

    var body: some View {
            // Chaîne coupée en deux instructions (`let` + `return`) : le body était
            // devenu trop long pour être type-checké en une seule expression.
            let content = TabView(selection: $selectedTab) {
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ONGLET 1 : SALAT
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                NavigationStack {
                    ZStack {
                        CosmicBackground(season: currentSeason)

                        // Mode voyage actif → voile d'accent subtil sur l'accueil.
                        TravelModeBackdrop()

                        ScrollView(.vertical, showsIndicators: false) {
                            // Écran Salat en 2 zones (cf. PLAN_UX_SALAT_ZONES.md) :
                            // prioritaire (« glance 3 s » : horloge, météo, décomptes,
                            // les 5 prières) puis secondaire (« pour aller plus loin » :
                            // adhkar, sunnah, rappel coranique, lune). Sous-vues séparées
                            // pour la lisibilité ET le type-checker.
                            VStack(spacing: 20) {
                                salatHeaderBlock
                                VStack(spacing: ZoneSpacing.interZone) {
                                    salatPriorityZone
                                    salatSecondaryZone
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .containerRelativeFrame(.horizontal)
                        }
                        .refreshable {
                            // Va chercher un point GPS frais (rattrape un changement de
                            // ville) → le VM recalcule les horaires automatiquement,
                            // puis on rafraîchit la météo sur la position fraîche.
                            await locationManager.refreshLocation()
                            if let loc = locationManager.currentLocation {
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
                        TabBackground.rappel
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
                    QiblaView()
                }
                    .tabItem {
                        Label("Qiblah", systemImage: "safari.fill")
                    }
                    .tag(2)
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // ONGLET APPRENDRE (tag 4) : récitation, révision hebdo, programmes ʿIlm.
                // Placé avant les Réglages pour qu'ils restent en dernière position.
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                LearnHubView()
                    .tabItem {
                        Label("Apprendre", systemImage: "graduationcap.fill")
                    }
                    .tag(4)

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

        return content
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
                handleNotificationDeepLink()
                handleControlDeepLink()
                prayerVM.refreshLiveActivity()
                // Va chercher un point GPS frais à chaque passage au premier plan :
                // rattrape un changement de ville survenu app en arrière-plan. Le VM
                // recalcule automatiquement à la livraison (le garde-fou évite tout
                // recalcul inutile si on n'a pas bougé).
                Task { await locationManager.refreshLocation() }
                // Throttlé 24h + anti-réentrance interne (double-tir avec le .task au lancement).
                Task { await updateChecker.checkForUpdate() }
            }
        }
        .environmentObject(podcastManager)
        .environmentObject(prayerVM)
        .environmentObject(weatherVM)
        .environmentObject(dailyContentService)
        .environmentObject(updateChecker)
        .environment(travel)
        .task {
            // Relie l'unique sink de localisation du VM au store voyage (une fois).
            prayerVM.travelStore = travel
            if let loc = locationManager.currentLocation {
                await weatherVM.fetchWeather(for: loc)
            }
            await updateChecker.checkForUpdate()
            await dailyContentService.fetchDailyContent()
            scheduleAdhkarReminders()
        }
        // Re-schedule des rappels Adhkar quand les horaires changent (nouvelle journée,
        // changement de localisation, recalcul) ou quand les réglages utilisateur changent.
        .onChange(of: prayerVM.dailyPrayers.first?.date) { _, _ in scheduleAdhkarReminders() }
        .onChange(of: adhkarMorningEnabled) { _, _ in scheduleAdhkarReminders() }
        .onChange(of: adhkarEveningEnabled) { _, _ in scheduleAdhkarReminders() }
        .onChange(of: adhkarReminderOffsetMinutes) { _, _ in scheduleAdhkarReminders() }
        .onChange(of: iqamahFajrDelay) { _, _ in scheduleAdhkarReminders() }
        .onChange(of: iqamahAsrDelay) { _, _ in scheduleAdhkarReminders() }
        // ── Auto-retry sur retour de connexion ──────────────────────────
        .onReceive(networkMonitor.onReconnect) {
            Task {
                if let loc = locationManager.currentLocation {
                    await weatherVM.forceRefresh(for: loc)
                }
                if dailyContentService.hasNetworkError {
                    await dailyContentService.fetchDailyContent()
                }
                await podcastManager.retryLoadIfNeeded()
                podcastManager.resumeBufferingIfStalled()
            }
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
                    if let loc = newLocation {
                        Task {
                            await weatherVM.fetchWeather(for: loc)
                        }
                    }
                }
        .onAppear {
                    checkWhatsNew()
                    // Une seule sheet possible par ancre : WhatsNew prioritaire (fenêtre
                    // de tir unique, liée à la version). Les triggers saisonniers
                    // (DST / 120 jours) ne sont PAS consommés quand on saute
                    // checkSeasonalChanges() → le popup ressortira au lancement suivant.
                    if !showWhatsNew {
                        checkSeasonalChanges()
                    }
                }
                .sheet(isPresented: $showSeasonalUpdatePopup) {
                    SeasonalUpdatePopupView(isPresented: $showSeasonalUpdatePopup, lastSetupTimestamp: $lastSmartSetupDate)
                        .presentationDetents([.fraction(0.6)])
                        .presentationBackground(.ultraThinMaterial)
                        .presentationCornerRadius(30)
                }
                .sheet(isPresented: $showWhatsNew, onDismiss: markWhatsNewSeen) {
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
                // Sheet Adhkar déclenchée par :
                //  - le Control Widget "Adhkar du moment" (timing auto-détecté ⇒ nil)
                //  - une notif Adhkar matin/soir (timing forcé)
                .sheet(isPresented: $showAdhkarFromControl, onDismiss: { adhkarSheetForcedTiming = nil }) {
                    // Timing forcé (notification) ou détecté (Control Widget) : le
                    // dégradé suit le même choix que la vue — le matin n'héritait
                    // plus du fond du soir.
                    let timing = adhkarSheetForcedTiming
                        ?? AdhkarTiming.current(fajr: prayerVM.fajrDate, asr: prayerVM.asrDate)
                    ZStack {
                        timing.sheetGradient
                            .ignoresSafeArea()
                        AdhkarView(initialTiming: adhkarSheetForcedTiming)
                    }
                    .environmentObject(prayerVM)
                    .presentationDragIndicator(.visible)
                }
                // Sheet Quran Library déclenchée par le Control Widget "Lire le Coran".
                .sheet(isPresented: $showQuranFromControl) {
                    QuranLibraryView()
                }
                // Notifs Coran / ʿIlm / révision hebdo tapées → bascule d'onglet
                // (modificateur séparé : le body dépasse sinon le type-checker).
                .modifier(TabSwitchDeepLinks(selectedTab: $selectedTab))
                // Notif Adhkar tapée → ouvre la sheet Adhkar avec le timing forcé.
                .onReceive(NotificationCenter.default.publisher(for: .adhkarReminderTapped)) { notif in
                    NotificationDeepLink.clear()
                    if let raw = notif.userInfo?["timing"] as? String,
                       let timing = AdhkarTiming(rawValue: raw) {
                        adhkarSheetForcedTiming = timing
                        showAdhkarFromControl = true
                    }
                }
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // DÉCLENCHEUR D'ADHAN (écoute les notifications)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AdhanTriggered"))) { notification in
                    guard let userInfo = notification.userInfo,
                          let prayerName = userInfo["prayerName"] as? String,
                          let prayerTime = userInfo["prayerTime"] as? Date else { return }

                    NotificationDeepLink.clear()   // no-op si posté par willPresent


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
    /// Programme les rappels Adhkar (matin/soir) post-prière selon les toggles utilisateur.
    /// No-op si les deux toggles sont OFF — le scheduler nettoie ses propres notifs.
    /// Hookée sur changement de prières + changement des réglages.
    private func scheduleAdhkarReminders() {
        let prayers = prayerVM.dailyPrayers.map {
            ScheduledPrayer(name: $0.name, date: $0.date)
        }
        let iqamahDelays: [String: Int] = [
            "Fajr": iqamahFajrDelay,
            "Asr": iqamahAsrDelay,
        ]
        AdhkarReminderScheduler.schedule(
            prayers: prayers,
            morningEnabled: adhkarMorningEnabled,
            eveningEnabled: adhkarEveningEnabled,
            iqamahDelaysMinutes: iqamahDelays,
            reminderOffsetMinutes: adhkarReminderOffsetMinutes
        )
    }

    /// Marque le Quoi de neuf comme vu, à la fermeture de la sheet.
    /// Écrit ici (et pas dans checkWhatsNew) : si la sheet n'a jamais
    /// été affichée (app tuée avant), le Quoi de neuf reviendra.
    private func markWhatsNewSeen() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        if !currentVersion.isEmpty { lastSeenAppVersion = currentVersion }
    }

    /// Consomme la route posée par `AppDelegate.didReceive` au tap d'une notification.
    ///
    /// Couvre le cold start : le post NotificationCenter du delegate est perdu si
    /// les `.onReceive` ne sont pas encore montés — la route persistée prend le
    /// relais. Si l'app était en mémoire, le handler live a déjà routé ET effacé
    /// la route (`NotificationDeepLink.clear()`), donc pas de double déclenchement.
    private func handleNotificationDeepLink() {
        guard let route = NotificationDeepLink.consume() else { return }
        switch route {
        case .adhan:
            let defaults = UserDefaults.standard
            guard let name = defaults.string(forKey: NotificationDeepLink.adhanNameKey) else { return }
            let time = Date(timeIntervalSince1970: defaults.double(forKey: NotificationDeepLink.adhanTimeKey))
            withAnimation(.easeIn(duration: 0.4)) {
                adhanPrayerName = name
                adhanPrayerTime = time
                showAdhanOverlay = true
            }
        case .quranTracker:
            // Le switch de tab monte LearnHubView → QuranKhatmaCard, qui
            // consomme `pendingOpenQuranTracker` à son onAppear et ouvre la sheet.
            selectedTab = 4
        case .ilmTracker:
            // Même mécanique : IlmProgramCard (onglet Apprendre) consomme
            // `pendingOpenIlmTracker` à son onAppear et ouvre la sheet.
            selectedTab = 4
        case .weeklyQuiz:
            // WeeklyReviewCard consomme `pendingOpenWeeklyQuiz` à son onAppear.
            selectedTab = 4
        case .adhkarMorning:
            adhkarSheetForcedTiming = .morning
            showAdhkarFromControl = true
        case .adhkarEvening:
            adhkarSheetForcedTiming = .evening
            showAdhkarFromControl = true
        }
    }

    /// Lit la clé `controlDeepLinkTarget` écrite par un Control Widget (Qibla / Adhkar)
    /// dans l'App Group, route vers la destination, puis efface la clé.
    ///
    /// Retry intégré : `openAppWhenRun=true` lance l'app en parallèle de l'AppIntent.perform()
    /// du widget. L'app peut passer à `.active` AVANT que la clé soit écrite côté widget.
    /// On retente 3 fois à 250ms d'intervalle pour couvrir cette race condition.
    private func handleControlDeepLink(retryCount: Int = 0) {
        let shared = UserDefaults(suiteName: AppGroup.identifier)
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
                print("✅ [DeepLink] Routing to Adhkar sheet (auto timing)")
                adhkarSheetForcedTiming = nil
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

        // Décision pure et testée (première install, vraie MAJ, downgrade TestFlight).
        switch UpdateCheckMath.whatsNewAction(current: currentVersion, lastSeen: lastSeenAppVersion) {
        case .show:
            // Vraie MAJ → sheet. `lastSeenAppVersion` est écrit au onDismiss pour ne
            // pas perdre le Quoi de neuf si la sheet n'est jamais affichée.
            showWhatsNew = true
        case .recordOnly:
            // Première install ou downgrade : mémoriser sans afficher.
            lastSeenAppVersion = currentVersion
        case .nothing:
            break
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

// MARK: - Deep links de notification qui changent d'onglet

/// Notif Coran → onglet Rappel (où vit la carte Khatma) ; notifs ʿIlm et
/// révision hebdo → onglet Apprendre. Les cartes ouvrent ensuite leur sheet
/// (handlers live ou flags `pending*` consommés à leur onAppear).
private struct TabSwitchDeepLinks: ViewModifier {
    @Binding var selectedTab: Int

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .quranReadingTapped)) { _ in
                NotificationDeepLink.clear()
                selectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: .ilmReminderTapped)) { _ in
                NotificationDeepLink.clear()
                selectedTab = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: .weeklyQuizTapped)) { _ in
                NotificationDeepLink.clear()
                selectedTab = 4
            }
            // Tap sur la carte « En ce moment » compacte (onglet Rappel) :
            // la suggestion complète et son routage vivent dans le hub Apprendre.
            .onReceive(NotificationCenter.default.publisher(for: .learnSuggestionTapped)) { _ in
                selectedTab = 4
            }
    }
}
