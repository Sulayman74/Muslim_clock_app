//
//  WeeklyReviewCard.swift
//  Muslim Clock — onglet Apprendre, révision hebdomadaire
//
//  Carte du hub : « À faire cette semaine (10 questions, ~6 min) » ou
//  « Fait : 8/10 ». Ouvre la session de la semaine ou la liste des thèmes.
//

import SwiftUI

struct WeeklyReviewCard: View {
    @Bindable var quiz: IlmQuizViewModel

    @State private var activeSession: QuizSessionRoute?
    @State private var showTopics = false

    /// Posé par `AppDelegate` au tap de la notification hebdo (cold start).
    @AppStorage("pendingOpenWeeklyQuiz") private var pendingOpenWeeklyQuiz = false

    var body: some View {
        Group {
            if quiz.isAvailable {
                content
            }
        }
        .sheet(item: $activeSession, onDismiss: { quiz.refresh() }) { route in
            IlmQuizView(quiz: quiz, session: route.session)
        }
        .sheet(isPresented: $showTopics) {
            IlmTopicsView(quiz: quiz)
        }
        .onAppear {
            quiz.refresh()
            quiz.rescheduleReminder()
            if pendingOpenWeeklyQuiz {
                pendingOpenWeeklyQuiz = false
                startWeekly()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .weeklyQuizTapped)) { _ in
            pendingOpenWeeklyQuiz = false
            startWeekly()
        }
    }

    private func startWeekly() {
        guard quiz.isAvailable else { return }
        activeSession = QuizSessionRoute(session: QuizSession(mode: .weekly, questions: quiz.weeklyQuestions()))
    }

    // MARK: - Contenu

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statusLine
            actions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardSecondary(cornerRadius: CornerRadius.card, tint: ModuleAccent.ilm)
        .geometryGroup()
        .animation(.smooth(duration: 0.35), value: quiz.thisWeekResult)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .foregroundStyle(ModuleAccent.ilm)
            Text("Aqîda · Fiqh · Hadith")
                .font(.caption.bold())
                .foregroundStyle(ModuleAccent.ilm)
            Spacer()
            if quiz.weekStreak > 0 {
                Label {
                    Text("\(quiz.weekStreak) sem.")
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "flame.fill")
                }
                .font(.caption.bold())
                .foregroundStyle(.orange)
                .accessibilityLabel(Text("\(quiz.weekStreak) semaines validées d'affilée"))
            }
            sizeMenu
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let result = quiz.thisWeekResult {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: result.isPassed ? "checkmark.seal.fill" : "checkmark.circle")
                    .foregroundStyle(result.isPassed ? .green : ModuleAccent.ilm)
                Text("Fait : \(result.score)/\(result.total)")
                    .font(.system(.title3, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Spacer()
            }
            .transition(.opacity)
            Text(result.isPassed
                 ? "Semaine validée. Prochaine révision la semaine prochaine."
                 : "Refais-la quand tu veux : la semaine est validée à partir de 70 %.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("À faire cette semaine")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)
                Text("\(quiz.sessionSize) questions · environ \(quiz.estimatedMinutes) min")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.65))
            }
            .transition(.opacity)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: startWeekly) {
                Label(quiz.thisWeekResult == nil ? "Commencer" : "Refaire", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(ModuleAccent.ilm.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
            }
            .sensoryFeedback(.impact(weight: .light), trigger: activeSession != nil)

            Button { showTopics = true } label: {
                Label("Par thème", systemImage: "square.grid.2x2")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(ModuleAccent.ilm)
                    .background(ModuleAccent.ilm.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
            }
        }
    }

    private var sizeMenu: some View {
        Menu {
            Picker("Taille de la session", selection: $quiz.sessionSize) {
                ForEach(WeeklyReviewPlanner.sizePresets, id: \.self) { size in
                    Text("\(size) questions").tag(size)
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.footnote.bold())
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Taille de la session"))
    }
}

/// Session à présenter en sheet (identifiable pour `sheet(item:)`).
struct QuizSessionRoute: Identifiable {
    let id = UUID()
    let session: QuizSession
}

extension Notification.Name {
    /// Émise quand l'utilisateur tape la notification de révision hebdo.
    /// MainView ouvre l'onglet Apprendre ; `WeeklyReviewCard` lance la session.
    static let weeklyQuizTapped = Notification.Name("WeeklyQuizTapped")
}
