//
//  IlmProgramCard.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Carte d'entrée dans le tab Rappel (pattern QuranKhatmaCard). Résumé compact
//  (% + prochaine leçon) et ouverture de la sheet complète au tap.
//

import SwiftUI

struct IlmProgramCard: View {
    @State private var vm = IlmViewModel()
    @State private var showTracker = false

    var body: some View {
        Button { showTracker = true } label: {
            content
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTracker) {
            IlmTrackerView(vm: vm)
                .presentationDetents([.large])
        }
        .onAppear {
            vm.refresh()
            // Idempotent : maintient le rappel quotidien aligné sur le plan courant.
            vm.rescheduleReminder()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let summary = vm.summary, vm.plan != nil {
            activeState(summary: summary)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple.opacity(0.4), .indigo.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: "books.vertical.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Programme ʿIlm")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("3 Fondements · 4 Règles · 40 Nawawi")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    private func activeState(summary: IlmProgressSummary) -> some View {
        VStack(spacing: 12) {
            // Ligne 1 : titre + streak hebdo
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.purple)
                Text(verbatim: vm.activeTrack?.title ?? String(localized: "Programme ʿIlm"))
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                    .lineLimit(1)
                Spacer()
                if !vm.reviewQueue.isEmpty {
                    Text("\(vm.reviewQueue.count) à réviser")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.purple)
                        .chipStyle(color: .purple)
                }
                if summary.weekStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundStyle(.purple)
                        Text("\(summary.weekStreak)sem")
                            .foregroundColor(.purple)
                    }
                    .font(.caption.bold())
                }
            }

            // Ligne 2 : progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.purple.opacity(0.7), .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(summary.percentComplete))
                }
            }
            .frame(height: 6)

            // Ligne 3 : leçons acquises / total + solde bienveillant
            HStack {
                Text("\(summary.completedLessons) / \(summary.totalLessons) leçons")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(balanceLabel(summary.balance))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(summary.balance >= 0 ? .green.opacity(0.85) : .orange.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }

    // Ton bienveillant : pas de rouge, phrasé positif (même règle que la Khatma).
    private func balanceLabel(_ balance: Int) -> String {
        if balance >= 0 {
            return String(format: String(localized: "+%lld d'avance"), balance)
        }
        return String(format: String(localized: "%lld à rattraper"), -balance)
    }
}
