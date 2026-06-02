//
//  QuranStatsView.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Stats lecture via Swift Charts natif. Heatmap régularité + courbe progression.
//

import SwiftUI
import Charts

struct QuranStatsView: View {
    let entries: [ReadingEntry]
    let plan: QuranPlan

    /// Période affichée pour la heatmap (35 derniers jours, 5 semaines).
    private let heatmapDays = 35

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heatmapSection
            progressionSection
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill").foregroundStyle(.indigo)
                Text("Régularité — 5 dernières semaines")
                    .font(.caption.bold())
                    .foregroundColor(.indigo)
            }

            Chart(heatmapData(), id: \.day) { item in
                RectangleMark(
                    xStart: .value("Jour", item.column),
                    xEnd: .value("Jour", item.column + 1),
                    yStart: .value("Semaine", item.row),
                    yEnd: .value("Semaine", item.row + 1)
                )
                .foregroundStyle(by: .value("Pages", item.pages))
                .cornerRadius(3)
            }
            .chartForegroundStyleScale(range: Gradient(colors: [.white.opacity(0.06), .teal]))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 110)
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Progression curve

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.teal)
                Text("Progression")
                    .font(.caption.bold())
                    .foregroundColor(.teal)
            }

            Chart {
                ForEach(progressionData(), id: \.day) { item in
                    AreaMark(
                        x: .value("Jour", item.day),
                        y: .value("Pages cumulées", item.cumulative)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [.teal.opacity(0.4), .teal.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    LineMark(
                        x: .value("Jour", item.day),
                        y: .value("Pages cumulées", item.cumulative)
                    )
                    .foregroundStyle(.teal)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.5))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(height: 140)
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Data helpers

    /// Une cellule de heatmap (jour × semaine).
    private struct HeatmapItem {
        let day: Date
        let column: Int   // 0...6 (lundi → dimanche)
        let row: Int      // 0...weeks
        let pages: Int
    }

    private func heatmapData() -> [HeatmapItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -(heatmapDays - 1), to: today) ?? today

        // Agrège les entries par jour
        let dict = Dictionary(grouping: entries.filter { $0.date >= start && $0.date <= today }) {
            cal.startOfDay(for: $0.date)
        }
        .mapValues { $0.reduce(0) { $0 + $1.pagesRead } }

        var items: [HeatmapItem] = []
        for offset in 0..<heatmapDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = (cal.component(.weekday, from: day) + 5) % 7 // lundi=0
            let row = heatmapDays / 7 - 1 - (offset / 7) // semaine la plus récente en haut
            items.append(HeatmapItem(
                day: day,
                column: weekday,
                row: row,
                pages: dict[day] ?? 0
            ))
        }
        return items
    }

    /// Cumul des pages lues par jour depuis le début du plan.
    private struct ProgressionItem {
        let day: Date
        let cumulative: Int
    }

    private func progressionData() -> [ProgressionItem] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: plan.startDate)
        let today = cal.startOfDay(for: .now)
        let totalDays = QuranPlanMath.daysBetween(start, today)

        let dict = Dictionary(grouping: entries.filter { $0.date >= start && $0.date <= today }) {
            cal.startOfDay(for: $0.date)
        }
        .mapValues { $0.reduce(0) { $0 + $1.pagesRead } }

        var items: [ProgressionItem] = []
        var cumulative = 0
        for offset in 0..<totalDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            cumulative += dict[day] ?? 0
            items.append(ProgressionItem(day: day, cumulative: cumulative))
        }
        return items
    }
}
