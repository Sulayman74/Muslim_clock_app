//
//  PrayerHeroCard.swift
//  Muslim Clock — onglet Salat, information n°1
//
//  Un seul héros pour « quelle prière, combien de temps » : il remplace le
//  cercle « prochaine prière », la jauge « Temps du X », la carte « Prochaine :
//  X » et le rappel « Dhuhr bientôt », qui disaient la même chose trois fois.
//  Trois états : prière en cours, prochaine prière (journée), nuit (après le
//  milieu de la nuit). Le décompte est formulé en langage naturel à la minute ;
//  la barre suit la cadence adaptative de PrayerCountdownMath.
//

import SwiftUI

struct PrayerHeroCard: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel

    /// Seuil de la barre au-delà duquel la fin de fenêtre devient pressante.
    private static let urgentProgress = 0.85

    private enum Situation: Equatable {
        /// Fenêtre de prière en cours (start → end).
        case inWindow(window: PrayerWindow, start: Date, end: Date)
        /// Journée hors fenêtre (lever du soleil → Dhuhr / Jumu'ah).
        case upcoming(name: String, target: Date, start: Date?)
        /// Nuit après le milieu de la nuit : prochaine = Fajr.
        case night(target: Date, middle: Date?, lastThird: Date?)
    }

    private var situation: Situation? {
        if prayerVM.currentPrayerWindow != .none,
           let start = prayerVM.currentWindowStart,
           let end = prayerVM.currentWindowEnd {
            return .inWindow(window: prayerVM.currentPrayerWindow, start: start, end: end)
        }
        guard let target = prayerVM.nextPrayerDate else { return nil }
        if prayerVM.nextPrayerName == "Fajr" {
            return .night(target: target, middle: prayerVM.middleOfNight, lastThird: prayerVM.lastThirdOfNight)
        }
        return .upcoming(name: prayerVM.nextPrayerName, target: target, start: prayerVM.sunriseTime)
    }

    var body: some View {
        ZStack {
            if let situation {
                card(situation)
                    .padding(.bottom, ZoneSpacing.intraZonePrimary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.35), value: situation)
    }

    // MARK: - Carte

    private func card(_ situation: Situation) -> some View {
        let tint = tint(for: situation)
        let range = barRange(for: situation)

        return VStack(alignment: .leading, spacing: 14) {
            // En-tête : quelle prière.
            HStack(spacing: 8) {
                Image(systemName: icon(for: situation))
                    .font(.title3)
                Text(title(for: situation))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(verbatim: arabicTitle(for: situation))
                    .font(.title3.bold())
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .foregroundStyle(tint)

            // Combien de temps — à la minute, en langage naturel.
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 4) {
                    Text(bigLabel(for: situation, now: context.date))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(subtitle(for: situation, now: context.date))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
                .animation(.smooth(duration: 0.35), value: context.date)
            }

            if let range {
                progressBar(start: range.start, end: range.end, tint: tint)
                    // Re-crée le schedule si les bornes changent (recalcul DST/GPS/réglages).
                    .id(range.end)
            }

            HStack {
                Text(verbatim: footLeading(for: situation, range: range))
                Spacer()
                Text(verbatim: footTrailing(for: situation))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(20)
        .glassCard(tint: tint)
        .accessibilityElement(children: .combine)
    }

    /// Barre start → end, cadence adaptative, rouge quand la fin presse (en fenêtre).
    private func progressBar(start: Date, end: Date, tint: Color) -> some View {
        let cadence = PrayerCountdownMath.barCadence(start: start, end: end)
        return TimelineView(.periodic(from: .now, by: cadence)) { context in
            let progress = PrayerCountdownMath.progress(start: start, end: end, now: context.date)
            let isUrgent = prayerVM.currentPrayerWindow != .none && progress > Self.urgentProgress
            let color = isUrgent ? Color.red : tint
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress))
                        .animation(.linear(duration: cadence), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Contenu par situation

    private func tint(for s: Situation) -> Color {
        switch s {
        case .inWindow: PrayerStateTint.now
        case .upcoming(let name, _, _): name == "Jumu'ah" ? PrayerStateTint.jumuah : PrayerStateTint.upcoming
        case .night: PrayerStateTint.night
        }
    }

    private func icon(for s: Situation) -> String {
        switch s {
        case .inWindow(let window, _, _): window.icon
        case .upcoming(let name, _, _): name == "Jumu'ah" ? "building.columns.fill" : "hourglass"
        case .night: "moon.stars.fill"
        }
    }

    /// Nom affiché de la fenêtre en cours (Jumu'ah le vendredi si activée).
    private func windowName(_ window: PrayerWindow) -> String {
        if window == .dhuhr && prayerVM.isFridayJumuah { return "Jumu'ah" }
        return window.rawValue
    }

    private func title(for s: Situation) -> String {
        switch s {
        case .inWindow(let window, _, _): String(localized: "Temps du \(windowName(window))")
        case .upcoming(let name, _, _): String(localized: "Prochaine : \(name)")
        case .night: String(localized: "Prochaine : Fajr")
        }
    }

    private func arabicTitle(for s: Situation) -> String {
        switch s {
        case .inWindow(let window, _, _): window.arabicName
        case .upcoming(let name, _, _): name == "Jumu'ah" ? "الجمعة" : PrayerWindow(rawValue: name)?.arabicName ?? ""
        case .night: "قيام الليل"
        }
    }

    private func bigLabel(for s: Situation, now: Date) -> String {
        switch s {
        case .inWindow(_, _, let end):
            String(localized: "reste \(PrayerCountdownMath.remainingLabel(until: end, now: now))")
        case .upcoming(_, let target, _), .night(let target, _, _):
            String(localized: "dans \(PrayerCountdownMath.remainingLabel(until: target, now: now))")
        }
    }

    private func subtitle(for s: Situation, now: Date) -> String {
        switch s {
        case .inWindow(let window, _, let end):
            let time = end.formatted(date: .omitted, time: .shortened)
            switch window {
            case .fajr: return String(localized: "jusqu'au lever du soleil à \(time)")
            case .isha: return String(localized: "jusqu'au milieu de la nuit à \(time)")
            default: return String(localized: "jusqu'à \(prayerVM.nextPrayerName) à \(time)")
            }
        case .upcoming(let name, let target, _):
            return String(localized: "\(name) à \(target.formatted(date: .omitted, time: .shortened))")
        case .night(let target, _, let lastThird):
            let fajr = target.formatted(date: .omitted, time: .shortened)
            if let lastThird, lastThird > now {
                return String(localized: "Fajr à \(fajr) · dernier tiers de la nuit dès \(lastThird.formatted(date: .omitted, time: .shortened))")
            }
            return String(localized: "Fajr à \(fajr) · dernier tiers de la nuit")
        }
    }

    private func barRange(for s: Situation) -> (start: Date, end: Date)? {
        switch s {
        case .inWindow(_, let start, let end): (start, end)
        case .upcoming(_, let target, let start): start.map { ($0, target) }
        case .night(let target, let middle, _): middle.map { ($0, target) }
        }
    }

    private func footLeading(for s: Situation, range: (start: Date, end: Date)?) -> String {
        guard let range else { return "" }
        return "\(range.start.formatted(date: .omitted, time: .shortened)) → \(range.end.formatted(date: .omitted, time: .shortened))"
    }

    private func footTrailing(for s: Situation) -> String {
        switch s {
        case .inWindow:
            String(localized: "Prochaine : \(prayerVM.nextPrayerName) \(prayerVM.nextPrayerTime)")
        case .upcoming:
            String(localized: "depuis le lever du soleil")
        case .night(_, let middle, _):
            middle.map { String(localized: "milieu de la nuit \($0.formatted(date: .omitted, time: .shortened))") } ?? ""
        }
    }
}
