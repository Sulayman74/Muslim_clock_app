//
//  SalatSecondaryZone.swift
//  Muslim Clock — onglet Salat, zone « Pour aller plus loin »
//
//  La zone décide ici QUELLES cartes contextuelles s'affichent (préparation,
//  nuit, adhkar du moment, voyage) et passe à chacune ses données : les cartes
//  ne portent plus de logique de visibilité. Le garde-fou `ZoneTwoPlanner`
//  plafonne et ordonne les candidates, pour que les jours chargés ne fassent
//  jamais un mur de cartes.
//

import SwiftUI

struct SalatSecondaryZone: View {
    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    @AppStorage(TravelKeys.active) private var travelModeActive = false

    /// Toggles DEBUG — consommés ici, les fonctions de fenêtre restent pures.
    @AppStorage("debugForceWuduWindow") private var debugForceWuduWindow = false
    @AppStorage("debugForceFriday") private var debugForceFriday = false

    /// Catégories du livret (cache local puis réseau), pour « À réciter maintenant ».
    @State private var categories: [AdhkarCategory] = []

    /// Couleur d'état de la prière (fil conducteur avec la zone prioritaire).
    let accent: Color
    let season: IslamicSeasonInfo
    let isFriday: Bool
    /// Prière de contexte pour la sunnah (en cours sinon prochaine, Jumu'ah le vendredi).
    let prayerContext: String
    /// `false` tant qu'aucun horaire n'est connu : pas de capsule « avant … ».
    let hasPrayers: Bool

    /// Les fenêtres sont à la minute près : un tick toutes les 30 s suffit.
    private static let refreshCadence: TimeInterval = 30

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.refreshCadence)) { context in
            let now = context.date
            let wudu = wuduVariant(now: now)
            let night = nightTimes
            let adhkar = adhkarCategory(now: now, wuduVisible: wudu != nil)
            let plan = plan(wudu: wudu != nil, night: night != nil, adhkar: adhkar != nil)

            // `spacing: 0` : chaque carte porte son espacement bas (dans sa
            // condition pour les conditionnelles) → aucun trou quand elle manque.
            VStack(alignment: .leading, spacing: 0) {
                ZoneSectionHeader(
                    titleFr: "Pour aller plus loin",
                    titleAr: "لِلاسْتِزَادَة",
                    accent: accent
                )
                .padding(.bottom, ZoneSpacing.sectionHeaderBottom + ZoneSpacing.intraZoneSecondary)

                // Se préparer à la prière (wudû'/ghusl) — la préparation précède la récitation.
                ZoneCardSlot(isVisible: plan.contains(.wudu)) {
                    if let wudu { WuduMomentCard(variant: wudu) }
                }

                // Qiyam : après le milieu de la nuit, repliée (hadith + horaires).
                ZoneCardSlot(isVisible: plan.contains(.night)) {
                    if let night { NightPrayerCard(times: night) }
                }

                ZoneCardSlot(isVisible: plan.contains(.adhkarMoment)) {
                    if let adhkar { AdhkarMomentCard(category: adhkar) }
                }

                // Deux portes d'entrée Adhkar côte à côte (même famille).
                HStack(spacing: 12) {
                    AdhkarQuickAccessButton(compact: true)
                    AdhkarBookletButton(compact: true)
                }
                .padding(.bottom, ZoneSpacing.intraZoneSecondary)

                // ProphetSunnahCardView couvre aussi les Rawatib (champ `sunnahRecommendation`).
                ProphetSunnahCardView(
                    sunnah: ProphetSunnahProvider.current(
                        prayerName: prayerContext,
                        season: season,
                        isFriday: isFriday
                    ),
                    contextPrayerName: hasPrayers ? prayerContext : nil,
                    isPrayerInWindow: prayerVM.currentPrayerWindow != .none
                )
                .padding(.bottom, ZoneSpacing.intraZoneSecondary)

                // Rappel coranique rotatif (replié par défaut).
                SpiritualReminderCard()
                    .padding(.bottom, ZoneSpacing.intraZoneSecondary)

                // Facilités du voyageur (qasr / jamʿ / jeûne).
                ZoneCardSlot(isVisible: plan.contains(.travel)) {
                    TravelFiqhCard()
                }

                MoonWidgetView(date: now)
            }
        }
        .task {
            if categories.isEmpty {
                let loaded = await RemoteJSONLoader.load(
                    filename: "hisn_adhkar.json",
                    remoteURL: "https://sulayman74.github.io/Muslim_clock_app/hisn_adhkar.json",
                    type: [AdhkarCategory].self
                )
                if let loaded {
                    categories = loaded
                } else {
                    print("SalatSecondaryZone : hisn_adhkar.json indisponible (réseau et cache)")
                }
            }
        }
    }

    // MARK: - Candidates

    /// Cartes retenues par le garde-fou pour les candidates du moment.
    private func plan(wudu: Bool, night: Bool, adhkar: Bool) -> Set<ZoneTwoPlanner.Card> {
        var candidates = Set<ZoneTwoPlanner.Card>()
        if wudu { candidates.insert(.wudu) }
        if night { candidates.insert(.night) }
        if adhkar { candidates.insert(.adhkarMoment) }
        if travelModeActive { candidates.insert(.travel) }
        return ZoneTwoPlanner.plan(candidates: candidates)
    }

    private var isFridayEffective: Bool {
        #if DEBUG
        if debugForceFriday { return true }
        #endif
        return isFriday
    }

    private func wuduVariant(now: Date) -> WuduWindowMath.Variant? {
        #if DEBUG
        if debugForceWuduWindow {
            let time = prayerVM.nextPrayerDate ?? now.addingTimeInterval(15 * 60)
            return isFridayEffective ? .fridayGhusl(time: time)
                                     : .wudu(prayer: prayerVM.nextPrayerName, time: time)
        }
        #endif
        let prayers = prayerVM.dailyPrayers.map { (name: $0.name, time: $0.date) }
        return WuduWindowMath.target(prayers: prayers, now: now, isFriday: isFridayEffective)
    }

    /// Moitié et dernier tiers de la nuit en cours, après le milieu de la nuit et avant Fajr.
    private var nightTimes: (middle: Date, lastThird: Date)? {
        guard prayerVM.currentPrayerWindow == .none,
              prayerVM.nextPrayerName == "Fajr",
              let middle = prayerVM.middleOfNight,
              let lastThird = prayerVM.lastThirdOfNight else { return nil }
        return (middle, lastThird)
    }

    /// Catégorie du livret pertinente maintenant. Fusion wudû' : quand « Se
    /// préparer à la prière » est visible, elle couvre déjà les ablutions — on
    /// passe à la suggestion suivante (mosquée, adhan…).
    private func adhkarCategory(now: Date, wuduVisible: Bool) -> AdhkarCategory? {
        let suggested = AdhkarSuggestion.suggested(
            from: categories,
            now: now,
            prayerDates: prayerVM.dailyPrayers.map(\.date),
            fajr: prayerVM.fajrDate,
            lastThirdOfNight: prayerVM.lastThirdOfNight,
            isTraveling: travelModeActive
        )
        return suggested.first { !(wuduVisible && $0.moments.contains(AdhkarMoment.wudu)) }
    }
}
