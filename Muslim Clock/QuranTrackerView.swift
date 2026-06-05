//
//  QuranTrackerView.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Sheet plein écran : vue principale du module. Affiche progression, journal et stats.
//

import SwiftUI
import SwiftData

struct QuranTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: QuranPlanViewModel
    @Query(sort: \ReadingEntry.date, order: .reverse) private var entries: [ReadingEntry]

    @State private var showSetup = false
    @State private var pagesToLog: Int = 1
    @State private var showLogSheet = false
    @State private var showLibrary = false

    /// Sourate+ayah cible pour le bouton "Reprendre où j'en étais".
    /// Quand non-nil, présente `QuranChapterDetailView` avec auto-scroll.
    @State private var resumeTarget: ResumeRoute?

    /// Marque-page libre — lecture indépendante du plan Khatma.
    @AppStorage("quranBookmarkSura") private var bookmarkSura: Int = 0
    @AppStorage("quranBookmarkAyah") private var bookmarkAyah: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                // Fond natif cohérent avec la tab Salat (MeshGradient + étoiles).
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()

                if vm.plan == nil {
                    emptyState
                } else if let plan = vm.plan, let progress = vm.progress {
                    activeContent(plan: plan, progress: progress)
                }
            }
            .navigationTitle("Khatma")
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
                QuranPlanSetupView(vm: vm)
            }
            .sheet(isPresented: $showLogSheet) {
                logSheet
                    .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showLibrary) {
                QuranLibraryView()
            }
            .sheet(item: $resumeTarget) { route in
                NavigationStack {
                    QuranChapterDetailView(chapterIndex: route.chapter, scrollToAyah: route.ayah)
                }
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { vm.refresh(entries: entries) }
        .onChange(of: entries) { _, newValue in vm.refresh(entries: newValue) }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.pages")
                .font(.system(size: 60))
                .foregroundStyle(.teal)
            Text("Crée ton plan de lecture")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Choisis un rythme et reçois un rappel doux après chaque prière.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showSetup = true } label: {
                Text("Commencer")
                    .bold()
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.teal)
                    .clipShape(Capsule())
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Active content

    private func activeContent(plan: QuranPlan, progress: QuranPlanProgress) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                progressRing(progress: progress)
                statRow(progress: progress)
                rhythmCard(progress: progress, plan: plan)

                Button { showLogSheet = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("J'ai lu mes pages aujourd'hui")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.teal.gradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Reprendre où j'en étais (utilise lastPageReached + mapper)
                Button { resumeKhatmaReading() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Reprendre où j'en étais")
                                .bold()
                            Text(resumeSubtitle)
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
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(!QuranPageMapper.shared.isAvailable)

                // Reprendre depuis mon marque-page (libre — indépendant du plan)
                if hasBookmark {
                    Button { resumeFromBookmark() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Reprendre depuis mon marque-page")
                                    .bold()
                                Text(bookmarkSubtitle)
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
                                .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                // Parcourir les sourates (online, full Coran via CDN)
                Button { showLibrary = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "list.bullet.indent")
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Parcourir les sourates")
                                .bold()
                            Text("114 sourates · arabe + traduction FR")
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
                            .stroke(Color.teal.opacity(0.2), lineWidth: 1)
                    )
                }

                QuranStatsView(entries: entries, plan: plan)
                    .padding(.top, 6)

                gentleReminder
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: - Sub-views

    private func progressRing(progress: QuranPlanProgress) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(progress.percentComplete))
                .stroke(
                    LinearGradient(colors: [.teal.opacity(0.7), .teal], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(progress.percentComplete * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                if vm.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                        Text("\(vm.streak) j de suite")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                }
            }
        }
        .frame(width: 180, height: 180)
        .padding(.top, 20)
    }

    private func statRow(progress: QuranPlanProgress) -> some View {
        HStack(spacing: 12) {
            statCell(value: "\(progress.pagesReadActual)", label: "Pages lues")
            statCell(value: "\(progress.pagesRemaining)", label: "Pages restantes")
            statCell(value: "\(progress.daysRemaining)j", label: "Restant")
        }
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

    private func rhythmCard(progress: QuranPlanProgress, plan: QuranPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "metronome.fill").foregroundStyle(.teal)
                Text("Ton rythme")
                    .font(.caption.bold())
                    .foregroundColor(.teal)
            }
            Text("**\(progress.pagesPerDay) pages/jour** — soit **\(progress.pagesPerPrayer) pages** après chacune des \(plan.prayersToUse.count) prière(s) sélectionnée(s).")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var gentleReminder: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink.opacity(0.6))
            Text("La qualité prime sur la quantité — la régularité, même petite, est plus aimée que beaucoup d'efforts ponctuels.")
                .font(.caption)
                .italic()
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Resume Khatma

    /// Page Madinah de reprise — `lastPageReached + 1` (page suivante à lire), borné à 604.
    private var resumePage: Int {
        guard let progress = vm.progress else { return vm.plan?.startPage ?? 1 }
        // pagesReadActual = nombre total de pages lues. Prochaine page à lire = startPage + pagesReadActual.
        let next = (vm.plan?.startPage ?? 1) + progress.pagesReadActual
        return min(QuranConstants.totalMadinahPages, max(1, next))
    }

    private var resumeSubtitle: String {
        guard QuranPageMapper.shared.isAvailable else {
            return "Mapping indisponible"
        }
        let p = resumePage
        if let (sura, ayah) = QuranPageMapper.shared.firstAyah(of: p) {
            return "Page \(p) · sourate \(sura), verset \(ayah)"
        }
        return "Page \(p)"
    }

    private func resumeKhatmaReading() {
        let p = resumePage
        guard let (sura, ayah) = QuranPageMapper.shared.firstAyah(of: p) else { return }

        Task {
            guard let chapters = await QuranLibraryLoader.shared.loadIndex(),
                  let target = chapters.first(where: { $0.id == sura }) else { return }
            await MainActor.run {
                resumeTarget = ResumeRoute(chapter: target, ayah: ayah)
            }
        }
    }

    // MARK: - Resume bookmark libre

    private var hasBookmark: Bool {
        bookmarkSura >= 1 && bookmarkAyah >= 1
    }

    private var bookmarkSubtitle: String {
        "Sourate \(bookmarkSura), verset \(bookmarkAyah)"
    }

    private func resumeFromBookmark() {
        guard hasBookmark else { return }
        Task {
            guard let chapters = await QuranLibraryLoader.shared.loadIndex(),
                  let target = chapters.first(where: { $0.id == bookmarkSura }) else { return }
            await MainActor.run {
                resumeTarget = ResumeRoute(chapter: target, ayah: bookmarkAyah)
            }
        }
    }

    // MARK: - Log sheet

    private var logSheet: some View {
        VStack(spacing: 20) {
            Text("Combien de pages aujourd'hui ?")
                .font(.headline)
                .padding(.top, 16)
            HStack(spacing: 20) {
                Button { pagesToLog = max(1, pagesToLog - 1) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.teal)
                }
                Text("\(pagesToLog)")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .frame(minWidth: 80)
                Button { pagesToLog = min(50, pagesToLog + 1) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.teal)
                }
            }
            Button {
                vm.logPages(pagesToLog, context: modelContext)
                pagesToLog = 1
                showLogSheet = false
            } label: {
                Text("Enregistrer")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.teal)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Resume route helper

/// Wrapper Identifiable utilisé par le `sheet(item:)` de QuranTrackerView pour
/// présenter QuranChapterDetailView en reprise Khatma.
private struct ResumeRoute: Identifiable {
    let chapter: QuranChapterIndex
    let ayah: Int
    var id: String { "\(chapter.id):\(ayah)" }
}
