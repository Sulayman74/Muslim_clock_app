import WidgetKit
import SwiftUI

// MARK: - Models

struct PrayerProgressData {
    let arabicName: String  // "الفجر"
    let latinInit: String   // "F"
    let time: Date
    let nextTime: Date      // Début de la prière suivante (fin de la fenêtre)
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
    let moonToday: MoonDayData           // Phase lunaire du jour courant
    let nextRefresh: Date
    let tomorrowFajr: Date?              // Pour le countdown après Isha
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
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
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

        // Sunrise : fin de la fenêtre Fajr
        let sunriseV = defaults?.double(forKey: "prayer_sunrise") ?? 0
        let sunrise: Date? = sunriseV > 0 ? Date(timeIntervalSince1970: sunriseV) : nil

        // Moitié de la nuit : fin de la fenêtre Isha
        // middleOfNight = maghrib + (fajr_demain - maghrib) / 2
        let middleOfNight: Date? = {
            guard let maghrib = times[3] else { return nil } // index 3 = Maghrib
            let nightDuration = tomorrowFajr.timeIntervalSince(maghrib)
            guard nightDuration > 0 else { return nil }
            return maghrib.addingTimeInterval(nightDuration / 2)
        }()

        let prayers: [PrayerProgressData] = effectiveDefs.indices.map { i in
            let nextTime = nextWindowEnd(
                for: i,
                in: effectiveDefs,
                times: times,
                sunrise: sunrise,
                middleOfNight: middleOfNight,
                tomorrowFajr: tomorrowFajr
            )
            guard let prayerTime = times[i] else {
                return PrayerProgressData(arabicName: effectiveDefs[i].arabic, latinInit: effectiveDefs[i].init_,
                                          time: now, nextTime: nextTime, progress: 0, isCurrent: false, isPast: false)
            }
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
                                      time: prayerTime, nextTime: nextTime, progress: progress,
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
            moonToday: moonToday(for: now),
            nextRefresh: nextRefresh,
            tomorrowFajr: tomorrowFajrV > 0 ? tomorrowFajr : nil
        )
    }

    /// Calcule la fin de la fenêtre d'une prière donnée (= début de la prière suivante).
    /// - Fajr : se termine au lever du soleil (`sunrise`) si disponible.
    /// - Isha : se termine à la moitié de la nuit (`middleOfNight`) si disponible.
    /// - Autres : début de la prochaine prière non-nulle, sinon Fajr de demain.
    private static func nextWindowEnd(
        for i: Int,
        in defs: [Def],
        times: [Date?],
        sunrise: Date?,
        middleOfNight: Date?,
        tomorrowFajr: Date
    ) -> Date {
        switch i {
        case 0:
            if let sr = sunrise { return sr }
            return times[1] ?? tomorrowFajr
        case 4:
            if let mid = middleOfNight { return mid }
            return tomorrowFajr
        default:
            for j in (i + 1)..<defs.count { if let t = times[j] { return t } }
            return tomorrowFajr
        }
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

    /// Phase lunaire pour la date courante (un seul jour, plus de strip 3-jours).
    static func moonToday(for date: Date) -> MoonDayData {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let day = hijri.component(.day, from: date)
        return MoonDayData(
            hijriDay: day,
            symbol: moonSymbol(for: day),
            isWhiteDays: (13...15).contains(day),
            isToday: true
        )
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
                nextTime: now.addingTimeInterval(Double(i - 1) * 3600),
                progress: i < 2 ? 1.0 : (i == 2 ? 0.55 : 0.0),
                isCurrent: i == 2, isPast: i < 2
            )
        }
        return PrayerEntry(
            date: now, prayers: prayers,
            hijriArabic: "١٧ رجب", hijriFrench: "17 Rajab",
            moonToday: MoonDayData(hijriDay: 14, symbol: "moonphase.full.moon", isWhiteDays: true, isToday: true),
            nextRefresh: now.addingTimeInterval(300),
            tomorrowFajr: now.addingTimeInterval(8 * 3600)
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

// MARK: - Micro Sphere (rectangulaire — ligne du bas)

struct MicroSphere: View {
    let prayer: PrayerProgressData

    var body: some View {
        Circle()
            .fill(fillStyle)
            .frame(width: prayer.isCurrent ? 8 : 6,
                   height: prayer.isCurrent ? 8 : 6)
            .overlay(
                Circle()
                    .stroke(.secondary, lineWidth: prayer.isCurrent || prayer.isPast ? 0 : 0.8)
            )
            .widgetAccentable(prayer.isCurrent)
    }

    private var fillStyle: AnyShapeStyle {
        if prayer.isCurrent { return AnyShapeStyle(.tint) }            // tintée par la watch face
        if prayer.isPast    { return AnyShapeStyle(.primary.opacity(0.65)) }
        return AnyShapeStyle(Color.clear)
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

    // MARK: ── Circulaire — Countdown vers la prochaine prière ──────────

    /// La prière en cours (pour l'anneau de progression)
    private var currentPrayer: PrayerProgressData? {
        entry.prayers.first(where: { $0.isCurrent })
    }

    /// La prochaine prière (celle qu'on attend)
    private var nextUpcomingPrayer: PrayerProgressData? {
        entry.prayers.first(where: { !$0.isPast && !$0.isCurrent })
    }

    /// Nom arabe de la prochaine prière à afficher (gère le cas Isha → Fajr demain)
    private var heroNextName: String {
        if currentPrayer != nil, let next = nextUpcomingPrayer { return next.arabicName }
        if currentPrayer != nil { return "الفجر" } // Isha en cours, prochain = Fajr demain
        if let next = nextUpcomingPrayer { return next.arabicName }
        return "الفجر" // après Isha, avant Fajr demain
    }

    /// Heure cible vers laquelle on compte (start de la prochaine prière)
    private var heroNextTime: Date? {
        if currentPrayer != nil, let next = nextUpcomingPrayer { return next.time }
        if currentPrayer != nil { return entry.tomorrowFajr }
        if let next = nextUpcomingPrayer { return next.time }
        return entry.tomorrowFajr
    }

    private var circularView: some View {
        ZStack {
            if let current = currentPrayer {
                // On est entre deux prières : anneau = progression actuelle, texte = prochaine prière
                let next = nextUpcomingPrayer

                // Piste
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3.5)

                // Arc de progression de la fenêtre en cours
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.02, current.progress)))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    // Nom de la PROCHAINE prière (pas l'actuelle)
                    Text(next?.arabicName ?? current.arabicName)
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()

                    // Countdown jusqu'à la prochaine prière
                    Text(current.nextTime, style: .timer)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            } else if let next = nextUpcomingPrayer {
                // Avant la première prière du jour (avant Fajr)
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3.5)

                VStack(spacing: 1) {
                    Text(next.arabicName)
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()

                    Text(next.time, style: .timer)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            } else if let fajr = entry.tomorrowFajr {
                // Après Isha — countdown vers le Fajr demain
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3.5)

                VStack(spacing: 1) {
                    Text("الفجر")
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()

                    Text(fajr, style: .timer)
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Pas de données
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

    // MARK: ── Rectangulaire — Countdown héros ─────────────────────────

    private var rectangularView: some View {
        // Layout compact : pour tenir dans le slot rectangular (~40-50pt de hauteur)
        // sans dépasser sur petits cadrans (40/41mm). Fonts réduites d'un cran et
        // spacing serré de 2 → 1.
        VStack(alignment: .leading, spacing: 1) {

            // Ligne 1 : nom prochaine prière + heure
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(heroNextName)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let target = heroNextTime {
                    Text(target, style: .time)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            // Ligne 2 : countdown live (.title3 au lieu de .title2)
            if let target = heroNextTime {
                Text(target, style: .timer)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .widgetAccentable()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            // Ligne 3 : 5 micro-sphères + date hijri
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(entry.prayers.indices, id: \.self) { i in
                        MicroSphere(prayer: entry.prayers[i])
                    }
                }

                Spacer(minLength: 4)

                Text(entry.hijriFrench)
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: ── Corner — Phase lunaire du jour ───────────

    private var cornerView: some View {
        let todayMoon = entry.moonToday

        return Image(systemName: todayMoon.symbol)
            .symbolRenderingMode(.hierarchical)
            .widgetAccentable()
            .foregroundStyle(todayMoon.isWhiteDays ? Color.orange : Color.white)
            .widgetLabel {
                Text("\(todayMoon.hijriDay)")
                    .foregroundStyle(todayMoon.isWhiteDays ? Color.orange : Color.secondary)
            }
    }

    // MARK: ── Inline ─────────────────────────────────────────────────

    private var inlineView: some View {
        HStack(spacing: 4) {
            Text(entry.hijriFrench).foregroundStyle(.secondary)
            if let next = nextUpcomingPrayer {
                Text(next.arabicName)
                Text(next.time, style: .time)
            } else if let current = currentPrayer {
                Text(current.arabicName)
                Text(current.nextTime, style: .timer)
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
        .description("5 sphères de prière, date hijri (FR · AR) et phase lunaire du jour.")
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
