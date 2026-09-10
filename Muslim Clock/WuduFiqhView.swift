//
//  WuduFiqhView.swift
//  Muslim Clock — Fiche « Les ablutions » (wudû' + ghusl/bienséances du vendredi)
//
//  Sheet de référence affichant le contenu statique de `WuduFiqh.swift`,
//  + carte d'accès (section Références du tab Rappel) + carte contextuelle
//  à l'approche d'une prière (zone secondaire du tab Salat).
//  Layout + bindings uniquement — le contenu est data (cf. CLAUDE.md).
//

import SwiftUI

// MARK: - Fiche (sheet)

struct WuduFiqhView: View {
    /// `true` : ouvre la fiche sur la section vendredi (carte contextuelle ghusl).
    var scrollToJumuah: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {

                        // ── Header ──
                        VStack(spacing: 8) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(wuduAccent)
                            Text("La purification pour la prière")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("Le wudû' pas à pas et le ghusl du vendredi — avec les preuves.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 28)

                        // ── Mérites ──
                        sectionCard(WuduFiqhContent.meritSection)

                        // ── Le wudû' pas à pas ──
                        stepsCard

                        // ── Annulatifs ──
                        sectionCard(WuduFiqhContent.nullifiersSection)

                        // ── Vendredi : ghusl + bienséances ──
                        fridayCard
                            .id("jumuah")

                        // ── Cadrage ──
                        Text(verbatim: WuduFiqhContent.disclaimer)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    // Ancre vendredi (sans animation : positionnement initial,
                    // pas de saut visible — anti-wiggle).
                    if scrollToJumuah {
                        proxy.scrollTo("jumuah", anchor: .top)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(14)
            }
        }
    }

    // MARK: - Rubrique avec dalils

    private func sectionCard(_ section: WuduSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(section.title, systemImage: section.icon)
                .font(.headline)
                .foregroundStyle(wuduAccent)

            Text(verbatim: section.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            ForEach(section.dalils) { dalil in
                dalilView(dalil, accent: wuduAccent)
            }

            Text(verbatim: section.scholarNote)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(wuduAccent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dalilView(_ dalil: WuduDalil, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: dalil.arabic)
                .font(.custom("AmiriQuran-Regular", size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
            Text(verbatim: dalil.translation)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            Text(verbatim: dalil.reference)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent.opacity(0.9))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Le wudû' pas à pas

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Le wudû' pas à pas", systemImage: "list.number")
                .font(.headline)
                .foregroundStyle(wuduAccent)

            dalilView(WuduFiqhContent.quranicBasis, accent: wuduAccent)

            ForEach(WuduFiqhContent.steps) { step in
                stepRow(step)
            }

            // L'invocation qui suit — et les huit portes.
            VStack(alignment: .leading, spacing: 6) {
                Label("Après le wudû'", systemImage: "hands.sparkles.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                dalilView(WuduFiqhContent.postWuduDua, accent: wuduAccent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(wuduAccent.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func stepRow(_ step: WuduStep) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(verbatim: "\(step.id)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(wuduAccent.opacity(0.6)))
                Text(verbatim: step.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
            }
            Text(verbatim: step.detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            if let arabic = step.arabic {
                Text(verbatim: arabic)
                    .font(.custom("AmiriQuran-Regular", size: 19))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            if let reference = step.reference {
                Text(verbatim: reference)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(wuduAccent.opacity(0.9))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Vendredi (section à accent vert — miroir de la janâza indigo)

    private var fridayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Le vendredi — ghusl et bienséances", systemImage: "building.columns.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text(verbatim: WuduFiqhContent.fridayGhuslSection.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            ForEach(WuduFiqhContent.fridayGhuslSection.dalils) { dalil in
                dalilView(dalil, accent: .green)
            }

            ForEach(WuduFiqhContent.fridayAdab) { adab in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(verbatim: "\(adab.id)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.green.opacity(0.6)))
                        Label(adab.title, systemImage: adab.icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Text(verbatim: adab.detail)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    if let reference = adab.reference {
                        Text(verbatim: reference)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green.opacity(0.9))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(verbatim: WuduFiqhContent.fridayGhuslSection.scholarNote)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Carte d'accès (tab Rappel, section « Références »)

struct WuduFiqhAccessCard: View {
    @State private var showFiche = false

    var body: some View {
        Button {
            showFiche = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(wuduAccent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "drop.fill")
                        .font(.title3)
                        .foregroundStyle(wuduAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Les ablutions — wudû'")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Comment faire, pas à pas · les preuves · ghusl du vendredi")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .glassCardSecondary(cornerRadius: 16, tint: wuduAccent, fallback: GlassFallback.warm)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showFiche)
        .sheet(isPresented: $showFiche) {
            WuduFiqhView()
        }
    }
}

// MARK: - Carte contextuelle (tab Salat, approche d'une prière)

/// « Se préparer à la prière » : apparaît dans la fenêtre pré-prière
/// (45 min ; 3 h avant Jumu'ah pour le ghusl). Enseigne — pendant que
/// l'AdhkarMomentCard, elle, fait réciter. Tap → fiche (ancrée vendredi
/// si variante ghusl).
struct WuduMomentCard: View {
    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    @State private var showFiche = false
    @State private var ficheAnchorsJumuah = false

    /// Toggles DEBUG — consommés au call site, la fonction de fenêtre reste pure.
    @AppStorage("debugForceWuduWindow") private var debugForceWuduWindow = false
    @AppStorage("debugForceFriday") private var debugForceFriday = false

    private var isFriday: Bool {
        #if DEBUG
        if debugForceFriday { return true }
        #endif
        return Calendar.current.component(.weekday, from: Date()) == 6
    }

    var body: some View {
        // Le TimelineView survit quand la carte est absente : c'est le conteneur
        // qui anime l'insertion/retrait (pattern DhuhrCountdownCard). Cadence
        // 30 s — la fenêtre est à la minute près.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if let variant = variant(now: context.date) {
                card(variant)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(isPresented: $showFiche) {
            WuduFiqhView(scrollToJumuah: ficheAnchorsJumuah)
        }
    }

    private func variant(now: Date) -> WuduWindowMath.Variant? {
        #if DEBUG
        if debugForceWuduWindow {
            let time = prayerVM.nextPrayerDate ?? now.addingTimeInterval(15 * 60)
            return isFriday ? .fridayGhusl(time: time)
                            : .wudu(prayer: prayerVM.nextPrayerName, time: time)
        }
        #endif
        let prayers = prayerVM.dailyPrayers.map { (name: $0.name, time: $0.date) }
        return WuduWindowMath.target(prayers: prayers, now: now, isFriday: isFriday)
    }

    private func card(_ variant: WuduWindowMath.Variant) -> some View {
        let isGhusl: Bool
        if case .fridayGhusl = variant { isGhusl = true } else { isGhusl = false }

        return Button {
            ficheAnchorsJumuah = isGhusl
            showFiche = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(wuduAccent)
                    Text(isGhusl ? "Se préparer à Jumu'ah" : "Se préparer à la prière")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(wuduAccent)
                    Spacer()
                    if isGhusl {
                        // Badge vendredi — grammaire exacte de FridaySalawatMiniReminder.
                        Text("Vendredi")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.green.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Text(isGhusl ? "Le ghusl du vendredi et ses bienséances" : "Les ablutions — wudû'")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text(verbatim: isGhusl
                     ? "غُسْلُ يَوْمِ الْجُمُعَةِ وَاجِبٌ عَلَى كُلِّ مُحْتَلِمٍ"
                     : "مِفْتَاحُ الصَّلَاةِ الطُّهُورُ")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .padding(16)
            .glassCardSecondary(tint: wuduAccent)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: showFiche)
    }
}
