//
//  LearnHubView.swift
//  Muslim Clock — onglet « Apprendre » (tag 4)
//
//  Layout uniquement : récitation, révision de la semaine, programmes ʿIlm.
//  Même structure que l'onglet Rappel (date, zones avec en-têtes de section).
//

import SwiftUI

struct LearnHubView: View {
    /// Un seul ViewModel ʿIlm pour la carte Programme et la révision : une
    /// erreur au quiz rétrograde une leçon, la carte le voit immédiatement.
    @State private var quiz = IlmQuizViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        WidgetDateHeader(date: .now)
                            .padding(.top, 20)

                        // VStack eager (pas Lazy) : les deep links reposent sur
                        // le onAppear des cartes, comme dans l'onglet Rappel.
                        VStack(spacing: ZoneSpacing.interZone) {
                            zone(titleFr: "Récitation", titleAr: "التِّلَاوَة", accent: ModuleAccent.quran) {
                                RecitationEntryCard()
                            }
                            zone(titleFr: "Révision de la semaine", titleAr: "مُرَاجَعَةُ الأُسْبُوع", accent: ModuleAccent.ilm) {
                                WeeklyReviewCard(quiz: quiz)
                            }
                            zone(titleFr: "Programmes", titleAr: "البَرَامِج", accent: ModuleAccent.ilm) {
                                IlmProgramCard(vm: quiz.ilm)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func zone<Content: View>(
        titleFr: LocalizedStringKey,
        titleAr: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ZoneSpacing.intraZoneSecondary) {
            ZoneSectionHeader(titleFr: titleFr, titleAr: titleAr, accent: accent)
                .padding(.bottom, ZoneSpacing.sectionHeaderBottom)
            content()
        }
    }
}

#Preview {
    LearnHubView()
        .preferredColorScheme(.dark)
}
