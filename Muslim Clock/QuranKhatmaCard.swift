//
//  QuranKhatmaCard.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Carte d'entrée dans le tab Rappel. Affiche un résumé (% + pages/j) et ouvre
//  la sheet complète au tap.
//

import SwiftUI
import SwiftData

struct QuranKhatmaCard: View {
    @State private var vm = QuranPlanViewModel()
    @State private var showTracker = false
    @Query(sort: \ReadingEntry.date, order: .reverse) private var entries: [ReadingEntry]
    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    /// Flag posé par AppDelegate quand l'utilisateur tape une notif rappel Quran.
    /// Permet l'ouverture auto de la sheet même quand la card vient juste de monter.
    @AppStorage("pendingOpenQuranTracker") private var pendingOpenQuranTracker: Bool = false

    /// Délais iqamah par prière (configurés dans SmartSetupView / SettingsView "Ma mosquée").
    @AppStorage("iqamahFajrDelay")    private var iqamahFajrDelay: Int = 20
    @AppStorage("iqamahDhuhrDelay")   private var iqamahDhuhrDelay: Int = 15
    @AppStorage("iqamahAsrDelay")     private var iqamahAsrDelay: Int = 15
    @AppStorage("iqamahMaghribDelay") private var iqamahMaghribDelay: Int = 5
    @AppStorage("iqamahIshaDelay")    private var iqamahIshaDelay: Int = 15
    /// Marge entre la fin de prière (iqamah ou adhan) et le rappel de lecture (minutes).
    @AppStorage("quranReminderOffsetMinutes") private var quranReminderOffsetMinutes: Int = 10

    var body: some View {
        Button { showTracker = true } label: {
            content
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTracker) {
            QuranTrackerView(vm: vm)
                .presentationDetents([.large])
        }
        .onAppear {
            vm.refresh(entries: entries)
            scheduleReminders()
            consumePendingDeepLink()
        }
        .onChange(of: entries) { _, newValue in vm.refresh(entries: newValue) }
        // Re-programme les rappels quand l'utilisateur change le plan
        .onChange(of: vm.plan) { _, _ in scheduleReminders() }
        // Re-programme aussi si les horaires de prière sont recalculés (changement de méthode, DST...)
        .onChange(of: prayerVM.dailyPrayers.map { $0.date }) { _, _ in scheduleReminders() }
        // Tap notif Quran reçu pendant que la card est montée → ouverture immédiate
        .onReceive(NotificationCenter.default.publisher(for: .quranReadingTapped)) { _ in
            showTracker = true
            pendingOpenQuranTracker = false
        }
    }

    /// Si l'AppDelegate a posé le flag avant que la card soit montée, on l'honore au mount.
    private func consumePendingDeepLink() {
        if pendingOpenQuranTracker {
            showTracker = true
            pendingOpenQuranTracker = false
        }
    }

    /// Branche le scheduler avec les horaires courants de PrayerTimesViewModel.
    /// No-op si aucun plan n'est actif (le scheduler nettoie ses propres notifs en passant).
    private func scheduleReminders() {
        guard let plan = vm.plan, let progress = vm.progress else {
            QuranReminderScheduler.cancelAll()
            return
        }
        let prayers = prayerVM.dailyPrayers.map {
            ScheduledPrayer(name: $0.name, date: $0.date)
        }
        let iqamahDelays: [String: Int] = [
            "Fajr":    iqamahFajrDelay,
            "Dhuhr":   iqamahDhuhrDelay,
            "Asr":     iqamahAsrDelay,
            "Maghrib": iqamahMaghribDelay,
            "Isha":    iqamahIshaDelay,
        ]
        QuranReminderScheduler.schedule(
            prayers: prayers,
            plan: plan,
            pagesPerPrayer: progress.pagesPerPrayer,
            iqamahDelaysMinutes: iqamahDelays,
            reminderOffsetMinutes: quranReminderOffsetMinutes
        )
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.plan == nil {
            emptyState
        } else if let plan = vm.plan, let progress = vm.progress {
            activeState(plan: plan, progress: progress)
        } else {
            // Fallback : plan présent mais progression pas encore calculée
            emptyState
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.teal.opacity(0.4), .indigo.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: "book.pages.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Khatma du Quran")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("Crée ton programme de lecture")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teal.opacity(0.2), lineWidth: 1)
        )
    }

    private func activeState(plan: QuranPlan, progress: QuranPlanProgress) -> some View {
        VStack(spacing: 12) {
            // Ligne 1 : titre + streak
            HStack(spacing: 8) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.teal)
                Text("Khatma")
                    .font(.caption.bold())
                    .foregroundColor(.teal)
                Spacer()
                if vm.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(vm.streak)j")
                            .foregroundColor(.orange)
                    }
                    .font(.caption.bold())
                }
            }

            // Ligne 2 : progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.teal.opacity(0.7), .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(progress.percentComplete))
                }
            }
            .frame(height: 6)

            // Ligne 3 : pages lues / total
            HStack {
                Text("\(progress.pagesReadActual) / \(progress.totalPages) pages")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(balanceLabel(progress.balance))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(balanceColor(progress.balance))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.teal.opacity(0.25), lineWidth: 1)
        )
    }

    // Ton bienveillant : pas de rouge sur le retard, pas de "tu es en retard".
    private func balanceLabel(_ balance: Int) -> String {
        if balance >= 0 {
            return String(format: String(localized: "+%lld pages d'avance"), balance)
        }
        // Pas de signe négatif visible — phrasing positif
        return String(format: String(localized: "il reste %lld pages à rattraper"), -balance)
    }

    private func balanceColor(_ balance: Int) -> Color {
        balance >= 0 ? .green.opacity(0.85) : .orange.opacity(0.85)
    }
}
