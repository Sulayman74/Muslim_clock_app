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

// MARK: - Rappel avant Dhuhr / Jumu'ah

/// Carte d'anticipation visible seulement dans la dernière heure avant Dhuhr
/// (`DhuhrCountdownMath`). Emphase « Jumu'ah » le vendredi. Cadencée à 10 s :
/// pas de barre de progression ici, et le décompte `Text(timerInterval:)` se met
/// à jour nativement — inutile de réveiller l'UI chaque seconde.
struct DhuhrCountdownCard: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 10.0)) { context in
            let prayers = prayerVM.dailyPrayers.map { (name: $0.name, time: $0.date) }
            if let target = DhuhrCountdownMath.target(prayers: prayers, now: context.date) {
                card(target: target, now: context.date)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func card(target: (label: String, time: Date), now: Date) -> some View {
        let isJumuah = target.label == "Jumu'ah"
        let accent: Color = isJumuah ? .indigo : .yellow

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: isJumuah ? "building.columns.fill" : "sun.max.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isJumuah ? "Jumu'ah bientôt" : "Dhuhr bientôt")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("à \(target.time.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text(timerInterval: now...target.time, countsDown: true)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}

struct IqamahCountdownCard: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel

    // Délais iqamah par prière (réglés dans Settings « Ma mosquée » / Config Magique).
    @AppStorage("iqamahFajrDelay")    private var iqamahFajrDelay = 20
    @AppStorage("iqamahDhuhrDelay")   private var iqamahDhuhrDelay = 15
    @AppStorage("iqamahAsrDelay")     private var iqamahAsrDelay = 15
    @AppStorage("iqamahMaghribDelay") private var iqamahMaghribDelay = 5
    @AppStorage("iqamahIshaDelay")    private var iqamahIshaDelay = 15

    @State private var showLatecomerFiche = false

    private var delays: [String: Int] {
        [
            "Fajr": iqamahFajrDelay,
            "Dhuhr": iqamahDhuhrDelay,
            "Asr": iqamahAsrDelay,
            "Maghrib": iqamahMaghribDelay,
            "Isha": iqamahIshaDelay,
        ]
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let prayers = prayerVM.dailyPrayers.map { (name: $0.name, adhan: $0.date) }
            if let target = IqamahMath.iqamahTarget(prayers: prayers, delaysMinutes: delays, now: context.date) {
                card(target: target, now: context.date)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $showLatecomerFiche) {
            LatecomerFiqhView()
        }
    }

    // MARK: - Carte

    @ViewBuilder
    private func card(target: (name: String, adhan: Date, iqamah: Date), now: Date) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "building.columns.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse)
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
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }

            // Progression adhan → iqamah
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: max(0, geo.size.width * IqamahMath.progress(
                            adhan: target.adhan, iqamah: target.iqamah, now: now
                        )))
                }
            }
            .frame(height: 4)

            // Lien contextuel : c'est exactement le moment où cette fiche sert.
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
                .foregroundStyle(.green.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }
}
