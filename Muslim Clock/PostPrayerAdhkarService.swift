//
//  PostPrayerAdhkarService.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 04/04/2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PostPrayerAdhkarService: ObservableObject {
    @Published var adhkarList: [Dhikr] = []

    func loadAdhkar(for prayerName: String) {
        let currentPrayerKey = prayerName.lowercased()

        Task { @MainActor in
            let githubURL = "https://sulayman74.github.io/Muslim_clock_app/post_prayer_adhkar.json"
            guard let allAdhkar = await RemoteJSONLoader.load(
                filename: "post_prayer_adhkar.json",
                remoteURL: githubURL,
                type: [Dhikr].self
            ) else {
                print("Erreur : Impossible de charger post_prayer_adhkar.json")
                return
            }

            if currentPrayerKey == "qiyam" {
                // Les adhkar "all" sont liés aux prières prescrites
                // (« دُبُرَ كُلِّ صَلَاةٍ مَكْتُوبَةٍ » — Muslim 596) : seuls les
                // adhkar propres à la prière de nuit sont affichés ici.
                self.adhkarList = allAdhkar.filter { $0.prayer == "qiyam" }
            } else {
                self.adhkarList = allAdhkar.filter { dhikr in
                    dhikr.prayer == "all" ||
                    dhikr.prayer == currentPrayerKey ||
                    (dhikr.prayer == "fajr_maghrib" && (currentPrayerKey == "fajr" || currentPrayerKey == "maghrib"))
                }
            }
        }
    }
}

// MARK: - NightPrayerCard

/// Prière de la nuit (qiyam) — zone secondaire, visible après le milieu de la
/// nuit jusqu'au Fajr. Repliée par défaut : l'en-tête donne le dernier tiers,
/// le dépli ajoute le hadith et la moitié de la nuit. Le héros garde le
/// décompte vers Fajr ; cette carte porte l'enrichissement.
struct NightPrayerCard: View {
    /// Moitié et dernier tiers de la nuit en cours — décidés par `SalatSecondaryZone`.
    let times: (middle: Date, lastThird: Date)
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PrayerStateTint.night.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PrayerStateTint.night)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Prière de la Nuit")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PrayerStateTint.night)
                        Text("Dernier tiers dès \(times.lastThird.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(verbatim: "قيام الليل")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .environment(\.layoutDirection, .rightToLeft)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("« Notre Seigneur descend chaque nuit vers le ciel le plus bas lorsqu'il ne reste que le dernier tiers... » (Bukhari)")
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Moitié de la nuit")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(times.middle.formatted(date: .omitted, time: .shortened))
                                .font(.system(.body, design: .rounded).bold())
                                .monospacedDigit()
                                .foregroundColor(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Dernier tiers")
                                .font(.caption)
                                .foregroundColor(PrayerStateTint.night)
                            Text(times.lastThird.formatted(date: .omitted, time: .shortened))
                                .font(.system(.body, design: .rounded).bold())
                                .monospacedDigit()
                                .foregroundColor(PrayerStateTint.night)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .collapsibleCard(tint: PrayerStateTint.night)
    }
}

// MARK: - SpiritualReminderCard

/// Rappel coranique rotatif (rotation par heure), zone secondaire. Replié par
/// défaut : c'est la carte la moins contextuelle de l'écran, elle ne doit pas
/// être la plus haute. L'en-tête donne la source ; le dépli ajoute le verset.
struct SpiritualReminderCard: View {

    private struct SpiritualReminder: Identifiable {
        let id = UUID()
        let arabic: String
        let french: String
        let source: String
        let icon: String
    }

    /// Accent fixe du domaine Coran (la rotation teal/indigo/violet/vert
    /// recouvrait les couleurs d'état de prière).
    private let accent = ModuleAccent.quran
    @State private var isExpanded = false

    private var currentReminder: SpiritualReminder {
        let reminders = [
            SpiritualReminder(
                arabic: "إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا",
                french: "La Salât demeure, pour les croyants, une prescription, à des temps déterminés.",
                source: "Sourate An-Nisa (4:103)",
                icon: "book.closed.fill"
            ),
            SpiritualReminder(
                arabic: "حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلَاةِ الْوُسْطَىٰ",
                french: "Soyez assidus aux Salâts, et surtout la Salât médiane.",
                source: "Sourate Al-Baqara (2:238)",
                icon: "moon.stars.fill"
            ),
            SpiritualReminder(
                arabic: "قَدْ أَفْلَحَ الْمُؤْمِنُونَ ۝ الَّذِينَ هُمْ فِي صَلَاتِهِمْ خَاشِعُونَ",
                french: "Bienheureux sont certes les croyants, ceux qui sont humbles dans leur Salât.",
                source: "Sourate Al-Mu'minun (23:1-2)",
                icon: "hands.sparkles.fill"
            ),
            SpiritualReminder(
                arabic: "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ",
                french: "Cherchez secours dans l'endurance et la Salât.",
                source: "Sourate Al-Baqara (2:45)",
                icon: "heart.fill"
            )
        ]

        // Rotation basée sur l'heure actuelle pour éviter de toujours voir le même
        let hour = Calendar.current.component(.hour, from: Date())
        let index = hour % reminders.count
        return reminders[index]
    }

    var body: some View {
        let reminder = currentReminder

        VStack(alignment: .leading, spacing: 14) {
            // En-tête cliquable (repli / dépli)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: reminder.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rappel")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(accent)
                        Text(verbatim: reminder.source)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Verset en arabe — même langage scripturaire que les cartes Coran.
                    Text(reminder.arabic)
                        .font(ScriptureFont.arabic(ScriptureFont.arabicCompact))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineSpacing(ScriptureFont.arabicLineSpacing)
                        .foregroundColor(.white)
                        .environment(\.layoutDirection, .rightToLeft)

                    // Traduction
                    Text("« \(reminder.french) »")
                        .font(ScriptureFont.translation())
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(ScriptureFont.translationLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)

                    // La source est déjà dans l'en-tête ; ici seulement le partage.
                    HStack {
                        Spacer()
                        // Partager — cible tactile 44 pt.
                        ShareLink(item: "\(reminder.arabic)\n\n\(reminder.french)\n\n— \(reminder.source)") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(accent.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .collapsibleCard(tint: accent)
    }
}

// MARK: - PostPrayerAdhkarView (Sheet)
struct PostPrayerAdhkarView: View {
    let prayerName: String
    @StateObject private var service = PostPrayerAdhkarService()
    @State private var showArabic: [Int: Bool] = [:]
    @State private var showBenefit: [Int: Bool] = [:]

    /// Clé minuscule utilisée pour le filtre et l'exception Fajr/Maghrib.
    private var prayerKey: String { prayerName.lowercased() }

    // Déduction d'un nom propre pour l'affichage
    private var displayName: String {
        if prayerKey == "qiyam" {
            return "la Prière de la Nuit"
        }
        return "la prière (\(prayerName.capitalized))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── EN-TÊTE PREMIUM ──
            VStack(spacing: 8) {
                Text("أذكار بعد الصلاة")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .environment(\.layoutDirection, .rightToLeft)

                Text("Adhkar après \(displayName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // ── LISTE DES ADHKAR ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(service.adhkarList) { dhikr in
                        // Carte partagée avec les adhkar matin/soir, en mode
                        // consultation (onTap nil ⇒ badge "x N" statique).
                        DhikrCardView(
                            dhikr: dhikr,
                            repeatCount: dhikr.effectiveRepeat(for: prayerKey),
                            count: 0,
                            isCompleted: false,
                            showArabic: showArabic[dhikr.id] ?? true,
                            showBenefit: showBenefit[dhikr.id] ?? false,
                            accentColor: .orange,
                            onTap: nil,
                            onToggleArabic: { showArabic[dhikr.id] = !(showArabic[dhikr.id] ?? true) },
                            onToggleBenefit: { showBenefit[dhikr.id] = !(showBenefit[dhikr.id] ?? false) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        // Fond harmonisé avec ton thème sombre/chaud
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.05, blue: 0.05), Color(red: 0.2, green: 0.1, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .task {
            service.loadAdhkar(for: prayerName)
        }
    }
}

// MARK: - GPSRelocationIndicator
struct GPSRelocationIndicator: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @State private var isRefreshing = false

    var body: some View {
        if prayerVM.hasMovedSignificantly {
            Button {
                // Force d'abord un point GPS frais (sinon on recalculerait avec la
                // position périmée), PUIS recalcule. Le bouton « fait tout » désormais.
                Task {
                    isRefreshing = true
                    await SharedLocationManager.shared.refreshLocation()
                    withAnimation { prayerVM.relocateAndRecalculate() }
                    isRefreshing = false
                }
            } label: {
                HStack(spacing: 6) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.blue)
                        Text("Mise à jour de la position…")
                            .font(.caption.bold())
                    } else {
                        Image(systemName: "location.fill.viewfinder")
                        Text("Recalculer position (> 15km)")
                            .font(.caption.bold())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundColor(.blue)
                .glassEffect(.regular.tint(.blue.opacity(0.2)), in: Capsule())
                // Cible tactile ≥ 44 pt (la capsule visible reste compacte).
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(isRefreshing)
            .transition(.scale.combined(with: .opacity))
        }
    }
}
