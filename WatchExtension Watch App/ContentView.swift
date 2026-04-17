import SwiftUI

struct ContentView: View {
    @StateObject private var vm = WatchPrayerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if vm.isDataAvailable {
                TabView {
                    NextPrayerView(vm: vm)
                    PrayerListView(vm: vm)
                }
                .tabViewStyle(.page)
            } else {
                NoDataView()
            }
        }
        .onAppear { vm.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.refresh() }
        }
    }
}

// MARK: - Next Prayer View

struct NextPrayerView: View {
    @ObservedObject var vm: WatchPrayerViewModel

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

            VStack(spacing: 6) {
                // Date islamique
                Text(vm.islamicDateString)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))

                if let next = vm.nextPrayer {
                    PrayerOrb(prayer: next)

                    // Compte à rebours
                    Text(next.time, style: .timer)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.yellow)
                        .monospacedDigit()
                        .task(id: next.id) {
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

    var body: some View {
        List(vm.prayers) { prayer in
            HStack(spacing: 8) {
                Circle()
                    .fill(prayer.isNext ? Color.yellow : Color.white.opacity(0.15))
                    .frame(width: 5, height: 5)

                VStack(alignment: .leading, spacing: 1) {
                    Text(prayer.arabicName)
                        .font(.system(size: 14, weight: prayer.isNext ? .bold : .regular))
                        .foregroundStyle(prayer.isNext ? Color.green : .primary)
                    Text(prayer.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(prayer.time, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(prayer.isNext ? .yellow : .secondary)
            }
        }
        .listStyle(.carousel)
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
