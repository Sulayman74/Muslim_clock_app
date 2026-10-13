//
//  IlmFlashCardView.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Session de révision espacée (Leitner). Recto : titre + amorce du texte arabe
//  (« récite la suite »). Verso : matn complet + traduction + auto-évaluation
//  (su / presque / à revoir) qui pilote la boîte de Leitner.
//

import SwiftUI

struct IlmFlashCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: IlmViewModel

    /// Snapshot de la file au montage — la notation ne réordonne pas la session en cours.
    @State private var queue: [IlmReviewCard] = []
    @State private var index = 0
    @State private var isRevealed = false
    /// Compteur de cartes sues (affiché en fin de session).
    @State private var knownCount = 0
    @State private var sessionDone = false

    /// Préférence de lecture PARTAGÉE avec le lecteur Coran et la leçon : la
    /// révision est une lecture du matn, elle suit le même papier.
    @AppStorage("quranReadingTheme") private var readingTheme: ReadingTheme = .dark
    private var theme: ReadingTheme { readingTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                if sessionDone || queue.isEmpty {
                    doneState
                } else {
                    cardContent(queue[index])
                }
            }
            .navigationTitle("Révision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !sessionDone && !queue.isEmpty {
                        Text("\(index + 1)/\(queue.count)")
                            .font(.caption.bold())
                            .foregroundColor(theme.textTertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .sensoryFeedback(.success, trigger: sessionDone)
        .onAppear {
            queue = vm.reviewQueue
            sessionDone = queue.isEmpty
        }
    }

    // MARK: - Carte

    private func cardContent(_ card: IlmReviewCard) -> some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 14) {
                    // En-tête : parcours d'origine + titre de la leçon
                    Text(verbatim: card.trackTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ModuleAccent.ilm)
                        .chipStyle(color: ModuleAccent.ilm)
                    Text(verbatim: card.lesson.title)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.center)

                    // Amorce (recto) ou matn complet (verso)
                    VStack(alignment: .trailing, spacing: 12) {
                        // Aligné à droite — même règle que IlmLessonView (pas d'override
                        // layoutDirection, la direction RTL vient du contenu).
                        Text(verbatim: isRevealed ? card.lesson.arabic : Self.opening(of: card.lesson.arabic))
                            .font(ScriptureFont.arabic(ScriptureFont.arabicCompact))
                            .lineSpacing(ScriptureFont.arabicLineSpacing)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .fixedSize(horizontal: false, vertical: true)

                        if isRevealed {
                            Divider().overlay(theme.divider)
                            Text(verbatim: card.lesson.text)
                                .font(ScriptureFont.translation(.subheadline))
                                .lineSpacing(ScriptureFont.translationLineSpacing)
                                .foregroundColor(theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                            .stroke(ModuleAccent.ilm.opacity(0.3), lineWidth: 1)
                    )
                    // Révélation : la carte grandit comme un bloc (anti-wiggle n°6).
                    .geometryGroup()

                    if !isRevealed {
                        Text("Récite la suite de mémoire, puis révèle la réponse.")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Actions bas d'écran
            VStack(spacing: 10) {
                if isRevealed {
                    HStack(spacing: 10) {
                        gradeButton("À revoir", icon: "arrow.counterclockwise", color: .orange, outcome: .forgot)
                        gradeButton("Presque", icon: "circle.bottomhalf.filled", color: .yellow, outcome: .almost)
                        gradeButton("Je savais", icon: "checkmark", color: .green, outcome: .known)
                    }
                } else {
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { isRevealed = true }
                    } label: {
                        Label("Révéler la réponse", systemImage: "eye.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(ModuleAccent.ilm.gradient)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private func gradeButton(_ label: String, icon: String, color: Color, outcome: IlmReviewOutcome) -> some View {
        Button {
            grade(outcome)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.22))
            .foregroundColor(theme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: index)
    }

    private func grade(_ outcome: IlmReviewOutcome) {
        guard queue.indices.contains(index) else { return }
        vm.gradeCard(queue[index].lesson.id, outcome: outcome)
        if outcome == .known { knownCount += 1 }

        if index < queue.count - 1 {
            withAnimation(.smooth(duration: 0.25)) {
                index += 1
                isRevealed = false
            }
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                sessionDone = true
            }
        }
    }

    // MARK: - Fin de session

    private var doneState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(ModuleAccent.ilm)
            Text(verbatim: "ما شاء الله")
                .font(ScriptureFont.arabic(26))
                .foregroundColor(theme.textPrimary)
            Text(queue.isEmpty
                 ? "Aucune carte à réviser aujourd'hui"
                 : "Révision terminée — \(knownCount)/\(queue.count) de mémoire")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(theme.textSecondary)
            Text("La régularité, même petite, est la clé de la rétention.")
                .font(.caption)
                .foregroundColor(theme.textTertiary)
            Button { dismiss() } label: {
                Text("Fermer")
                    .bold()
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(ModuleAccent.ilm)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Amorce

    /// Premiers mots du matn (recto de la carte) — assez pour situer, pas assez pour lire.
    private static func opening(of arabic: String, wordCount: Int = 6) -> String {
        let words = arabic.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count > wordCount else { return arabic }
        return words.prefix(wordCount).joined(separator: " ") + " …"
    }
}
