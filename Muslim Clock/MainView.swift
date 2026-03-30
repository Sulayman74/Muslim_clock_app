import SwiftUI

struct MainView: View {
    @StateObject var manager = CompassManager()
    @StateObject var prayerVM = PrayerTimesViewModel()
    
    // 🚀 1. LE DÉTECTEUR D'ONGLET
    @State private var selectedTab: Int = 0
    
    var body: some View {
        // 🚀 2. ON CONNECTE LE TABVIEW AU DÉTECTEUR
        TabView(selection: $selectedTab) {
            
            // --- ONGLET 1 : ACCUEIL ---
            NavigationStack {
                ZStack {
                    LinearGradient(colors: [.blue.opacity(0.4), .indigo.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                    
                    ScrollView (.vertical, showsIndicators: false) {
                        VStack(spacing: 35) {
                            // --- L'HORLOGE NATIVE ---
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
                        // 🚀 3. LA CORRECTION DU WOBBLE (OVERFLOW X)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                    }
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
            .tag(0) // 🚀 4. ÉTIQUETTE DE L'ONGLET 0
            
            // --- ONGLET 2 : BOUSSOLE ---
            QiblaView(manager: manager)
                .tabItem {
                    Label("Qiblah", systemImage: "safari.fill")
                }
                .tag(1) // 🚀 4. ÉTIQUETTE DE L'ONGLET 1
        }
        // 🚀 5. LA MAGIE DES COULEURS LIQUID GLASS
        // Si Tab 0 (Accueil) -> Indigo. Si Tab 1 (Qiblah) -> Vert Sapin / Menthe.
        .tint(selectedTab == 0 ? .purple : .mint)
        
        .tabBarMinimizeBehavior(.onScrollDown)
        .environment(\.colorScheme, .dark)
    }
}

#Preview {
    MainView()
}
