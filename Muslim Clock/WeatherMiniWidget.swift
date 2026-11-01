import SwiftUI
import CoreLocation
import WeatherKit

/// Capsule du chapeau Salat : affiche la ville (source GPS) + attribution
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

// MARK: - Chapeau : rangée de chips

/// Rangée d'état du chapeau Salat : ville + attribution, météo, fraîcheur des
/// horaires, et le bouton « Recalculer » quand on a bougé. Remplace les deux
/// cercles météo / prochaine prière (120 pt) : la prochaine prière vit dans le
/// héros, la météo n'a pas besoin de 120 pt pour deux caractères.
struct SalatStatusChips: View {
    let cityName: String
    @EnvironmentObject var weatherVM: WeatherViewModel
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @ObservedObject private var location = SharedLocationManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                WeatherCityAttributionRow(cityName: cityName, attribution: weatherVM.attribution)
                weatherChip
                freshnessChip
            }
            GPSRelocationIndicator()
        }
    }

    private var weatherChip: some View {
        HStack(spacing: 4) {
            Image(systemName: weatherVM.conditionIcon)
                .font(.system(size: 12))
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
            Text(verbatim: weatherVM.temperature)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.clear, in: Capsule())
        // Squelette uniquement pendant un vrai chargement : sans position, « --° ».
        .redacted(reason: weatherVM.isLoading && location.currentLocation != nil ? .placeholder : [])
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Météo : \(weatherVM.temperature)"))
    }

    /// Largeur plancher de la chip de fraîcheur : « 8:12 » et « Position… »
    /// occupent la même place, la rangée ne se décale pas pendant un refresh.
    private static let freshnessMinWidth: CGFloat = 64

    /// « Horaires mis à jour à HH:mm », ou spinner pendant un fix GPS. Rien avant le premier calcul.
    @ViewBuilder
    private var freshnessChip: some View {
        if location.isRefreshingLocation {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini).tint(.white.opacity(0.6))
                Text("Position…")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .frame(minWidth: Self.freshnessMinWidth)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: Capsule())
        } else if let updated = prayerVM.lastPrayerUpdate {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                Text(verbatim: updated.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .frame(minWidth: Self.freshnessMinWidth)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: Capsule())
            .accessibilityLabel(Text("Horaires mis à jour à \(updated.formatted(date: .omitted, time: .shortened))"))
        }
    }
}

// MARK: - Liste des prières

struct PrayerListView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @AppStorage(StorageKeys.iqamahFajrDelay)    private var iqamahFajr    = IqamahDefaults.fajr
    @AppStorage(StorageKeys.iqamahDhuhrDelay)   private var iqamahDhuhr   = IqamahDefaults.dhuhr
    @AppStorage(StorageKeys.iqamahAsrDelay)     private var iqamahAsr     = IqamahDefaults.asr
    @AppStorage(StorageKeys.iqamahMaghribDelay) private var iqamahMaghrib = IqamahDefaults.maghrib
    @AppStorage(StorageKeys.iqamahIshaDelay)    private var iqamahIsha    = IqamahDefaults.isha

    /// Hauteur plancher d'une ligne, mise à l'échelle avec Dynamic Type : les
    /// 5 prières (et Chourouq) tiennent au-dessus du fold sans hauteur fixe.
    @ScaledMetric(relativeTo: .title3) private var rowMinHeight: CGFloat = 54
    /// Espacement entre lignes (plus serré que la zone : la liste est un bloc).
    private static let rowSpacing: CGFloat = 8

    /// Noms affichés tant qu'aucun horaire n'est disponible : la liste garde sa
    /// place (pas de trou, pas de saut à l'arrivée des horaires — anti-wiggle n°5).
    private static let placeholderNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    /// Même format que `DailyPrayer.time` (« 06:27 ») : un formatter partagé,
    /// plus un par ligne et par rendu.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func iqamahDelay(for name: String) -> Int {
        switch name {
        case "Fajr":    return iqamahFajr
        case "Dhuhr":   return iqamahDhuhr
        case "Asr":     return iqamahAsr
        case "Maghrib": return iqamahMaghrib
        case "Isha":    return iqamahIsha
        default:        return 0
        }
    }

    private func iqamahTime(for prayer: DailyPrayer) -> String? {
        // Pas d'iqamah pour Jumu'ah : l'utilisateur a déjà défini l'heure exacte
        if prayer.name == "Jumu'ah" { return nil }
        let delay = iqamahDelay(for: prayer.name)
        guard delay > 0 else { return nil }
        return Self.timeFormatter.string(from: prayer.date.addingTimeInterval(Double(delay) * 60))
    }

    var body: some View {
        VStack(spacing: Self.rowSpacing) {
            if prayerVM.dailyPrayers.isEmpty {
                ForEach(Self.placeholderNames, id: \.self) { name in
                    row(name: name, time: "--:--", iqamah: nil, ramadanBadge: nil, isCurrent: false, isNext: false)
                        .opacity(0.45)
                    if name == "Fajr" {
                        sunriseRow(time: "--:--").opacity(0.45)
                    }
                }
            } else {
                ForEach(prayerVM.dailyPrayers) { prayer in
                    row(
                        name: prayer.name,
                        time: prayer.time,
                        iqamah: iqamahTime(for: prayer),
                        ramadanBadge: IslamicSeasonInfo.ramadanBadge(for: prayer.name),
                        isCurrent: prayer.isCurrent,
                        isNext: prayer.isNext
                    )
                    // Chourouq : fin du temps de Fajr — ligne fine, pas une prière.
                    if prayer.name == "Fajr", let sunrise = prayerVM.sunriseTime {
                        sunriseRow(time: Self.timeFormatter.string(from: sunrise))
                    }
                }
            }
        }
        .redacted(reason: prayerVM.isLoading ? .placeholder : [])
        .animation(.easeInOut(duration: 0.3), value: prayerVM.isLoading)
        .animation(.easeInOut(duration: 0.3), value: prayerVM.dailyPrayers.isEmpty)
    }

    // MARK: - Lignes

    private func row(name: String, time: String, iqamah: String?, ramadanBadge: String?, isCurrent: Bool, isNext: Bool) -> some View {
        let tint: Color? = isCurrent ? PrayerStateTint.now : (isNext ? PrayerStateTint.upcoming : nil)

        return HStack(spacing: 10) {
            // Nom de la prière — toujours canonique (« Maghrib », « Fajr »…).
            Text(verbatim: name)
                .font(.headline)
                .foregroundStyle(isNext ? PrayerStateTint.upcoming : .white)

            // Badge contextuel Ramadan (« Iftar » / « Fin du Sohoor »).
            if let ramadanBadge {
                RamadanPrayerBadge(label: ramadanBadge, prayerName: name)
            }

            // Badge "En cours" (Priorité sur prochaine)
            if isCurrent {
                stateBadge("En cours", tint: PrayerStateTint.now)
            } else if isNext {
                stateBadge("Prochaine", tint: PrayerStateTint.upcoming)
            }

            Spacer()

            // Horaire adhan + iqamah
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: time)
                    .font(.system(.title3, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundStyle(tint ?? .white)

                if let iqamah {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))

                        Text(verbatim: iqamah)
                            .font(.system(size: 12, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        // Plancher scalé (pas de hauteur fixe) : le contenu peut pousser en Dynamic Type.
        .frame(minHeight: rowMinHeight)
        // Surface unique : teinte « now » (en cours) / « upcoming » (prochaine),
        // neutre pour les prières passées.
        .glassCard(tint: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(name: name, time: time, iqamah: iqamah, isCurrent: isCurrent, isNext: isNext))
    }

    /// Ligne discrète « Chourouq HH:mm » (lever du soleil), sans verre.
    private func sunriseRow(time: String) -> some View {
        HStack {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 10))
            Text("Chourouq")
                .font(.caption.weight(.medium))
            Spacer()
            Text(verbatim: time)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 20)
        .frame(minHeight: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Chourouq, lever du soleil, \(time)"))
    }

    private func stateBadge(_ label: LocalizedStringKey, tint: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.gradient)
            .clipShape(Capsule())
    }

    private func accessibilityLabel(name: String, time: String, iqamah: String?, isCurrent: Bool, isNext: Bool) -> Text {
        var parts: [String] = [name]
        if isCurrent { parts.append(String(localized: "en cours")) }
        else if isNext { parts.append(String(localized: "prochaine prière")) }
        parts.append(time)
        if let iqamah { parts.append(String(localized: "iqamah \(iqamah)")) }
        return Text(verbatim: parts.joined(separator: ", "))
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
