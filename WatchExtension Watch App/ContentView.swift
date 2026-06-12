import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var vm = WatchPrayerViewModel()
    @StateObject private var dailyVM = WatchDailyContentViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if vm.isDataAvailable {
                TabView {
                    NextPrayerView(vm: vm)
                    DailyContentTab(vm: dailyVM)
                    PrayerListView(vm: vm)
                    NowPlayingView()
                }
                .tabViewStyle(.page)
            } else {
                NoDataView()
            }
        }
        .onAppear {
            vm.refresh()
            dailyVM.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                vm.refresh()
                dailyVM.refresh()
            }
        }
        // Haptic discret quand la sync iPhone → Watch aboutit (NoData → Data).
        .sensoryFeedback(.success, trigger: vm.isDataAvailable)
        // Haptic léger quand on bascule sur une nouvelle prochaine prière.
        .sensoryFeedback(.impact(weight: .light), trigger: vm.nextPrayer?.time)
    }
}

// MARK: - Next Prayer View

struct NextPrayerView: View {
    @ObservedObject var vm: WatchPrayerViewModel

    private var seasonAccentColor: Color {
        let s = vm.season
        if s.isEid { return .green }
        if s.isSacredMonth { return .purple }
        if s.hijriMonth == 9 { return .yellow } // Ramadan
        if s.isFriday { return .orange }
        return .clear
    }

    var body: some View {
        ZStack {
            // Fond cosmique
            RadialGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.22),
                    Color(red: 0.02, green: 0.02, blue: 0.08)
                ],
                center: .center, startRadius: 10, endRadius: 130
            )
            .ignoresSafeArea()

            VStack(spacing: 4) {
                // Bandeau saison islamique / vendredi / Eid (banner Friday géré via WatchIslamicSeason.current)
                if vm.season.hasBanner {
                    HStack(spacing: 4) {
                        Image(systemName: vm.season.icon)
                            .font(.system(size: 9))
                        Text(vm.season.labelAr)
                            .font(.system(size: 9, weight: .bold))
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    .foregroundStyle(seasonAccentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(seasonAccentColor.opacity(0.15))
                    .clipShape(Capsule())
                }

                // Date islamique
                Text(vm.islamicDateString)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))

                if let next = vm.nextPrayer {
                    PrayerOrb(prayer: next)

                    // Compte a rebours — task ID stable (next.time) au lieu d'UUID
                    // régénéré à chaque refresh, évite les sleeps multiples en parallèle.
                    Text(next.time, style: .timer)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.yellow)
                        .monospacedDigit()
                        .task(id: next.time) {
                            let delay = next.time.timeIntervalSinceNow
                            if delay > 0 {
                                try? await Task.sleep(for: .seconds(delay + 2))
                                vm.refresh()
                            }
                        }
                } else {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                        .symbolEffect(.pulse)
                    Text("بسم الله")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Prayer Orb

private struct PrayerOrb: View {
    let prayer: WatchPrayer
    @State private var pulsing = false

    private var orbColor: Color {
        switch prayer.name {
        case "Fajr":    return .indigo
        case "Dhuhr":   return Color(red: 0.9, green: 0.72, blue: 0.15)
        case "Jumu'ah": return .orange
        case "Asr":     return .orange
        case "Maghrib": return Color(red: 0.85, green: 0.35, blue: 0.15)
        case "Isha":    return .teal
        default:        return .green
        }
    }

    var body: some View {
        ZStack {
            // Anneau pulsant (hors du clip)
            Circle()
                .strokeBorder(orbColor.opacity(0.35), lineWidth: 1)
                .frame(width: 82, height: 82)
                .scaleEffect(pulsing ? 1.15 : 1.0)
                .opacity(pulsing ? 0 : 1)
                .animation(
                    .easeOut(duration: 2.4).repeatForever(autoreverses: false),
                    value: pulsing
                )

            // Sphère (clippée)
            ZStack {
                // Corps de la sphère
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor.opacity(0.6),
                                orbColor.opacity(0.2),
                                orbColor.opacity(0.04)
                            ],
                            center: UnitPoint(x: 0.35, y: 0.28),
                            startRadius: 2,
                            endRadius: 36
                        )
                    )

                // Reflet lumineux (effet sphère 3D)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 14
                        )
                    )
                    .frame(width: 24, height: 15)
                    .offset(x: -13, y: -16)

                // Texte de la prière
                VStack(spacing: 2) {
                    Text(prayer.arabicName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(prayer.time, style: .time)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(orbColor.opacity(0.8), lineWidth: 1.5)
            )
        }
        .onAppear { pulsing = true }
    }
}

// MARK: - Prayer List View

struct PrayerListView: View {
    @ObservedObject var vm: WatchPrayerViewModel

    /// Pendant Ramadan, Maghrib s'affiche en « Iftar » (rupture du jeûne).
    private func displayName(_ prayer: WatchPrayer) -> String {
        if prayer.name == "Maghrib" && vm.season.hijriMonth == 9 {
            return String(localized: "Iftar")
        }
        return prayer.name
    }

    var body: some View {
        List(vm.prayers) { prayer in
            let isJumuah = prayer.name == "Jumu'ah"
            HStack(spacing: 8) {
                Circle()
                    .fill(prayer.isNext ? Color.yellow : (isJumuah ? Color.orange : Color.white.opacity(0.15)))
                    .frame(width: 5, height: 5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(prayer.arabicName)
                        .font(.system(size: 14, weight: (prayer.isNext || isJumuah) ? .bold : .regular))
                        .foregroundStyle(prayer.isNext ? Color.green : (isJumuah ? Color.orange : .primary))
                    Text(displayName(prayer))
                        .font(.caption2)
                        .foregroundStyle(isJumuah ? .orange : .secondary)
                }
                Spacer()
                Text(prayer.time, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(prayer.isNext ? .yellow : (isJumuah ? .orange : .secondary))
            }
        }
        .listStyle(.carousel)
    }
}

// MARK: - Daily Content Tab (Verset + Hadith du jour)

struct DailyContentTab: View {
    @ObservedObject var vm: WatchDailyContentViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if vm.hasContent {
                    DailyCard(
                        title: "Verset",
                        icon: "book.fill",
                        accent: .indigo,
                        textFR: vm.ayahFR,
                        textAR: vm.ayahAR,
                        source: vm.ayahSource
                    )
                    DailyCard(
                        title: "Hadith",
                        icon: "quote.opening",
                        accent: .teal,
                        textFR: vm.hadithFR,
                        textAR: vm.hadithAR,
                        source: vm.hadithSource
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo.opacity(0.6))
                        Text("Ouvrez l'app iPhone")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }
}

private struct DailyCard: View {
    let title: String
    let icon: String
    let accent: Color
    let textFR: String
    let textAR: String
    let source: String

    @State private var showArabic = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer()
                Text(showArabic ? "FR" : "عربي")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent.opacity(0.2))
                    .clipShape(Capsule())
            }
            .foregroundStyle(accent)

            Group {
                if showArabic, !textAR.isEmpty {
                    Text(textAR)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                } else {
                    Text(textFR)
                        .font(.system(.caption, design: .serif))
                        .italic()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(.white.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)

            if !source.isEmpty {
                Text("— \(source)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !textAR.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) { showArabic.toggle() }
            }
        }
        .sensoryFeedback(.selection, trigger: showArabic)
    }
}

// MARK: - No Data View

struct NoDataView: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.18),
                    Color(red: 0.02, green: 0.02, blue: 0.08)
                ],
                center: .center, startRadius: 10, endRadius: 110
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.15))
                        .frame(width: 58, height: 58)
                        .scaleEffect(pulsing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulsing)
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                }
                Text("Synchronisation")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Ouvrez l'app iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear { pulsing = true }
    }
}

#Preview {
    ContentView()
}
