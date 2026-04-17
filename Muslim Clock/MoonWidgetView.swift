import SwiftUI

#Preview("Aujourd'hui") {
    ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.12).ignoresSafeArea()
        MoonWidgetView(date: .now)
            .padding()
    }
}

#Preview("Nouvelle Lune (Hilal)") {
    // Calcule le 1er du prochain mois hégirien
    let hijri = Calendar(identifier: .islamicUmmAlQura)
    var dc = hijri.dateComponents([.year, .month], from: .now)
    dc.month = (dc.month ?? 1) + 1
    if (dc.month ?? 1) > 12 { dc.month = 1; dc.year = (dc.year ?? 1446) + 1 }
    dc.day = 1
    let newMoonDate = hijri.date(from: dc) ?? .now

    return ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.12).ignoresSafeArea()
        MoonWidgetView(date: newMoonDate)
            .padding()
    }
}

// MARK: - ═══════════════════════════════════════════════════
// MODÈLE
// ═══════════════════════════════════════════════════════════

struct MoonDayInfo: Identifiable {
    let id = UUID()
    let date: Date
    let hijriDay: Int
    let symbol: String
    let phaseName: String
    let illumination: Double   // 0.0 → 1.0
    let isToday: Bool
    let isWhiteDays: Bool      // Jours blancs : 13, 14, 15
}

// MARK: - ═══════════════════════════════════════════════════
// CALCULATEUR — SOURCE UNIQUE : CALENDRIER HÉGIRIEN
// Aucune dépendance réseau, instantané, offline
// ═══════════════════════════════════════════════════════════

enum MoonPhaseCalculator {

    private static let hijri = Calendar(identifier: .islamicUmmAlQura)

    /// Renvoie les infos lunaires pour une date grégorienne
    static func info(for date: Date) -> MoonDayInfo {
        let hijriDay = hijri.component(.day, from: date)
        // Illumination : approximation cosinus sur cycle de 29.5 j
        let illumination = (1 - cos(2 * .pi * Double(hijriDay) / 29.5)) / 2

        return MoonDayInfo(
            date: date,
            hijriDay: hijriDay,
            symbol: symbol(for: hijriDay),
            phaseName: phaseName(for: hijriDay),
            illumination: illumination,
            isToday: hijri.isDateInToday(date),
            isWhiteDays: (13...15).contains(hijriDay)
        )
    }

    /// Renvoie `count` jours centrés sur `date` (2 avant, auj., 2 après si count = 5)
    static func strip(centeredOn date: Date, count: Int = 5) -> [MoonDayInfo] {
        let half = count / 2
        return (-half...half).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: date).map { info(for: $0) }
        }
    }

    // MARK: Mapping jour hégirien → SF Symbol

    static func symbol(for hijriDay: Int) -> String {
        switch hijriDay {
        case 1, 29, 30: return "moonphase.new.moon"
        case 2...6:     return "moonphase.waxing.crescent"
        case 7, 8:      return "moonphase.first.quarter"
        case 9...13:    return "moonphase.waxing.gibbous"
        case 14...16:   return "moonphase.full.moon"
        case 17...21:   return "moonphase.waning.gibbous"
        case 22, 23:    return "moonphase.last.quarter"
        default:        return "moonphase.waning.crescent"   // 24...28
        }
    }

    // MARK: Mapping jour hégirien → nom de phase

    static func phaseName(for hijriDay: Int) -> String {
        switch hijriDay {
        case 1, 29, 30: return String(localized: "Nouvelle Lune")
        case 2...6:     return String(localized: "Croissant ↑")
        case 7, 8:      return String(localized: "1er Quartier")
        case 9...13:    return String(localized: "Gibbeuse ↑")
        case 14...16:   return String(localized: "Pleine Lune")
        case 17...21:   return String(localized: "Gibbeuse ↓")
        case 22, 23:    return String(localized: "Der. Quartier")
        default:        return String(localized: "Croissant ↓")
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// CARD PRINCIPALE — 5 JOURS
// ═══════════════════════════════════════════════════════════

struct MoonWidgetView: View {
    var date: Date = .now

    private var strip: [MoonDayInfo] { MoonPhaseCalculator.strip(centeredOn: date) }
    private var today: MoonDayInfo   { MoonPhaseCalculator.info(for: date) }

    private var hijriMonthYear: String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .islamicUmmAlQura)
        fmt.locale   = Locale(identifier: "fr_FR")
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date).capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── EN-TÊTE ──
            HStack {
                Label("Phases Lunaires", systemImage: "moon.stars.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .labelStyle(.titleAndIcon)

                Spacer()

                Text(verbatim: hijriMonthYear)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // ── BANDEAU "JOURS BLANCS" (visible si applicable) ──
            if today.isWhiteDays {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("Jours Blancs — Jeûne recommandé (13-14-15)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
            }

            // ── BANDE 5 JOURS ──
            HStack(spacing: 0) {
                ForEach(strip) { day in
                    MoonDayCell(info: day)
                }
            }

            // ── CARTE INVOCATION HILAL (1er jour du mois) ──
            if today.hijriDay == 1 {
                NewMoonInvocationCard()
            }

            // ── PHASE + ILLUMINATION DU JOUR ──
            HStack(spacing: 6) {
                Text(verbatim: today.phaseName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(today.isWhiteDays ? .orange : .white.opacity(0.7))

                Spacer()

                // Barre d'illumination
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1)).frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: today.isWhiteDays
                                        ? [.orange.opacity(0.6), .orange]
                                        : [.indigo.opacity(0.6), .indigo],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * today.illumination, height: 4)
                    }
                }
                .frame(width: 60, height: 4)

                Text(verbatim: "\(Int(today.illumination * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    today.isWhiteDays ? Color.orange.opacity(0.4) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - ═══════════════════════════════════════════════════
// CARTE INVOCATION — HILAL (1er MUHARRAM / début de mois)
// ═══════════════════════════════════════════════════════════

private struct NewMoonInvocationCard: View {
    @State private var expanded = false

    private let arabic  = "اللَّهُمَّ أَهِلَّهُ عَلَيْنَا بِالأَمْنِ وَالإِيمَانِ وَالسَّلَامَةِ وَالإِسْلَامِ رَبِّي وَرَبُّكَ اللَّه"
    private let french  = "« Ô Allah ! Fais paraître ce croissant sur nous avec sécurité et foi, préservation et Islam. Mon Seigneur et ton Seigneur est Allah. »"
    private let source  = "At-Tirmidhî (n°3451) — Talha ibn ʿUbaydullāh رضي الله عنه\nHadîth hasan, authentifié par Al-Albânî"
    private let benefits: [(ar: String, fr: String)] = [
        ("يُمْن",    "Bénédiction"),
        ("إيمان",   "Foi"),
        ("سَلامَة", "Sécurité"),
        ("إسلام",   "Islam")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── EN-TÊTE ──
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text("Invocation du Hilal")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            // ── TEXTE ARABE (toujours visible) ──
            Text(arabic)
                .font(.system(size: 15, weight: .medium))
                .environment(\.layoutDirection, .rightToLeft)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineSpacing(5)

            // ── SECTION DÉTAILS (dépliable) ──
            if expanded {
                Divider().background(.white.opacity(0.12))

                // Traduction française
                Text(french)
                    .font(.system(size: 11, design: .rounded))
                    .italic()
                    .foregroundStyle(.white.opacity(0.75))
                    .lineSpacing(2)

                // Source
                Text(source)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineSpacing(2)

                // Bienfaits
                HStack(spacing: 6) {
                    ForEach(benefits, id: \.ar) { b in
                        VStack(spacing: 1) {
                            Text(b.ar)
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                            Text(b.fr)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundStyle(.yellow.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - ═══════════════════════════════════════════════════
// CELLULE D'UN JOUR
// ═══════════════════════════════════════════════════════════

private struct MoonDayCell: View {
    let info: MoonDayInfo

    private var dayLabel: String {
        if info.isToday { return "Auj." }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: info.date).prefix(3)).capitalized
    }

    private var accent: Color { info.isWhiteDays ? .orange : .indigo }

    var body: some View {
        VStack(spacing: 5) {

            // Jour de semaine ou "Auj."
            Text(dayLabel)
                .font(.system(size: info.isToday ? 10 : 9,
                              weight: info.isToday ? .bold : .medium,
                              design: .rounded))
                .foregroundStyle(info.isToday ? .white : .white.opacity(0.4))

            // Symbole lune
            Image(systemName: info.symbol)
                .font(.system(size: info.isToday ? 28 : 20))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(info.isWhiteDays ? .orange :
                                    (info.isToday ? .white : .white.opacity(0.65)))
                .frame(height: info.isToday ? 32 : 24)

            // Jour hégirien
            Text(verbatim: "\(info.hijriDay)")
                .font(.system(size: info.isToday ? 13 : 10,
                              weight: .bold, design: .rounded))
                .foregroundStyle(info.isToday ? .white : .white.opacity(0.55))
        }
        .padding(.vertical, info.isToday ? 10 : 6)
        .frame(maxWidth: .infinity)
        .background {
            if info.isToday {
                RoundedRectangle(cornerRadius: 14)
                    .fill(accent.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(accent.opacity(0.45), lineWidth: 1)
                    )
            }
        }
    }
}
