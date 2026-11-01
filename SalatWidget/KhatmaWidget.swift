//
//  KhatmaWidget.swift
//  SalatWidget
//
//  Widget « Khatma » (Home small + Lock Screen circular) : progression du plan
//  de lecture du Coran. Lit le snapshot publié par `QuranPlanSynchronizer` dans
//  l'App Group (clés `StorageKeys.khatma*`) — clés absentes = pas de plan actif.
//
//  Le rechargement est poussé par l'app à chaque changement de progression ;
//  la timeline ne se rafraîchit d'elle-même qu'à minuit (nouveau jour de plan).
//

import WidgetKit
import SwiftUI

// MARK: - Entrée

struct KhatmaEntry: TimelineEntry {
    let date: Date
    let pagesRead: Int
    let totalPages: Int
    let pagesPerDay: Int
    let streak: Int

    var hasPlan: Bool { totalPages > 0 }
    var percent: Double {
        totalPages > 0 ? min(1, Double(pagesRead) / Double(totalPages)) : 0
    }
}

// MARK: - Provider

struct KhatmaProvider: TimelineProvider {

    private var shared: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    private func buildEntry(at date: Date) -> KhatmaEntry {
        KhatmaEntry(
            date: date,
            pagesRead: shared?.integer(forKey: StorageKeys.khatmaPagesRead) ?? 0,
            totalPages: shared?.integer(forKey: StorageKeys.khatmaTotalPages) ?? 0,
            pagesPerDay: shared?.integer(forKey: StorageKeys.khatmaPagesPerDay) ?? 0,
            streak: shared?.integer(forKey: StorageKeys.khatmaStreak) ?? 0
        )
    }

    func placeholder(in context: Context) -> KhatmaEntry {
        KhatmaEntry(date: .now, pagesRead: 241, totalPages: 604, pagesPerDay: 20, streak: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (KhatmaEntry) -> Void) {
        let entry = buildEntry(at: .now)
        completion(entry.hasPlan || context.isPreview ? entry : placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KhatmaEntry>) -> Void) {
        let now = Date()
        // La progression ne change que via l'app (qui pousse un reload ciblé).
        // Minuit : nouveau jour de plan — on resynchronise par principe.
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 3600)
        completion(Timeline(entries: [buildEntry(at: now)], policy: .after(midnight)))
    }
}

// MARK: - Vues

struct KhatmaWidgetView: View {
    let entry: KhatmaEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
                .containerBackground(.clear, for: .widget)
        default:
            if entry.hasPlan {
                smallView
                    .containerBackground(for: .widget) {
                        WidgetUtils.widgetBackground(at: entry.date)
                    }
            } else {
                emptyView
                    .containerBackground(for: .widget) {
                        WidgetUtils.widgetBackground(at: entry.date)
                    }
            }
        }
    }

    // ── Home small : anneau + pages + streak ──
    private var smallView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Khatma")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Spacer()
                if entry.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text(verbatim: "\(entry.streak)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                }
            }
            .foregroundStyle(.orange)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.015, entry.percent)))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: "\(Int((entry.percent * 100).rounded()))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(maxHeight: .infinity)

            Text(verbatim: "\(entry.pagesRead) / \(entry.totalPages)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // ── Lock Screen circular : jauge de progression ──
    private var circularView: some View {
        Gauge(value: entry.percent) {
            Image(systemName: "book.pages.fill")
        } currentValueLabel: {
            if entry.hasPlan {
                Text(verbatim: "\(Int((entry.percent * 100).rounded()))%")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
            } else {
                Image(systemName: "book.pages")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(.orange)
        .widgetAccentable()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.pages")
                .font(.title3)
                .foregroundStyle(.orange.opacity(0.7))
            Text("Créer un plan de lecture dans l'app")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Déclaration

struct KhatmaWidget: Widget {
    // `kind` partagé via StorageKeys pour que l'app cible son rechargement.
    static let kind = StorageKeys.khatmaWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: KhatmaProvider()) { entry in
            KhatmaWidgetView(entry: entry)
        }
        .configurationDisplayName("Khatma")
        .description("Ta progression de lecture du Coran.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    KhatmaWidget()
} timeline: {
    KhatmaEntry(date: .now, pagesRead: 241, totalPages: 604, pagesPerDay: 20, streak: 6)
    KhatmaEntry(date: .now, pagesRead: 0, totalPages: 0, pagesPerDay: 0, streak: 0)
}

#Preview("Circular", as: .accessoryCircular) {
    KhatmaWidget()
} timeline: {
    KhatmaEntry(date: .now, pagesRead: 241, totalPages: 604, pagesPerDay: 20, streak: 6)
}
