import WidgetKit
import SwiftUI

// MARK: - Models

struct PrayerProgressData {
    let arabicName: String  // "الفجر"
    let latinInit: String   // "F"
    let time: Date
    let progress: Double    // 0.0 = futur, 1.0 = passé, 0.0-1.0 = en cours
    let isCurrent: Bool
    let isPast: Bool
}

struct MoonDayData {
    let hijriDay: Int
    let symbol: String      // SF Symbol
    let isWhiteDays: Bool
    let isToday: Bool
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let prayers: [PrayerProgressData]    // 5 prières
    let hijriArabic: String              // "١٧ رجب"
    let hijriFrench: String              // "17 Rajab"
    let moonStrip: [MoonDayData]         // [hier, auj, demain]
    let nextRefresh: Date
}

// MARK: - Data Layer

private enum PrayerData {

    struct Def {
        let arabic: String
        let init_: String
        let key: String
    }

    static let defs: [Def] = [
        Def(arabic: "الفجر",  init_: "F", key: "prayer_fajr"),
        Def(arabic: "الظهر",  init_: "D", key: "prayer_dhuhr"),
        Def(arabic: "العصر",  init_: "A", key: "prayer_asr"),
        Def(arabic: "المغرب", init_: "M", key: "prayer_maghrib"),
        Def(arabic: "العشاء", init_: "I", key: "prayer_isha"),
    ]

    static func buildEntry() -> PrayerEntry {
        let defaults = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
        let now = Date()

        // Jumu'ah : le vendredi, remplacer le label Dhuhr
        let isFriday = Calendar.current.component(.weekday, from: now) == 6
        let jumuahEnabled = defaults?.bool(forKey: "w_jumuahEnabled") ?? false
        let isFridayJumuah = isFriday && jumuahEnabled

        // Construire les definitions avec le bon label pour Dhuhr/Jumu'ah
        let effectiveDefs: [Def] = defs.enumerated().map { i, def in
            if i == 1 && isFridayJumuah {
                return Def(arabic: "الجمعة", init_: "J", key: def.key)
            }
            return def
        }

        let times: [Date?] = effectiveDefs.map { def in
            let v = defaults?.double(forKey: def.key) ?? 0
            return v > 0 ? Date(timeIntervalSince1970: v) : nil
        }
        let tomorrowFajrV = defaults?.double(forKey: "prayer_fajr_tomorrow") ?? 0
        let tomorrowFajr  = tomorrowFajrV > 0
            ? Date(timeIntervalSince1970: tomorrowFajrV)
            : now.addingTimeInterval(8 * 3600)

        let prayers: [PrayerProgressData] = effectiveDefs.indices.map { i in
            guard let prayerTime = times[i] else {
                return PrayerProgressData(arabicName: effectiveDefs[i].arabic, latinInit: effectiveDefs[i].init_,
                                          time: now, progress: 0, isCurrent: false, isPast: false)
            }
            let nextTime: Date = {
                for j in (i + 1)..<effectiveDefs.count { if let t = times[j] { return t } }
                return tomorrowFajr
            }()
            let isPast    = nextTime <= now
            let isCurrent = prayerTime <= now && nextTime > now
            let progress: Double = {
                if isPast    { return 1.0 }
                if isCurrent {
                    let total   = nextTime.timeIntervalSince(prayerTime)
                    let elapsed = now.timeIntervalSince(prayerTime)
                    return total > 0 ? max(0, min(1, elapsed / total)) : 0
                }
                return 0.0
            }()
            return PrayerProgressData(arabicName: effectiveDefs[i].arabic, latinInit: effectiveDefs[i].init_,
                                      time: prayerTime, progress: progress,
                                      isCurrent: isCurrent, isPast: isPast)
        }

        let nextRefresh: Date = prayers.contains(where: { $0.isCurrent })
            ? now.addingTimeInterval(5 * 60)
            : (prayers.first(where: { !$0.isPast && !$0.isCurrent })?.time ?? tomorrowFajr)

        return PrayerEntry(
            date: now,
            prayers: prayers,
            hijriArabic: formatHijriArabic(now),
            hijriFrench: formatHijriFrench(now),
            moonStrip: buildMoonStrip(for: now),
            nextRefresh: nextRefresh
        )
    }

    // MARK: Hijri formatting

    static func formatHijriArabic(_ date: Date) -> String {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        let comps = cal.dateComponents([.month, .day], from: date)
        let months = ["محرم","صفر","ربيع الأول","ربيع الثاني",
                      "جمادى الأولى","جمادى الثانية","رجب","شعبان",
                      "رمضان","شوال","ذو القعدة","ذو الحجة"]
        let day      = comps.day ?? 1
        let monthIdx = max(0, min(11, (comps.month ?? 1) - 1))
        let nf = NumberFormatter(); nf.locale = Locale(identifier: "ar_SA")
        let arabicDay = nf.string(from: NSNumber(value: day)) ?? "\(day)"
        return "\(arabicDay) \(months[monthIdx])"
    }

    static func formatHijriFrench(_ date: Date) -> String {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        let comps = cal.dateComponents([.month, .day], from: date)
        let months = ["Mouharram","Safar","Rabîʿ I","Rabîʿ II",
                      "Joumâda I","Joumâda II","Rajab","Chaâbane",
                      "Ramadan","Chawwâl","Dhou al-Qiʿda","Dhou al-Hijja"]
        let day      = comps.day ?? 1
        let monthIdx = max(0, min(11, (comps.month ?? 1) - 1))
        return "\(day) \(months[monthIdx])"
    }

    // MARK: Moon phase

    static func buildMoonStrip(for date: Date) -> [MoonDayData] {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        return [-1, 0, 1].compactMap { offset in
            guard let d = Calendar.current.date(byAdding: .day, value: offset, to: date) else { return nil }
            let day = hijri.component(.day, from: d)
            return MoonDayData(hijriDay: day, symbol: moonSymbol(for: day),
                               isWhiteDays: (13...15).contains(day),
                               isToday: hijri.isDateInToday(d))
        }
    }

    static func moonSymbol(for day: Int) -> String {
        switch day {
        case 1, 29, 30: return "moonphase.new.moon"
        case 2...6:     return "moonphase.waxing.crescent"
        case 7, 8:      return "moonphase.first.quarter"
        case 9...13:    return "moonphase.waxing.gibbous"
        case 14...16:   return "moonphase.full.moon"
        case 17...21:   return "moonphase.waning.gibbous"
        case 22, 23:    return "moonphase.last.quarter"
        default:        return "moonphase.waning.crescent"
        }
    }

    // MARK: Placeholder

    static func placeholder() -> PrayerEntry {
        let now = Date()
        let prayers = defs.enumerated().map { i, def in
            PrayerProgressData(
                arabicName: def.arabic, latinInit: def.init_,
                time: now.addingTimeInterval(Double(i - 2) * 3600),
                progress: i < 2 ? 1.0 : (i == 2 ? 0.55 : 0.0),
                isCurrent: i == 2, isPast: i < 2
            )
        }
        return PrayerEntry(
            date: now, prayers: prayers,
            hijriArabic: "١٧ رجب", hijriFrench: "17 Rajab",
            moonStrip: [
                MoonDayData(hijriDay: 13, symbol: "moonphase.waxing.gibbous", isWhiteDays: true,  isToday: false),
                MoonDayData(hijriDay: 14, symbol: "moonphase.full.moon",      isWhiteDays: true,  isToday: true),
                MoonDayData(hijriDay: 15, symbol: "moonphase.full.moon",      isWhiteDays: true,  isToday: false),
            ],
            nextRefresh: now.addingTimeInterval(300)
        )
    }
}

// MARK: - Timeline Provider

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry { PrayerData.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(context.isPreview ? PrayerData.placeholder() : PrayerData.buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let entry = PrayerData.buildEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.nextRefresh)))
    }
}

// MARK: - Prayer Sphere Component

struct PrayerSphereView: View {
    let prayer: PrayerProgressData
    let size: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Fond sphère
                Circle()
                    .fill(sphereFill)

                // Anneau de piste
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1.5)

                // Arc de progression
                if prayer.progress > 0 {
                    Circle()
                        .trim(from: 0, to: CGFloat(prayer.progress))
                        .stroke(arcColor, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                // Première lettre du nom arabe
                Text(String(prayer.arabicName.prefix(1)))
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(centerColor)
            }
            .frame(width: size, height: size)
            .shadow(color: glowColor, radius: prayer.isCurrent ? 5 : 0)

            // Initiale latine
            Text(prayer.latinInit)
                .font(.system(size: 6, weight: .bold, design: .rounded))
                .foregroundStyle(labelColor)
        }
    }

    private var sphereFill: AnyShapeStyle {
        if prayer.isPast {
            return AnyShapeStyle(
                RadialGradient(colors: [.indigo.opacity(0.75), .indigo.opacity(0.3)],
                               center: UnitPoint(x: 0.3, y: 0.3),
                               startRadius: 0, endRadius: size * 0.9)
            )
        } else if prayer.isCurrent {
            let inner = 0.15 + prayer.progress * 0.45
            return AnyShapeStyle(
                RadialGradient(colors: [.orange.opacity(inner), .orange.opacity(0.05)],
                               center: UnitPoint(x: 0.3, y: 0.3),
                               startRadius: 0, endRadius: size * 0.9)
            )
        } else {
            return AnyShapeStyle(Color.white.opacity(0.04))
        }
    }

    private var arcColor: Color {
        prayer.isCurrent ? .orange : .indigo.opacity(0.75)
    }

    private var centerColor: Color {
        if prayer.isPast    { return .white.opacity(0.88) }
        if prayer.isCurrent { return .orange }
        return .white.opacity(0.18)
    }

    private var glowColor: Color {
        prayer.isCurrent ? .orange.opacity(0.55) : .clear
    }

    private var labelColor: Color {
        if prayer.isCurrent { return .orange.opacity(0.9)  }
        if prayer.isPast    { return .indigo.opacity(0.75) }
        return .white.opacity(0.18)
    }
}

// MARK: - Complication View (toutes familles)

struct PrayerComplicationView: View {
    let entry: PrayerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:    circularView
        case .accessoryRectangular: rectangularView
        case .accessoryCorner:      cornerView
        default:                    inlineView
        }
    }

    // MARK: ── Circulaire — Anneau de prière en cours ──────────────────

    private var activePrayer: PrayerProgressData? {
        entry.prayers.first(where: { $0.isCurrent })
            ?? entry.prayers.first(where: { !$0.isPast })
    }

    private var circularView: some View {
        ZStack {
            if let p = activePrayer {
                // Piste
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3.5)

                // Arc (minimum 2 % pour la visibilité au démarrage)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.02, p.progress)))
                    .stroke(
                        p.isCurrent ? Color.orange : Color.indigo.opacity(0.8),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(p.arabicName)
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()

                    if p.isCurrent {
                        // Pourcentage de la fenêtre de prière écoulée
                        Text("\(Int(p.progress * 100))%")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(p.time, style: .time)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Après ʿIchâ — en attente du Fajr
                VStack(spacing: 2) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 18))
                        .widgetAccentable()
                    Text("الفجر")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(3)
    }

    // MARK: ── Rectangulaire — 5 sphères + date hijri, fond sombre ──────

    private var rectangularView: some View {
        ZStack {
            // Fond sombre dégradé
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.18),
                    Color(red: 0.02, green: 0.02, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 5) {

                // Date hijri : FR · AR
                HStack(spacing: 5) {
                    Text(entry.hijriFrench)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("·")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.25))

                    Text(entry.hijriArabic)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // 5 sphères de prière
                HStack(spacing: 0) {
                    ForEach(entry.prayers.indices, id: \.self) { i in
                        PrayerSphereView(prayer: entry.prayers[i], size: 22)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
    }

    // MARK: ── Corner — Phase lunaire (hier · auj · demain) ───────────

    private var cornerView: some View {
        let todayMoon = entry.moonStrip.first(where: { $0.isToday }) ?? entry.moonStrip.first!
        let dayText   = entry.moonStrip.map { "\($0.hijriDay)" }.joined(separator: " · ")

        return Image(systemName: todayMoon.symbol)
            .symbolRenderingMode(.hierarchical)
            .widgetAccentable()
            .foregroundStyle(todayMoon.isWhiteDays ? Color.orange : Color.white)
            .widgetLabel {
                Text(dayText)
                    .foregroundStyle(todayMoon.isWhiteDays ? Color.orange : Color.secondary)
            }
    }

    // MARK: ── Inline ─────────────────────────────────────────────────

    private var inlineView: some View {
        HStack(spacing: 4) {
            Text(entry.hijriFrench).foregroundStyle(.secondary)
            if let p = activePrayer {
                Text(p.arabicName)
                Text(p.time, style: .time)
            }
        }
    }
}

// MARK: - Widget Declaration

struct PrayerComplication: Widget {
    let kind = "PrayerComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prières · Lune")
        .description("5 sphères de prière, date hijri (FR · AR) et phase lunaire sur 3 jours.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview("Circulaire", as: .accessoryCircular) {
    PrayerComplication()
} timeline: {
    PrayerData.placeholder()
}

#Preview("Rectangulaire — 5 sphères", as: .accessoryRectangular) {
    PrayerComplication()
} timeline: {
    PrayerData.placeholder()
}

#Preview("Corner — Lune", as: .accessoryCorner) {
    PrayerComplication()
} timeline: {
    PrayerData.placeholder()
}

#Preview("Inline", as: .accessoryInline) {
    PrayerComplication()
} timeline: {
    PrayerData.placeholder()
}
