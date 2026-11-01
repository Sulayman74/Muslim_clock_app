//
//  LearnSuggestionCard.swift
//  Muslim Clock — carte « En ce moment » (onglets Apprendre et Rappel)
//
//  Affiche LA première suggestion de `LearnSuggestionEngine` pour la fenêtre
//  courante. Deux styles :
//  - `.full` (hub Apprendre) : le tap ouvre directement la sheet cible ;
//  - `.compact` (onglet Rappel) : le tap bascule vers l'onglet Apprendre
//    (notification consommée par MainView) — la logique de routage vit à un
//    seul endroit.
//  Le dismiss (croix) masque la carte jusqu'à la PROCHAINE fenêtre, dans les
//  deux onglets (clé partagée). Aucune notification push.
//

import SwiftUI
import SwiftData

extension Notification.Name {
    /// Tap sur la carte compacte (Rappel) → MainView bascule sur l'onglet Apprendre.
    static let learnSuggestionTapped = Notification.Name("LearnSuggestionTapped")
}

struct LearnSuggestionCard: View {
    enum Style { case full, compact }
    let style: Style

    @EnvironmentObject private var prayerVM: PrayerTimesViewModel
    @Query(sort: \ReadingEntry.date, order: .reverse) private var entries: [ReadingEntry]

    /// VMs propres à la carte (pattern QuranKhatmaCard / IlmProgramCard) :
    /// état rechargé depuis le disque à chaque `refresh()`.
    @State private var quiz = IlmQuizViewModel()
    @State private var planVM = QuranPlanViewModel()

    /// Fenêtre masquée par l'utilisateur ("slot-yyyy-MM-dd") — partagée entre
    /// les deux onglets : un dismiss vaut pour toute la fenêtre.
    @AppStorage("learn_suggestion_dismissed") private var dismissedSlotKey = ""

    @State private var suggestion: LearnSuggestionKind?

    // Sheets (style .full uniquement)
    @State private var showFlashCards = false
    @State private var quizRoute: QuizSessionRoute?
    @State private var showKhatma = false
    @State private var lessonRoute: IlmLessonRoute?
    @State private var showRecitation = false
    @State private var showLibrary = false

    var body: some View {
        // Le Group survit quand la carte est absente : l'insertion/retrait est
        // animé au lieu d'un saut sec (protocole anti-wiggle, règle 4).
        Group {
            if let suggestion, !isDismissed {
                card(for: suggestion)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.3), value: suggestion)
        .animation(.smooth(duration: 0.3), value: dismissedSlotKey)
        .onAppear(perform: refresh)
        .sheet(isPresented: $showFlashCards, onDismiss: refresh) {
            IlmFlashCardView(vm: quiz.ilm)
        }
        .sheet(item: $quizRoute, onDismiss: refresh) { route in
            IlmQuizView(quiz: quiz, session: route.session)
        }
        .sheet(isPresented: $showKhatma, onDismiss: refresh) {
            QuranTrackerView(vm: planVM)
                .presentationDetents([.large])
        }
        .sheet(item: $lessonRoute, onDismiss: refresh) { route in
            IlmLessonView(vm: quiz.ilm, track: route.track, index: route.index)
        }
        .sheet(isPresented: $showRecitation, onDismiss: refresh) {
            RecitationSetupView()
        }
        .sheet(isPresented: $showLibrary) {
            QuranLibraryView()
        }
    }

    // MARK: - Calcul

    private var currentSlotKey: String {
        let dates = prayerDates
        let slot = LearnSuggestionEngine.slot(
            now: .now, fajr: dates.fajr, dhuhr: dates.dhuhr,
            maghrib: dates.maghrib, isha: dates.isha
        )
        return LearnSuggestionEngine.slotKey(slot: slot, now: .now)
    }

    private var isDismissed: Bool { dismissedSlotKey == currentSlotKey }

    private var prayerDates: (fajr: Date?, dhuhr: Date?, maghrib: Date?, isha: Date?) {
        func date(_ name: String) -> Date? {
            prayerVM.dailyPrayers.first { $0.name == name }?.date
        }
        // Le vendredi, Dhuhr peut être affiché « Jumu'ah » selon le réglage.
        return (date("Fajr"), date("Dhuhr") ?? date("Jumu'ah"), date("Maghrib"), date("Isha"))
    }

    private func refresh() {
        quiz.refresh()
        quiz.ilm.refresh()
        planVM.refresh(entries: entries)

        let dates = prayerDates
        let input = LearnSuggestionInput(
            now: .now,
            fajr: dates.fajr,
            dhuhr: dates.dhuhr,
            maghrib: dates.maghrib,
            isha: dates.isha,
            isFriday: Calendar.current.component(.weekday, from: .now) == 6,
            dueReviewCount: quiz.ilm.reviewQueue.count,
            nextLessonTitle: quiz.ilm.nextLesson?.title,
            khatmaBalance: planVM.plan != nil ? planVM.progress?.balance : nil,
            hasReadToday: entries.first.map { Calendar.current.isDateInToday($0.date) } ?? false,
            quizAvailable: quiz.isAvailable,
            weeklyQuizDone: quiz.thisWeekResult != nil,
            recitationReworkCount: RecitationProgressStore.load().versesToRework().count
        )
        suggestion = LearnSuggestionEngine.suggestions(input).first
    }

    // MARK: - Routage (style .full) / bascule d'onglet (style .compact)

    private func open(_ kind: LearnSuggestionKind) {
        guard style == .full else {
            // La carte compacte ne route pas elle-même : MainView bascule sur
            // Apprendre, où la carte pleine porte la même suggestion.
            NotificationCenter.default.post(name: .learnSuggestionTapped, object: nil)
            return
        }
        switch kind {
        case .reviewCards:
            showFlashCards = true
        case .weeklyQuiz:
            quizRoute = QuizSessionRoute(session: QuizSession(mode: .weekly, questions: quiz.weeklyQuestions()))
        case .khatmaReading:
            showKhatma = true
        case .lessonOfDay:
            if let track = quiz.ilm.activeTrack, let index = quiz.ilm.summary?.nextLessonIndex {
                lessonRoute = IlmLessonRoute(track: track, index: index)
            }
        case .recitationRework:
            showRecitation = true
        case .kahf, .nightSurahs:
            showLibrary = true
        }
    }

    private func dismiss() {
        dismissedSlotKey = currentSlotKey
    }

    // MARK: - Rendu

    @ViewBuilder
    private func card(for kind: LearnSuggestionKind) -> some View {
        let display = Self.display(for: kind, quiz: quiz)
        Button { open(kind) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(display.accent.opacity(0.22))
                        .frame(width: 44, height: 44)
                    Image(systemName: display.icon)
                        .font(.title3)
                        .foregroundStyle(display.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if style == .full {
                        Text("En ce moment")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(display.accent.opacity(0.85))
                    }
                    Text(display.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(verbatim: display.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))

                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Masquer la suggestion jusqu'à la prochaine période"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, style == .full ? 14 : 12)
            .glassCardSecondary(
                cornerRadius: CornerRadius.card,
                tint: display.accent,
                fallback: style == .compact ? GlassFallback.warm : GlassFallback.cosmic
            )
            .geometryGroup()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("learn.suggestion")
    }

    /// Textes et accents par suggestion — localisés via le catalog.
    private static func display(
        for kind: LearnSuggestionKind,
        quiz: IlmQuizViewModel
    ) -> (icon: String, accent: Color, title: LocalizedStringKey, subtitle: String) {
        switch kind {
        case .kahf:
            return ("book.fill", ModuleAccent.quran, "Sourate Al-Kahf",
                    String(localized: "La lecture du vendredi"))
        case .reviewCards(let count):
            return ("rectangle.on.rectangle.angled", ModuleAccent.ilm, "Réviser mes acquis",
                    String(format: String(localized: "%lld carte(s) due(s) aujourd'hui"), count))
        case .weeklyQuiz:
            return ("checklist", ModuleAccent.ilm, "Révision de la semaine",
                    String(format: String(localized: "%lld questions · environ %lld min"),
                           quiz.sessionSize, quiz.estimatedMinutes))
        case .khatmaReading(let behind):
            return ("book.pages.fill", ModuleAccent.quran, "Lire mon Coran",
                    behind > 0
                        ? String(format: String(localized: "%lld page(s) à rattraper"), behind)
                        : String(localized: "Les pages du jour t'attendent"))
        case .lessonOfDay(let title):
            return ("books.vertical.fill", ModuleAccent.ilm, "Leçon du jour", title)
        case .recitationRework(let count):
            return ("waveform.and.mic", ModuleAccent.quran, "Corriger ma récitation",
                    String(format: String(localized: "%lld verset(s) à retravailler"), count))
        case .nightSurahs:
            return ("moon.zzz.fill", .indigo, "Avant de dormir",
                    String(localized: "Sourate Al-Mulk"))
        }
    }
}
