//
//  IlmTopicsView.swift
//  Muslim Clock — onglet Apprendre, révision par thème
//
//  Thèmes rangés par domaine (aqîda, fiqh, hadith) avec leur maîtrise.
//  Un tap lance un entraînement libre sur le thème (non compté dans la semaine).
//

import SwiftUI

struct IlmTopicsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var quiz: IlmQuizViewModel

    @State private var activeSession: QuizSessionRoute?

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: ZoneSpacing.interZone) {
                        ForEach(QuizDomain.allCases, id: \.self) { domain in
                            let topics = quiz.topics(in: domain)
                            if !topics.isEmpty {
                                section(domain: domain, topics: topics)
                            }
                        }
                        Text("La maîtrise compte les questions dont ta dernière réponse est juste.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Thèmes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $activeSession, onDismiss: { quiz.refresh() }) { route in
                IlmQuizView(quiz: quiz, session: route.session)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(domain: QuizDomain, topics: [QuizTopic]) -> some View {
        VStack(alignment: .leading, spacing: ZoneSpacing.intraZoneSecondary) {
            ZoneSectionHeader(titleFr: domainTitle(domain), titleAr: domainArabic(domain), accent: ModuleAccent.ilm)
                .padding(.bottom, ZoneSpacing.sectionHeaderBottom)
            ForEach(topics) { topic in
                topicRow(topic)
            }
        }
    }

    private func topicRow(_ topic: QuizTopic) -> some View {
        let mastery = quiz.mastery(topicID: topic.id)
        return Button {
            let questions = quiz.topicQuestions(topicID: topic.id)
            activeSession = QuizSessionRoute(session: QuizSession(mode: .topic(topic.id), questions: questions))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: topic.titleFr)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(verbatim: topic.titleAr)
                        .font(ScriptureFont.arabic(18))
                        .foregroundStyle(.white.opacity(0.6))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule()
                            .fill(ModuleAccent.ilm.gradient)
                            .frame(width: geo.size.width * mastery.ratio)
                    }
                }
                .frame(height: 6)
                HStack {
                    Text("\(mastery.correct)/\(mastery.total) maîtrisées")
                        .monospacedDigit()
                    Spacer()
                    Text(verbatim: mastery.ratio.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardSecondary(cornerRadius: CornerRadius.card, tint: ModuleAccent.ilm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Lance un entraînement sur ce thème"))
    }

    private func domainTitle(_ domain: QuizDomain) -> LocalizedStringKey {
        switch domain {
        case .aqidah: "Croyance (ʿaqîda)"
        case .fiqh: "Jurisprudence (fiqh)"
        case .hadith: "Hadith"
        }
    }

    private func domainArabic(_ domain: QuizDomain) -> String {
        switch domain {
        case .aqidah: "العَقِيدَة"
        case .fiqh: "الفِقْه"
        case .hadith: "الحَدِيث"
        }
    }
}
