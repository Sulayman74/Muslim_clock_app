//
//  SalatWidgetLiveActivity.swift
//  SalatWidget
//
//  Live Activity "Prochaine Salât" — compte à rebours live (Dynamic Island + Lock Screen)
//  démarré ~30 min avant chaque prière par SalatLiveActivityManager (app iOS).
//
//  `SalatLiveActivityAttributes` est défini dans le main app target — ce fichier doit
//  être ajouté au target SalatWidgetExtension via Target Membership (cf. fichier .swift dédié).
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget

struct SalatWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SalatLiveActivityAttributes.self) { context in
            // ── Lock Screen / Banner ──
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.attributes.iconName)
                            .font(.title3)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.frenchName)
                                .font(.headline)
                            Text(context.attributes.arabicName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.targetTime, style: .time)
                            .font(.headline)
                            .monospacedDigit()
                        Text("heure")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                        Text(context.state.targetTime, style: .timer)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.iconName)
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.targetTime, style: .timer)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(maxWidth: 60)
            } minimal: {
                Image(systemName: context.attributes.iconName)
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<SalatLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // Icône prière
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.orange.opacity(0.4), .orange.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                Image(systemName: context.attributes.iconName)
                    .font(.title2)
                    .foregroundStyle(.orange)
            }

            // Nom + heure cible
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.arabicName)
                    .font(.system(size: 18, weight: .bold))
                    .environment(\.layoutDirection, .rightToLeft)
                Text(context.attributes.frenchName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(context.state.targetTime, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Countdown live
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.targetTime, style: .timer)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(minWidth: 70, alignment: .trailing)
                Text("restant")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

extension SalatLiveActivityAttributes {
    fileprivate static var preview: SalatLiveActivityAttributes {
        SalatLiveActivityAttributes(
            prayerKey: "maghrib",
            frenchName: "Maghrib",
            arabicName: "المغرب",
            iconName: "sunset.fill"
        )
    }
}

extension SalatLiveActivityAttributes.ContentState {
    fileprivate static var inThirty: SalatLiveActivityAttributes.ContentState {
        SalatLiveActivityAttributes.ContentState(targetTime: Date().addingTimeInterval(30 * 60))
    }
    fileprivate static var inFive: SalatLiveActivityAttributes.ContentState {
        SalatLiveActivityAttributes.ContentState(targetTime: Date().addingTimeInterval(5 * 60))
    }
}

#Preview("Lock Screen", as: .content, using: SalatLiveActivityAttributes.preview) {
    SalatWidgetLiveActivity()
} contentStates: {
    SalatLiveActivityAttributes.ContentState.inThirty
    SalatLiveActivityAttributes.ContentState.inFive
}
