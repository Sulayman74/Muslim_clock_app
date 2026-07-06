//
//  IlmTrackerView.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Sheet plein écran : vue principale du module (pattern QuranTrackerView).
//  Ring de progression, stats, leçon du jour, liste des parcours.
//

import SwiftUI

struct IlmTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: IlmViewModel

    @State private var showSetup = false
    @State private var showReview = false
    /// Route vers une leçon (parcours + index) — sheet(item:).
    @State private var lessonRoute: IlmLessonRoute?

    var body: some View {
        NavigationStack {
            ZStack {
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                if !IlmContentLoader.shared.isAvailable {
                    contentUnavailable
                } else if vm.plan == nil {
                    emptyState
                } else if let track = vm.activeTrack, let summary = vm.summary {
                    activeContent(track: track, summary: summary)
                }
            }
            .navigationTitle("Programme ʿIlm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if vm.plan != nil {
                        Button { showSetup = true } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSetup) {
                IlmPlanSetupView(vm: vm)
            }
            .sheet(item: $lessonRoute) { route in
                IlmLessonView(vm: vm, track: route.track, index: route.index)
            }
            .sheet(isPresented: $showReview) {
                IlmFlashCardView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { vm.refresh() }
    }

    // MARK: - États vides

    /// Contenu bundlé indisponible (JSON absent/corrompu) — état neutre, jamais de crash.
    private var contentUnavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundStyle(.purple.opacity(0.7))
            Text("Contenu indisponible")
                .font(.headline)
                .foregroundColor(.white)
            Text("Réinstalle l'application si le problème persiste.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
            Text("Apprends les fondements")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Les 3 Fondements, les 4 Règles et les 40 Hadiths de Nawawi — en arabe, avec leur traduction, à ton rythme.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showSetup = true } label: {
                Text("Commencer")
                    .bold()
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.purple)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: showSetup)
        }
    }

    // MARK: - Contenu actif

    private func activeContent(track: IlmTrack, summary: IlmProgressSummary) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                progressRing(summary: summary)
                statRow(summary: summary)
                rhythmCard(track: track, summary: summary)

                if let nextIndex = summary.nextLessonIndex {
                    Button {
                        lessonRoute = IlmLessonRoute(track: track, index: nextIndex)
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("Étudier la leçon du jour")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.purple.gradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: lessonRoute != nil)
                } else {
                    trackCompletedBanner(track: track)
                }

                if !vm.reviewQueue.isEmpty {
                    reviewButton
                }

                tracksSection

                gentleReminder
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private func progressRing(summary: IlmProgressSummary) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(summary.percentComplete))
                .stroke(
                    LinearGradient(colors: [.purple.opacity(0.7), .purple], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(summary.percentComplete * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                if summary.weekStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark").foregroundStyle(.purple)
                        Text("\(summary.weekStreak) semaine(s)")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                }
            }
        }
        .frame(width: 180, height: 180)
        .padding(.top, 20)
    }

    private func statRow(summary: IlmProgressSummary) -> some View {
        HStack(spacing: 12) {
            statCell(value: "\(summary.completedLessons)", label: String(localized: "Acquises"))
            statCell(value: "\(summary.totalLessons - summary.completedLessons)", label: String(localized: "Restantes"))
            statCell(value: estimatedEndLabel(summary), label: String(localized: "Fin estimée"))
        }
    }

    private func estimatedEndLabel(_ summary: IlmProgressSummary) -> String {
        guard let end = summary.estimatedEndDate else { return "✓" }
        return end.formatted(.dateTime.day().month(.abbreviated))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rhythmCard(track: IlmTrack, summary: IlmProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "metronome.fill").foregroundStyle(.purple)
                Text("Ton rythme")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
            }
            Text("**\(vm.plan?.lessonsPerWeek ?? 0) leçon(s)/semaine** — \(balanceLabel(summary.balance))")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            if let nextIndex = summary.nextLessonIndex {
                Text("Prochaine : \(track.lessons[nextIndex].title)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // Ton bienveillant : pas de rouge, phrasé positif (même règle que la Khatma).
    private func balanceLabel(_ balance: Int) -> String {
        if balance >= 0 {
            return String(format: String(localized: "+%lld leçon(s) d'avance"), balance)
        }
        return String(format: String(localized: "il reste %lld leçon(s) à rattraper"), -balance)
    }

    /// Session de révision espacée — visible uniquement quand des cartes sont dues.
    private var reviewButton: some View {
        Button { showReview = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Réviser mes acquis")
                        .bold()
                    Text("\(vm.reviewQueue.count) carte(s) due(s) aujourd'hui — 2 minutes")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showReview)
    }

    private func trackCompletedBanner(track: IlmTrack) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(.green.opacity(0.85))
            Text("Parcours terminé — الحمد لله")
                .font(.headline)
                .foregroundColor(.white)
            Text("Choisis un nouveau parcours ci-dessous, ou révise librement les leçons.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Liste des parcours

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Les trois textes")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)

            ForEach(vm.tracks) { track in
                trackRow(track)
            }
        }
        .padding(.top, 6)
    }

    private func trackRow(_ track: IlmTrack) -> some View {
        let completed = vm.completedCount(in: track)
        let total = track.lessons.count
        let isActive = vm.plan?.trackID == track.id

        return Button {
            // Ouvre le parcours à sa première leçon non acquise (ou la 1ʳᵉ si terminé).
            let index = IlmMath.nextLessonIndex(in: track, progress: vm.progress) ?? 0
            lessonRoute = IlmLessonRoute(track: track, index: index)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(verbatim: track.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        if isActive {
                            Text("En cours")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.purple)
                                .chipStyle(color: .purple)
                        }
                        if completed == total {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.green.opacity(0.85))
                        }
                    }
                    Text(verbatim: "\(track.titleArabic) · \(track.author)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.55))

                    // Mini barre de progression du parcours
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(Color.purple.opacity(0.8))
                                .frame(width: total > 0 ? geo.size.width * CGFloat(completed) / CGFloat(total) : 0)
                        }
                    }
                    .frame(height: 4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.purple.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var gentleReminder: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink.opacity(0.6))
            Text("« Celui qui emprunte un chemin à la recherche d'une science, Allah lui facilite par cela un chemin vers le Paradis. » — Muslim 2699")
                .font(.caption)
                .italic()
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

// MARK: - Route leçon

/// Wrapper Identifiable pour le `sheet(item:)` (pattern ResumeRoute de QuranTrackerView).
struct IlmLessonRoute: Identifiable {
    let track: IlmTrack
    let index: Int
    var id: String { "\(track.id):\(index)" }
}
