import AppIntents
import UIKit
import SwiftUI
import AVFoundation
import WidgetKit
import Adhan

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MODÈLE DE DONNÉES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum PrayerStatus: Equatable {
    case passed
    case nextNormal
    case nextImminent
    case future
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let prayerStatuses: [String: PrayerStatus]
    let prayerTimes: [String: Date]
    let nextPrayerName: String
    let nextPrayerDate: Date?
    let hijriDateAr: String
}

enum WidgetUtils {
    
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
    static func formatTime(_ date: Date?) -> String {
        guard let d = date else { return "--:--" }
        return timeFormatter.string(from: d)
    }
    
    static func shortPrayerName(_ name: String) -> String {
        switch name {
        case "Fajr": return "FJR"
        case "Dhuhr": return "DHR"
        case "Asr": return "ASR"
        case "Maghrib": return "MGH"
        case "Isha": return "ISH"
        default: return String(name.prefix(3)).uppercased()
        }
    }
    
    static func sphereColor(_ status: PrayerStatus) -> Color {
        switch status {
        case .passed: return .indigo
        case .nextNormal: return .orange
        case .nextImminent: return .red
        case .future: return .white.opacity(0.15)
        }
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PROVIDER PARTAGÉ — LIT LES RÉGLAGES SMART SETUP
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
struct SalatProvider: TimelineProvider {
    
    private var shared: UserDefaults? {
        UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
    }
    
    private func getCoordinates() -> (Double, Double) {
        let lat = shared?.double(forKey: "saved_latitude") ?? 48.8566
        let lon = shared?.double(forKey: "saved_longitude") ?? 2.3522
        return (lat == 0 ? 48.8566 : lat, lon == 0 ? 2.3522 : lon)
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // ✅ MÊME LOGIQUE QUE PrayerTimesViewModel
    // Lit les clés "w_*" écrites par l'app
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    private func getParams() -> CalculationParameters {
        let sd = shared
        let method = sd?.string(forKey: "w_calculationMethod") ?? "UOIF (12°)"
        let fajrOffset = sd?.integer(forKey: "w_fajrOffset") ?? 0
        let dhuhrOffset = sd?.integer(forKey: "w_dhuhrOffset") ?? 0
        let asrOffset = sd?.integer(forKey: "w_asrOffset") ?? 0
        let maghribOffset = sd?.integer(forKey: "w_maghribOffset") ?? 0
        let isIshaFixed = sd?.bool(forKey: "w_isIshaFixed") ?? true
        let ishaFixedDuration = sd?.integer(forKey: "w_ishaFixedDuration") ?? 90
        let ishaOffset = sd?.integer(forKey: "w_ishaOffset") ?? 0
        
        // 1. Méthode / Angles
        var params: CalculationParameters
        
        switch method {
            case "UOIF (12°)":
                params = CalculationMethod.muslimWorldLeague.params
                params.fajrAngle = 12
                params.ishaAngle = 12
            case "ISNA (15°)":
                params = CalculationMethod.northAmerica.params
            case "Mosquée de Paris":
                params = CalculationMethod.muslimWorldLeague.params
                params.fajrAngle = 18
                params.ishaAngle = 18
            default: // "Ligue Islamique (18°)"
                params = CalculationMethod.muslimWorldLeague.params
        }
        
        params.madhab = .shafi
        
        // 2. Offsets (Temkine)
        params.adjustments.fajr = fajrOffset
        params.adjustments.dhuhr = dhuhrOffset
        params.adjustments.asr = asrOffset
        params.adjustments.maghrib = maghribOffset
        
        // 3. Isha fixe ou astronomique
        if isIshaFixed {
            params.ishaInterval = ishaFixedDuration == 0 ? 90 : ishaFixedDuration
            params.adjustments.isha = maghribOffset
        } else {
            params.adjustments.isha = ishaOffset
        }
        
        return params
    }
    
    private func hijriArabic(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        f.locale = Locale(identifier: "ar_SA")
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }
    
    func buildEntry(for date: Date) -> SimpleEntry {
        let (lat, lon) = getCoordinates()
        let params = getParams()
        let comp = Calendar.current.dateComponents([.year, .month, .day], from: date)
        
        var statuses: [String: PrayerStatus] = [
            "Fajr": .future, "Dhuhr": .future, "Asr": .future,
            "Maghrib": .future, "Isha": .future
        ]
        var times: [String: Date] = [:]
        var nextName = "Fajr"
        var nextDate: Date? = nil
        
        if let pt = PrayerTimes(coordinates: Coordinates(latitude: lat, longitude: lon), date: comp, calculationParameters: params) {
            let prayers: [(String, Date)] = [
                ("Fajr", pt.fajr), ("Dhuhr", pt.dhuhr), ("Asr", pt.asr),
                ("Maghrib", pt.maghrib), ("Isha", pt.isha)
            ]
            
            var found = false
            for (name, time) in prayers {
                times[name] = time
                if date >= time {
                    statuses[name] = .passed
                } else if !found {
                    found = true
                    nextName = name
                    nextDate = time
                    statuses[name] = time.timeIntervalSince(date) <= 15 * 60 ? .nextImminent : .nextNormal
                }
            }
            
            if !found {
                nextName = "Fajr"
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date)!
                let tc = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                if let tp = PrayerTimes(coordinates: Coordinates(latitude: lat, longitude: lon), date: tc, calculationParameters: params) {
                    nextDate = tp.fajr
                }
            }
        }
        
        return SimpleEntry(
            date: date,
            prayerStatuses: statuses,
            prayerTimes: times,
            nextPrayerName: nextName,
            nextPrayerDate: nextDate,
            hijriDateAr: hijriArabic(for: date)
        )
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: .now,
            prayerStatuses: ["Fajr": .passed, "Dhuhr": .nextNormal, "Asr": .future, "Maghrib": .future, "Isha": .future],
            prayerTimes: [:],
            nextPrayerName: "Dhuhr",
            nextPrayerDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
            hijriDateAr: "١٢ شوال"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(buildEntry(for: .now))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let now = Date()
        var entries: [SimpleEntry] = [buildEntry(for: now)]
        
        let (lat, lon) = getCoordinates()
        let params = getParams()
        let comp = Calendar.current.dateComponents([.year, .month, .day], from: now)
        
        let checkpoints: [TimeInterval] = [
            -30 * 60,
            -15 * 60,
            -5 * 60,
            0
        ]
        
        if let pt = PrayerTimes(
            coordinates: Coordinates(latitude: lat, longitude: lon),
            date: comp,
            calculationParameters: params
        ) {
            
            let prayerTimes = [pt.fajr, pt.dhuhr, pt.asr, pt.maghrib, pt.isha]
            
            for time in prayerTimes {
                for offset in checkpoints {
                    let trigger = time.addingTimeInterval(offset)
                    if trigger > now {
                        entries.append(buildEntry(for: trigger))
                    }
                }
            }
        }
        
        // ✅ Anti doublons + tri
        let uniqueDates = Array(Set(entries.map { $0.date })).sorted()
        let finalEntries = uniqueDates.map { buildEntry(for: $0) }
        
        completion(Timeline(entries: finalEntries, policy: .atEnd))
    }

    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // WIDGET 1 : HOME — MEDIUM (sphères, design original)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    struct MainPrayerSphere: View {
        var name: String
        var status: PrayerStatus
        var themeColor: Color {
            switch status {
                case .passed: return .indigo
                case .nextNormal: return .orange
                case .nextImminent: return .red
                case .future: return .clear
            }
        }
        var isActive: Bool { status != .future }
        var body: some View {
            VStack(spacing: 8) {
                Circle()
                    .fill(isActive ? themeColor : Color.white.opacity(0.05))
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(isActive ? 0.6 : 0.15), lineWidth: 1))
                    .shadow(color: isActive ? themeColor.opacity(0.7) : .clear, radius: 8)
                Text(verbatim: name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor((status == .nextNormal || status == .nextImminent) ? .white : .white.opacity(0.5))
            }
        }
    }
    
    struct HomeWidgetDateHeader: View {
        var date: Date
        var gregorianFr: String {
            let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d MMMM yyyy"
            return f.string(from: date).capitalized
        }
        var hijriAr: String {
            let f = DateFormatter(); f.calendar = Calendar(identifier: .islamicUmmAlQura); f.locale = Locale(identifier: "ar_SA"); f.dateFormat = "d MMMM yyyy"
            return f.string(from: date)
        }
        var hijriFr: String {
            let f = DateFormatter(); f.calendar = Calendar(identifier: .islamicUmmAlQura); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d MMMM yyyy"
            return f.string(from: date)
        }
        var body: some View {
            VStack(spacing: 2) {
                HStack(alignment: .bottom) {
                    Text(verbatim: gregorianFr).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(verbatim: hijriAr).font(.system(size: 14, weight: .bold)).foregroundColor(.orange.opacity(0.9)).environment(\.layoutDirection, .rightToLeft)
                }
                HStack { Text(verbatim: hijriFr).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.5)); Spacer() }
            }
            .padding(.horizontal, 16)
        }
    }
    
    struct SalatHomeWidget: Widget {
        let kind = "SalatWidget"
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: SalatProvider()) { entry in
                VStack(spacing: 16) {
                    HomeWidgetDateHeader(date: entry.date)
                    HStack(alignment: .center, spacing: 12) {
                        MainPrayerSphere(name: "Fajr", status: entry.prayerStatuses["Fajr"] ?? .future)
                        MainPrayerSphere(name: "Dhuhr", status: entry.prayerStatuses["Dhuhr"] ?? .future)
                        MainPrayerSphere(name: "Asr", status: entry.prayerStatuses["Asr"] ?? .future)
                        MainPrayerSphere(name: "Maghrib", status: entry.prayerStatuses["Maghrib"] ?? .future)
                        MainPrayerSphere(name: "Isha", status: entry.prayerStatuses["Isha"] ?? .future)
                    }
                }
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.15), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .configurationDisplayName("Le Cycle de Lumière")
            .description("Suivez vos prières d'un simple coup d'œil.")
            .supportedFamilies([.systemMedium])
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // WIDGET 2 : HOME — SMALL (carré compact)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    struct SalatSmallWidget: Widget {
        let kind = "SalatSmallWidget"
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: SalatProvider()) { entry in
                VStack(spacing: 6) {
                    Text(verbatim: entry.hijriDateAr)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    Text(verbatim: entry.nextPrayerName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(verbatim: WidgetUtils.formatTime(entry.nextPrayerDate))
                        .font(.system(size: 28, weight: .thin, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                    
                    if let target = entry.nextPrayerDate, target > entry.date {
                        Text(target, style: .relative)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 5) {
                        ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { name in
                            Circle()
                                .fill(WidgetUtils.sphereColor(entry.prayerStatuses[name] ?? .future))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.15), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .configurationDisplayName("Prochaine Prière")
            .description("La prochaine prière en un coup d'œil.")
            .supportedFamilies([.systemSmall])
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // WIDGET 3 : LOCK SCREEN (Circular + Rectangular + Inline)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    struct SalatLockView: View {
        let entry: SimpleEntry
        @Environment(\.widgetFamily) var family
        
        var body: some View {
            switch family {
                case .accessoryCircular:
                    circularView
                case .accessoryRectangular:
                    rectangularView
                case .accessoryInline:
                    inlineView
                default:
                    Text(verbatim: "🕌")
            }
        }
        
        private func isCurrentPrayer(_ name: String, entry: SimpleEntry) -> Bool {
            guard let time = entry.prayerTimes[name] else { return false }
            
            let nextTimes = entry.prayerTimes.values
                .filter { $0 > time }
                .sorted()
            
            guard let next = nextTimes.first else { return false }
            
            return entry.date >= time && entry.date < next
        }
        
        private func realProgress(entry: SimpleEntry) -> Double {
            guard let next = entry.nextPrayerDate else { return 0 }
            
            let calendar = Calendar.current
            
            // 🔍 1. Cherche dernière prière aujourd’hui
            let previousToday = entry.prayerTimes
                .filter { $0.value < entry.date }
                .max(by: { $0.value < $1.value })?.value
            
            var previous = previousToday
            
            // 🌙 2. Si aucune → on est après minuit AVANT Fajr
            if previous == nil {
                
                // 👉 recalcul Isha d’hier
                let yesterday = calendar.date(byAdding: .day, value: -1, to: entry.date)!
                let comp = calendar.dateComponents([.year, .month, .day], from: yesterday)
                
                let (lat, lon) = SalatProvider().getCoordinates()
                let params = SalatProvider().getParams()
                
                if let pt = PrayerTimes(
                    coordinates: Coordinates(latitude: lat, longitude: lon),
                    date: comp,
                    calculationParameters: params
                ) {
                    previous = pt.isha
                }
            }
            
            guard let prev = previous else { return 0 }
            
            let total = next.timeIntervalSince(prev)
            let elapsed = entry.date.timeIntervalSince(prev)
            
            return max(0, min(1, elapsed / total))
        }
        
        // ----- Circular ------------ //
        
        private var circularView: some View {
            let progress = realProgress(entry: entry)
            
            return Gauge(value: progress) {
                Image(systemName: "moon.stars.fill")
            } currentValueLabel: {
                VStack(spacing: 1) {
                    Text(verbatim: WidgetUtils.shortPrayerName(entry.nextPrayerName))
                        .font(.system(size: 11, weight: .bold))
                    
                    if let target = entry.nextPrayerDate {
                        Text(verbatim: WidgetUtils.formatTime(target))
                            .font(.system(size: 9, weight: .medium))
                            .monospacedDigit()
                    }
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(colorForStatus(entry))
            .widgetAccentable()
        }
        
        private func colorForStatus(_ entry: SimpleEntry) -> Color {
            guard let next = entry.nextPrayerDate else { return .blue }
            
            let remaining = next.timeIntervalSince(entry.date)
            
            // 🔴 priorité haute
            if remaining < 3 * 60 { return .red }
            
            // 🟠 priorité moyenne
            if remaining < 15 * 60 { return .orange }
            
            // 🌙 sinon nuit
            if entry.nextPrayerName == "Fajr" {
                return .indigo
            }
            
            return .blue
        }
        // ── RECTANGULAR ──
        private var rectangularView: some View {
            VStack(alignment: .leading, spacing: 6) {
                if isCurrentPrayer(entry.nextPrayerName, entry: entry) {
                    Text("En cours")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                // Ligne 1 : prière + heure
                HStack {
                    Label(entry.nextPrayerName, systemImage: "moon.stars.fill")
                        .font(.headline.weight(.bold))
                    
                    Spacer()
                    
                    Text(verbatim: WidgetUtils.formatTime(entry.nextPrayerDate))
                        .font(.headline.monospacedDigit())
                }
                
                // Ligne 2 : countdown
                if let target = entry.nextPrayerDate, target > entry.date {
                    Text(target, style: .relative)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
            .widgetAccentable()
        }
        
        // ── INLINE ──
        private var inlineView: some View {
            ViewThatFits {
                Text(verbatim: "🕌 \(entry.nextPrayerName) \(WidgetUtils.formatTime(entry.nextPrayerDate))")
                Text(verbatim: "\(entry.nextPrayerName) \(WidgetUtils.formatTime(entry.nextPrayerDate))")
                Text(verbatim: WidgetUtils.formatTime(entry.nextPrayerDate))
            }
        }
    }
    
    struct SalatLockScreenWidget: Widget {
        let kind = "SalatLockWidget"
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: SalatProvider()) { entry in
                SalatLockView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            }
            .configurationDisplayName("Muslim Clock")
            .description("Prochaine prière sur l'écran verrouillé.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // WIDGET 4 : APPLE WATCH — 5 CERCLES (accessoryRectangular)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    struct WatchFiveCirclesView: View {
        let entry: SimpleEntry

        private let prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        private let shorts  = ["FJR",  "DHR",   "ASR", "MGH",     "ISH"]

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                // Rangée des 5 cercles
                HStack(spacing: 0) {
                    ForEach(Array(prayers.enumerated()), id: \.offset) { i, name in
                        let status = entry.prayerStatuses[name] ?? .future
                        VStack(spacing: 3) {
                            Circle()
                                .fill(circleFill(status))
                                .overlay(Circle().stroke(circleStroke(status), lineWidth: 1))
                                .frame(width: 14, height: 14)
                                .widgetAccentable(status == .nextNormal || status == .nextImminent)
                            Text(verbatim: shorts[i])
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundStyle(labelOpacity(status))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Prochaine prière + décompte
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: entry.nextPrayerName)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .widgetAccentable()
                    if let target = entry.nextPrayerDate, target > entry.date {
                        Text(target, style: .relative)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        private func circleFill(_ status: PrayerStatus) -> Color {
            switch status {
            case .passed:                    return .primary.opacity(0.55)
            case .nextNormal, .nextImminent: return .primary
            case .future:                    return .clear
            }
        }

        private func circleStroke(_ status: PrayerStatus) -> Color {
            switch status {
            case .future: return .primary.opacity(0.3)
            default:      return .clear
            }
        }

        private func labelOpacity(_ status: PrayerStatus) -> Color {
            switch status {
            case .nextNormal, .nextImminent: return .primary
            case .passed:                    return .primary.opacity(0.6)
            case .future:                    return .primary.opacity(0.3)
            }
        }
    }

    struct SalatWatchCirclesWidget: Widget {
        let kind = "SalatWatchCircles"
        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: SalatProvider()) { entry in
                WatchFiveCirclesView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            }
            .configurationDisplayName("Salat · 5 Cercles")
            .description("Le cycle des 5 prières sur votre cadran.")
            .supportedFamilies([.accessoryRectangular])
        }
    }
}
