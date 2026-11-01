//
//  IqamahCountdownView.swift
//  Muslim Clock — Décompte Adhan → Iqamah
//
//  Carte compacte visible UNIQUEMENT pendant la fenêtre [adhan, adhan + délai)
//  de la prière en cours. Le délai vient des réglages « Ma mosquée »
//  (iqamahXxxDelay). Décision pure (IqamahMath), recalculée à chaque tick —
//  stateless : un retour de background retombe automatiquement sur l'état réel.
//

import SwiftUI

// Le rappel « Dhuhr / Jumu'ah bientôt » a fusionné dans `PrayerHeroCard`
// (état « prochaine prière », teinte Jumu'ah le vendredi).

struct IqamahCountdownCard: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Délais iqamah par prière (réglés dans Settings « Ma mosquée » / Config Magique).
    @AppStorage(StorageKeys.iqamahFajrDelay)    private var iqamahFajrDelay = IqamahDefaults.fajr
    @AppStorage(StorageKeys.iqamahDhuhrDelay)   private var iqamahDhuhrDelay = IqamahDefaults.dhuhr
    @AppStorage(StorageKeys.iqamahAsrDelay)     private var iqamahAsrDelay = IqamahDefaults.asr
    @AppStorage(StorageKeys.iqamahMaghribDelay) private var iqamahMaghribDelay = IqamahDefaults.maghrib
    @AppStorage(StorageKeys.iqamahIshaDelay)    private var iqamahIshaDelay = IqamahDefaults.isha

    @State private var showLatecomerFiche = false

    private var delays: [String: Int] {
        IqamahDefaults.delays(
            fajr: iqamahFajrDelay,
            dhuhr: iqamahDhuhrDelay,
            asr: iqamahAsrDelay,
            maghrib: iqamahMaghribDelay,
            isha: iqamahIshaDelay
        )
    }

    var body: some View {
        // Cadence 2 s : le décompte (Text(timerInterval:)) est auto-rafraîchi
        // nativement ; ce tick ne sert qu'à la barre de progression et à
        // l'apparition/disparition de la carte → 1 Hz inutile.
        TimelineView(.periodic(from: .now, by: 2.0)) { context in
            let prayers = prayerVM.dailyPrayers.map { (name: $0.name, adhan: $0.date) }
            let target = IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: context.date)
            ZStack {
                if let target {
                    card(target: target, now: context.date)
                        .padding(.bottom, ZoneSpacing.intraZonePrimary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.smooth(duration: 0.35), value: target?.iqamah)
        }
        .sheet(isPresented: $showLatecomerFiche) {
            LatecomerFiqhView()
        }
    }

    // MARK: - Carte

    /// La prière est EN COURS pendant la fenêtre adhan → iqamah : teinte « now ».
    private let accent = PrayerStateTint.now

    @ViewBuilder
    private func card(target: (name: String, adhan: Date, iqamah: Date), now: Date) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "building.columns.fill")
                        .font(.title3)
                        .foregroundStyle(accent)
                        .symbolEffect(.pulse, isActive: !reduceMotion)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Iqamah de \(target.name)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Adhan à \(target.adhan.formatted(.dateTime.hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Décompte natif — se met à jour tout seul, zéro Timer custom.
                Text(timerInterval: now...target.iqamah, countsDown: true)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }

            // Progression adhan → iqamah
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: max(0, geo.size.width * IqamahMath.progress(
                            adhan: target.adhan, iqamah: target.iqamah, now: now
                        )))
                }
            }
            .frame(height: 4)

            // Lien contextuel : c'est exactement le moment où cette fiche sert.
            // Cible tactile ≥ 44 pt sur toute la largeur.
            Button {
                showLatecomerFiche = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "figure.walk.arrival")
                    Text("Arrivé en retard ? Comment compléter")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent.opacity(0.9))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCard(tint: accent)
    }
}
