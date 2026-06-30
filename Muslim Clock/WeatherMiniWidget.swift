import SwiftUI
import CoreLocation
import WeatherKit

/// Capsule sous le `WeatherMiniWidget` : affiche la ville (source GPS) + attribution
/// WeatherKit (Apple — requise par App Review 5.2.5).
///
/// Pensée pour s'adapter à des noms de ville longs : la capsule s'élargit avec le
/// contenu, le nom de ville est en `lineLimit(1) + truncationMode(.middle)` pour
/// rester lisible même tronqué (« Saint-…-Provence » plutôt que « Saint-Rémy-… »).
///
/// L'attribution affiche le logo officiel « Weather ». Si l'attribution n'a pas
/// encore été fetchée (offline / cold start), fallback texte cliquable vers la
/// page légale connue d'Apple.
struct WeatherCityAttributionRow: View {
    let cityName: String
    let attribution: WeatherAttribution?

    /// Fallback URL si `attribution` est nil — page légale Apple WeatherKit publique.
    private static let fallbackLegalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.indigo.opacity(0.8))

            Text(verbatim: cityName.isEmpty ? String(localized: "Localisation…") : cityName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)

            Text(verbatim: "·")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))

            WeatherAttributionView(attribution: attribution, fallbackURL: Self.fallbackLegalURL)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.clear, in: Capsule())
    }
}

/// Attribution Apple Weather requise par App Review (guideline 5.2.5).
///
/// Affiche le logo officiel « Weather » fourni par `WeatherAttribution.combinedMarkDarkURL`,
/// avec un tap qui ouvre `legalPageURL` (sources des données : NOAA, etc.).
///
/// Si `attribution == nil` (pas encore chargée), affiche un fallback texte cliquable
/// vers `fallbackURL` (page légale publique d'Apple).
struct WeatherAttributionView: View {
    let attribution: WeatherAttribution?
    var fallbackURL: URL? = nil

    var body: some View {
        Link(destination: attribution?.legalPageURL ?? fallbackURL ?? URL(string: "https://www.apple.com/weather/")!) {
            if let url = attribution?.combinedMarkDarkURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 12)
                } placeholder: {
                    fallbackLabel
                }
            } else {
                fallbackLabel
            }
        }
        .accessibilityLabel(Text("Source des données météo"))
    }

    private var fallbackLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "applelogo")
                .font(.system(size: 9, weight: .medium))
            Text(verbatim: "Weather")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.7))
    }
}

struct WeatherMiniWidget: View {
    @EnvironmentObject var weatherVM: WeatherViewModel
    var location: CLLocation?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: weatherVM.conditionIcon)
                .font(.system(size: 34))
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
            Text(verbatim: weatherVM.temperature)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(width: 100, height: 100)
        .padding(10)
        .glassEffect(.regular, in: .circle)
        .redacted(reason: weatherVM.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: weatherVM.isLoading)
    }
}

struct NextPrayerWidget: View {
    // 1. 🔌 On attrape le cerveau global injecté par MainView
        @EnvironmentObject var prayerVM: PrayerTimesViewModel

    /// Dans une fenêtre de prière active : le widget bascule sur la prière en
    /// cours + heure de fin de fenêtre. Évite la redondance avec
    /// `CurrentPrayerGaugeView` qui montre déjà le décompte détaillé.
    private var isInWindow: Bool {
        prayerVM.currentPrayerWindow != .none && prayerVM.currentWindowEnd != nil
    }

    private var displayName: String {
        guard isInWindow else { return prayerVM.nextPrayerName }
        if prayerVM.currentPrayerWindow == .dhuhr && prayerVM.isFridayJumuah {
            return "Jumu'ah"
        }
        return prayerVM.currentPrayerWindow.rawValue
    }

    private var displayTime: String {
        if isInWindow, let end = prayerVM.currentWindowEnd {
            return end.formatted(date: .omitted, time: .shortened)
        }
        return prayerVM.nextPrayerTime
    }

    var body: some View {
        VStack(spacing: isInWindow ? 2 : 8) {
            Text(verbatim: displayName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if isInWindow {
                Text("jusqu'à")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.9))
            }

            Text(verbatim: displayTime)
                .font(.system(size: isInWindow ? 22 : 24, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 100, height: 100)
        .padding(10)
        .glassEffect(.clear, in: .circle)
        .redacted(reason: prayerVM.isLoading ? .placeholder : []) // SKELETON RESTAURÉ
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
        .animation(.easeInOut(duration: 0.3), value: isInWindow)
    }
}

struct PrayerListView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @AppStorage("iqamahFajrDelay")    private var iqamahFajr    = 10
    @AppStorage("iqamahDhuhrDelay")   private var iqamahDhuhr   = 10
    @AppStorage("iqamahAsrDelay")     private var iqamahAsr     = 10
    @AppStorage("iqamahMaghribDelay") private var iqamahMaghrib = 5
    @AppStorage("iqamahIshaDelay")    private var iqamahIsha    = 10
    
    private func iqamahDelay(for name: String) -> Int {
        switch name {
        case "Fajr":            return iqamahFajr
        case "Dhuhr", "Jumu'ah": return iqamahDhuhr
        case "Asr":             return iqamahAsr
        case "Maghrib":         return iqamahMaghrib
        case "Isha":            return iqamahIsha
        default:                return 0
        }
    }
    
    private func iqamahTime(for prayer: DailyPrayer) -> String? {
        // Pas d'iqamah pour Jumu'ah : l'utilisateur a déjà défini l'heure exacte
        if prayer.name == "Jumu'ah" { return nil }
        let delay = iqamahDelay(for: prayer.name)
        guard delay > 0 else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: prayer.date.addingTimeInterval(Double(delay) * 60))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(prayerVM.dailyPrayers) { prayer in
                HStack(spacing: 12) {
                    // Nom de la prière — toujours canonique (« Maghrib », « Fajr »…).
                    Text(verbatim: prayer.name)
                        .font(.headline)
                        .foregroundStyle(prayer.isNext ? .green : .primary)

                    // Badge contextuel Ramadan (« Iftar » / « Fin du Sohoor »).
                    if let badge = IslamicSeasonInfo.ramadanBadge(for: prayer.name) {
                        RamadanPrayerBadge(label: badge, prayerName: prayer.name)
                    }

                    // Badge "En cours" (Priorité sur prochaine)
                    if prayer.isCurrent {
                        Text("En cours")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.gradient)
                            .clipShape(Capsule())
                    } else if prayer.isNext {
                        Text("Prochaine")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.gradient)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Horaire adhan + iqamah
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: prayer.time)
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(prayer.isNext ? .green : (prayer.isCurrent ? .orange : .primary))
                        
                        if let iqamah = iqamahTime(for: prayer) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.indigo.opacity(0.6))
                                
                                Text(verbatim: iqamah)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                        }
                    } // fin VStack horaires
                } // fin HStack de la ligne
                .padding(.horizontal, 20)
                .frame(height: 70)
                // ✅ Liquid Glass pour la prochaine, material classique pour les autres
                .background {
                                    if prayer.isNext || prayer.isCurrent {
                                        Color.clear
                                    } else {
                                        RoundedRectangle(cornerRadius: 20).fill(.regularMaterial)
                                    }
                                }
                                .if(prayer.isNext) { view in
                                    view.glassEffect(.regular.tint(.green.opacity(0.15)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .if(prayer.isCurrent) { view in
                                    view.glassEffect(.regular.tint(.orange.opacity(0.15)), in: RoundedRectangle(cornerRadius: 20))
                                }
                                .if(!prayer.isNext && !prayer.isCurrent) { view in
                                    view.cornerRadius(20)
                                }
                            }
                        }
        .redacted(reason: prayerVM.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
    }
}
 
// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Ramadan badge

/// Petite capsule affichée à côté d'une prière pendant Ramadan pour signaler
/// son rôle contextuel (« Iftar » à côté de Maghrib, « Fin du Sohoor » à côté de Fajr).
struct RamadanPrayerBadge: View {
    let label: String
    let prayerName: String

    private var tint: Color {
        // Iftar = chaleur du coucher (ambre/orange). Sohoor = nuit (violet doux,
        // teinte partagée avec l'accent de la carte du'a Suhoor).
        prayerName == "Fajr"
            ? IslamicSeasonInfo.ramadanNightTint
            : Color(red: 0.95, green: 0.55, blue: 0.15)
    }

    private var icon: String {
        prayerName == "Fajr" ? "moon.stars.fill" : "sunset.fill"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(verbatim: label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .glassEffect(.clear.tint(tint.opacity(0.20)), in: Capsule())
        .accessibilityLabel(Text("Contexte Ramadan : \(label)"))
    }
}
