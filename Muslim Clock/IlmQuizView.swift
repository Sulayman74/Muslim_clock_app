//
//  IlmQuizView.swift
//  Muslim Clock — onglet Apprendre, révision hebdomadaire
//
//  Une question par écran. Le choix est verrouillé après la réponse, puis
//  l'explication et la preuve (dalil) apparaissent. Bascule FR/AR par opacité
//  (anti-wiggle n°3), compteurs en chiffres tabulaires (n°2).
//

import SwiftUI

struct IlmQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Bindable var quiz: IlmQuizViewModel

    @State private var session: QuizSession
    /// Langue d'affichage du contenu religieux (FR ou arabe), indépendante de la langue de l'app.
    @State private var showArabic = false
    @State private var lessonRoute: IlmLessonRoute?
    /// Déclencheurs haptiques (succès / erreur) : un compteur suffit à les rejouer.
    @State private var correctTick = 0
    @State private var wrongTick = 0

    init(quiz: IlmQuizViewModel, session: QuizSession) {
        self.quiz = quiz
        _session = State(initialValue: session)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                if session.isFinished {
                    QuizResultView(
                        session: session,
                        topicTitle: quiz.topicTitle(for:),
                        onOpenLesson: openLesson(for:),
                        onClose: { dismiss() }
                    )
                    .transition(.opacity)
                } else if let question = session.current {
                    questionPage(question)
                        .id(question.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: session.index)
            .animation(.smooth(duration: 0.3), value: session.isFinished)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !session.isFinished {
                        Text("\(session.index + 1)/\(session.total)")
                            .font(.caption.bold())
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                            .accessibilityLabel(Text("Question \(session.index + 1) sur \(session.total)"))
                    }
                }
            }
            .sheet(item: $lessonRoute) { route in
                IlmLessonView(vm: quiz.ilm, track: route.track, index: route.index)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: correctTick)
        .sensoryFeedback(.warning, trigger: wrongTick)
        .onAppear { showArabic = locale.language.languageCode?.identifier == "ar" }
        .onChange(of: session.isFinished) { _, finished in
            if finished, session.mode == .weekly, session.total > 0 {
                quiz.finishWeeklySession(score: session.score, total: session.total)
            }
        }
    }

    private var title: LocalizedStringKey {
        switch session.mode {
        case .weekly: "Révision de la semaine"
        case .topic: "Révision par thème"
        }
    }

    // MARK: - Page question

    private func questionPage(_ question: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            progressBar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    questionHeader(question)
                    prompt(question)
                    choices(question)
                    // Vue conditionnelle au milieu du scroll : conteneur qui survit
                    // + transition keyée sur la réponse (anti-wiggle n°4).
                    Group {
                        if session.isAnswered {
                            QuizExplanationCard(question: question, showArabic: showArabic)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.smooth(duration: 0.35), value: session.isAnswered)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            nextButton
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule()
                    .fill(ModuleAccent.ilm.gradient)
                    .frame(width: geo.size.width * progressRatio)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.smooth(duration: 0.3), value: progressRatio)
        .accessibilityHidden(true)
    }

    private var progressRatio: CGFloat {
        guard session.total > 0 else { return 0 }
        let answered = session.index + (session.isAnswered ? 1 : 0)
        return CGFloat(answered) / CGFloat(session.total)
    }

    private func questionHeader(_ question: QuizQuestion) -> some View {
        HStack(spacing: 8) {
            Text(kindLabel(question.kind))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ModuleAccent.ilm)
                .chipStyle(color: ModuleAccent.ilm)
            Text(verbatim: quiz.topicTitle(for: question))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
            Spacer()
            LanguageToggleChip(isArabic: showArabic) {
                showArabic.toggle()
            }
            .foregroundStyle(ModuleAccent.ilm)
        }
    }

    private func kindLabel(_ kind: QuizQuestionKind) -> LocalizedStringKey {
        switch kind {
        case .masala: "Notion"
        case .dalil: "Preuve"
        case .application: "Cas pratique"
        }
    }

    /// Énoncé FR et AR superposés : la hauteur est celle du plus long, le toggle
    /// ne fait que changer l'opacité (aucun saut).
    private func prompt(_ question: QuizQuestion) -> some View {
        ZStack(alignment: .topLeading) {
            Text(verbatim: question.promptFr)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showArabic ? 0 : 1)
                .accessibilityHidden(showArabic)

            Text(verbatim: question.promptAr)
                .font(ScriptureFont.arabic(ScriptureFont.arabicCompact))
                .lineSpacing(8)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showArabic ? 1 : 0)
                .accessibilityHidden(!showArabic)
        }
        .animation(.smooth(duration: 0.25), value: showArabic)
    }

    private func choices(_ question: QuizQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                QuizChoiceButton(
                    choice: choice,
                    state: choiceState(index: index, question: question),
                    showArabic: showArabic
                ) {
                    select(index)
                }
            }
        }
    }

    private func choiceState(index: Int, question: QuizQuestion) -> QuizChoiceButton.ChoiceState {
        guard let selected = session.selectedChoice else { return .idle }
        if index == question.correctIndex { return .correct }
        if index == selected { return .wrong }
        return .dimmed
    }

    private var nextButton: some View {
        Button(action: advance) {
            Text(session.isLastQuestion ? "Voir le résultat" : "Question suivante")
                .bold()
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(session.isAnswered ? AnyShapeStyle(ModuleAccent.ilm.gradient) : AnyShapeStyle(.white.opacity(0.08)))
                .foregroundStyle(session.isAnswered ? .white : .white.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
        }
        .disabled(!session.isAnswered)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.smooth(duration: 0.2), value: session.isAnswered)
    }

    // MARK: - Actions

    private func select(_ index: Int) {
        guard let outcome = session.select(index) else { return }
        quiz.answer(outcome.question, choiceIndex: index)
        if outcome.correct { correctTick += 1 } else { wrongTick += 1 }
    }

    private func advance() {
        session.advance()
    }

    private func openLesson(for question: QuizQuestion) {
        lessonRoute = quiz.lessonRoute(for: question)
    }
}

// MARK: - Bouton de choix

struct QuizChoiceButton: View {
    enum ChoiceState: Equatable {
        case idle, correct, wrong, dimmed
    }

    let choice: QuizChoice
    let state: ChoiceState
    let showArabic: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                icon
                    .frame(width: 22)
                ZStack(alignment: .topLeading) {
                    Text(verbatim: choice.fr)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showArabic ? 0 : 1)
                    Text(verbatim: choice.ar)
                        .font(ScriptureFont.arabic(19))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(showArabic ? 1 : 0)
                }
                .multilineTextAlignment(.leading)
            }
            .foregroundStyle(.white.opacity(state == .dimmed ? 0.45 : 1))
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous)
                    .stroke(borderColor, lineWidth: state == .idle ? 1 : 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .animation(.smooth(duration: 0.25), value: state)
        .animation(.smooth(duration: 0.25), value: showArabic)
        .accessibilityLabel(Text(verbatim: showArabic ? choice.ar : choice.fr))
        .accessibilityValue(accessibilityState)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .idle, .dimmed:
            Image(systemName: "circle")
                .foregroundStyle(.white.opacity(0.35))
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .wrong:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var background: Color {
        switch state {
        case .idle, .dimmed: .white.opacity(0.06)
        case .correct: .green.opacity(0.18)
        case .wrong: .orange.opacity(0.18)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle: .white.opacity(0.1)
        case .dimmed: .clear
        case .correct: .green.opacity(0.7)
        case .wrong: .orange.opacity(0.7)
        }
    }

    private var accessibilityState: Text {
        switch state {
        case .idle: Text("")
        case .dimmed: Text("")
        case .correct: Text("Bonne réponse")
        case .wrong: Text("Ta réponse, incorrecte")
        }
    }
}

// MARK: - Explication + preuve

struct QuizExplanationCard: View {
    let question: QuizQuestion
    let showArabic: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Explication", systemImage: "lightbulb.fill")
                .font(.caption.bold())
                .foregroundStyle(ModuleAccent.ilm)

            Text(verbatim: explanation)
                .font(ScriptureFont.translation())
                .lineSpacing(ScriptureFont.translationLineSpacing)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            if !question.dalil.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preuve")
                        .font(.caption2.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.5))
                    ForEach(Array(question.dalil.enumerated()), id: \.offset) { _, dalil in
                        Label {
                            Text(verbatim: dalilLabel(dalil))
                                .font(ScriptureFont.source())
                                .foregroundStyle(ModuleAccent.ilm.opacity(0.9))
                        } icon: {
                            Image(systemName: dalil.kind == .quran ? "book.closed.fill" : "quote.opening")
                                .foregroundStyle(dalil.kind == .quran ? ModuleAccent.quran : ModuleAccent.hadith)
                        }
                    }
                }
            }

            if let scholarRef = question.scholarRef, !scholarRef.isEmpty {
                Text(verbatim: "— \(scholarRef)")
                    .font(ScriptureFont.source())
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .scriptureCard(accent: ModuleAccent.ilm)
    }

    /// L'explication arabe n'existe pas toujours : on retombe sur le français.
    private var explanation: String {
        if showArabic, let ar = question.explanationAr, !ar.isEmpty { return ar }
        return question.explanationFr
    }

    private func dalilLabel(_ dalil: QuizDalil) -> String {
        switch dalil.kind {
        case .quran:
            return String(format: String(localized: "Coran %@"), dalil.ref)
        case .hadith:
            if let grading = dalil.grading, !grading.isEmpty {
                return "\(dalil.ref) — \(grading)"
            }
            return dalil.ref
        }
    }
}

// MARK: - Résultat

struct QuizResultView: View {
    let session: QuizSession
    let topicTitle: (QuizQuestion) -> String
    let onOpenLesson: (QuizQuestion) -> Void
    let onClose: () -> Void

    private var ratio: Double {
        session.total > 0 ? Double(session.score) / Double(session.total) : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: ratio >= WeeklySessionResult.passRatio ? "checkmark.seal.fill" : "book.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(ratio >= WeeklySessionResult.passRatio ? .green : ModuleAccent.ilm)
                    .padding(.top, 24)

                Text(verbatim: ratio >= WeeklySessionResult.passRatio ? "ما شاء الله" : "بارك الله فيك")
                    .font(ScriptureFont.arabic(26))
                    .foregroundStyle(.white)

                Text("\(session.score)/\(session.total)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel(Text("Score : \(session.score) sur \(session.total)"))

                Text(session.mode == .weekly
                     ? (ratio >= WeeklySessionResult.passRatio
                        ? "Semaine validée. La régularité fait la science."
                        : "Chaque erreur est une leçon : revois-la, elle reviendra en révision.")
                     : "Entraînement terminé.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                if !session.mistakes.isEmpty {
                    mistakesList
                }

                Button(action: onClose) {
                    Text("Fermer")
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(ModuleAccent.ilm.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var mistakesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("À revoir")
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.55))
            ForEach(session.mistakes) { question in
                Button { onOpenLesson(question) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: question.promptFr)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: topicTitle(question))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer(minLength: 0)
                        if question.lessonId != nil {
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCardSecondary(cornerRadius: CornerRadius.badge, tint: .orange)
                }
                .buttonStyle(.plain)
                .disabled(question.lessonId == nil)
                .accessibilityHint(question.lessonId == nil ? Text("") : Text("Ouvre la leçon correspondante"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
