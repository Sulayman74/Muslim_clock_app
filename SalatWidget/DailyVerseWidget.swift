//
//  DailyVerseWidget.swift
//  SalatWidget
//
//  Widget « Verset du jour » (Home small + medium). Lit le verset publié par
//  `DailyContentService` dans l'App Group (clés `StorageKeys.dailyAyah*`) — aucune
//  requête réseau : le widget affiche le dernier contenu synchronisé par l'app.
//
//  Arabe en principal (police système : AmiriQuran n'est pas dans ce target),
//  traduction FR et source en secondaire. Fond cohérent avec les autres widgets
//  via `WidgetUtils.widgetBackground` (variante Ramadan incluse).
//

import WidgetKit
import SwiftUI

// MARK: - Entrée

struct DailyVerseEntry: TimelineEntry {
    let date: Date
    let arabic: String
    let french: String
    let source: String

    var hasContent: Bool { !arabic.isEmpty || !french.isEmpty }
}

// MARK: - Provider

struct DailyVerseProvider: TimelineProvider {

    /// Sans contenu publié (app jamais ouverte) : on retente régulièrement.
    private static let noContentRetry: TimeInterval = 2 * 3600

    private var shared: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    private func buildEntry(at date: Date) -> DailyVerseEntry {
        DailyVerseEntry(
            date: date,
            arabic: shared?.string(forKey: StorageKeys.dailyAyahAr) ?? "",
            french: shared?.string(forKey: StorageKeys.dailyAyahFr) ?? "",
            source: shared?.string(forKey: StorageKeys.dailyAyahSource) ?? ""
        )
    }

    func placeholder(in context: Context) -> DailyVerseEntry {
        DailyVerseEntry(
            date: .now,
            arabic: "وَقُل رَّبِّ زِدْنِي عِلْمًا",
            french: "Et dis : Seigneur, accrois mes connaissances.",
            source: "Coran 20:114"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyVerseEntry) -> Void) {
        let entry = buildEntry(at: .now)
        completion(entry.hasContent || context.isPreview ? entry : placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyVerseEntry>) -> Void) {
        let now = Date()
        let entry = buildEntry(at: now)

        // Le contenu tourne une fois par jour : recharger à minuit. Sans contenu
        // encore publié, on retente plus tôt (l'app finira par synchroniser).
        let calendar = Calendar.current
        let nextRefresh: Date = entry.hasContent
            ? (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(Self.noContentRetry))
            : now.addingTimeInterval(Self.noContentRetry)

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Vues

struct DailyVerseView: View {
    let entry: DailyVerseEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.hasContent {
                switch family {
                case .systemSmall: smallView
                default:           mediumView
                }
            } else {
                emptyView
            }
        }
        .containerBackground(for: .widget) {
            WidgetUtils.widgetBackground(at: entry.date)
        }
    }

    // ── Small : arabe + source, compact ──
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(verbatim: entry.arabic)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            sourceLabel
        }
    }

    // ── Medium : arabe + traduction FR + source ──
    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text(verbatim: entry.arabic)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            if !entry.french.isEmpty {
                Text(verbatim: entry.french)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            sourceLabel
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Verset du jour")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.orange)
    }

    private var sourceLabel: some View {
        Group {
            if !entry.source.isEmpty {
                Text(verbatim: entry.source)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.85))
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(.orange.opacity(0.7))
            Text("Ouvrez l'app")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Déclaration

struct DailyVerseWidget: Widget {
    // `kind` partagé via StorageKeys pour que l'app cible son rechargement.
    static let kind = StorageKeys.dailyVerseWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DailyVerseProvider()) { entry in
            DailyVerseView(entry: entry)
        }
        .configurationDisplayName("Verset du jour")
        .description("Le verset du jour, synchronisé depuis l'app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview("Medium", as: .systemMedium) {
    DailyVerseWidget()
} timeline: {
    DailyVerseEntry(date: .now,
                    arabic: "وَقُل رَّبِّ زِدْنِي عِلْمًا",
                    french: "Et dis : Seigneur, accrois mes connaissances.",
                    source: "Coran 20:114")
}

#Preview("Small", as: .systemSmall) {
    DailyVerseWidget()
} timeline: {
    DailyVerseEntry(date: .now,
                    arabic: "إِنَّ مَعَ الْعُسْرِ يُسْرًا",
                    french: "Certes, avec la difficulté vient la facilité.",
                    source: "Coran 94:6")
}
