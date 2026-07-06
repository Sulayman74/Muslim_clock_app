//
//  IlmPlanSetupView.swift
//  Muslim Clock — module Programme ʿIlm
//
//  Sheet de création / modification du programme (pattern QuranPlanSetupView) :
//  choix du parcours, preset de rythme, rappel quotidien.
//

import SwiftUI

struct IlmPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: IlmViewModel

    @State private var trackID: String = ""
    @State private var lessonsPerWeek: Int = 7
    @State private var reminderEnabled: Bool = true
    @State private var reminderTime: Date = Calendar.current.date(
        bySettingHour: 20, minute: 0, second: 0, of: .now
    ) ?? .now

    /// Preset sélectionné (feedback UX) — remis à nil si réglage manuel divergent.
    @State private var selectedPreset: IlmPlanPreset?

    /// Overlay de célébration après validation, juste avant le dismiss.
    @State private var planSaved: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Texte à étudier") {
                    ForEach(vm.tracks) { track in
                        Button { select(track) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: trackID == track.id ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(trackID == track.id ? .purple : .white.opacity(0.3))
                                    .symbolEffect(.bounce, value: trackID == track.id)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: track.title)
                                        .foregroundColor(.white)
                                        .font(.system(size: 14, weight: trackID == track.id ? .bold : .medium))
                                    Text(verbatim: "\(track.titleArabic) · \(track.lessons.count) leçons")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(
                            trackID == track.id
                                ? Color.purple.opacity(0.18)
                                : Color.white.opacity(0.08)
                        )
                    }
                }

                Section {
                    ForEach(IlmPlanPreset.allCases) { preset in
                        Button { apply(preset) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedPreset == preset ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(selectedPreset == preset ? .purple : .white.opacity(0.3))
                                Text(preset.label)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: selectedPreset == preset ? .bold : .medium))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(
                            selectedPreset == preset
                                ? Color.purple.opacity(0.18)
                                : Color.white.opacity(0.08)
                        )
                    }
                    Stepper(value: $lessonsPerWeek, in: 1...14) {
                        Text("\(lessonsPerWeek) leçon(s) / semaine")
                            .contentTransition(.numericText())
                    }
                    .onChange(of: lessonsPerWeek) { _, newValue in
                        if selectedPreset?.lessonsPerWeek != newValue {
                            selectedPreset = nil
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                } header: {
                    Text("Rythme")
                } footer: {
                    Text(estimateFooter)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Section("Rappel quotidien") {
                    Toggle("Activer le rappel", isOn: $reminderEnabled)
                    DatePicker("Heure", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .disabled(!reminderEnabled)
                }
                .listRowBackground(Color.white.opacity(0.08))

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Text(vm.plan == nil ? "Commencer" : "Mettre à jour").bold()
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.purple.opacity(0.4))
                    .disabled(trackID.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                CosmicBackground(season: IslamicSeasonInfo.current())
                    .ignoresSafeArea()
            )
            .navigationTitle("ʿIlm — Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear(perform: prefillFromCurrent)
            .overlay {
                if planSaved {
                    celebrationOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: planSaved)
    }

    // MARK: - Footer estimation

    private var estimateFooter: String {
        guard let track = vm.tracks.first(where: { $0.id == trackID }) else {
            return String(localized: "Choisis un texte pour voir la durée estimée.")
        }
        let remaining = track.lessons.count - vm.completedCount(in: track)
        guard remaining > 0 else { return String(localized: "Parcours déjà terminé — révision libre.") }
        let weeks = Int(ceil(Double(remaining) / Double(max(1, lessonsPerWeek))))
        return String(
            format: String(localized: "≈ %lld semaine(s) pour les %lld leçons restantes."),
            weeks, remaining
        )
    }

    // MARK: - Actions

    private func select(_ track: IlmTrack) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.smooth(duration: 0.3)) { trackID = track.id }
    }

    private func apply(_ preset: IlmPlanPreset) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.smooth(duration: 0.3)) {
            lessonsPerWeek = preset.lessonsPerWeek
            selectedPreset = preset
        }
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        // Conserve la date de début si on modifie le même parcours (le solde reste juste).
        let startDate: Date = (vm.plan?.trackID == trackID) ? (vm.plan?.startDate ?? .now) : .now
        let plan = IlmPlan(
            trackID: trackID,
            startDate: startDate,
            lessonsPerWeek: lessonsPerWeek,
            reminderEnabled: reminderEnabled,
            reminderHour: comps.hour ?? 20,
            reminderMinute: comps.minute ?? 0
        )
        vm.savePlan(plan)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            planSaved = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            dismiss()
        }
    }

    private func prefillFromCurrent() {
        if let p = vm.plan {
            trackID = p.trackID
            lessonsPerWeek = p.lessonsPerWeek
            reminderEnabled = p.reminderEnabled
            reminderTime = Calendar.current.date(
                bySettingHour: p.reminderHour, minute: p.reminderMinute, second: 0, of: .now
            ) ?? .now
            selectedPreset = IlmPlanPreset.allCases.first { $0.lessonsPerWeek == p.lessonsPerWeek }
        } else {
            trackID = vm.tracks.first?.id ?? ""
            selectedPreset = .oneLessonPerDay
        }
    }

    // MARK: - Celebration overlay

    private var celebrationOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
                .symbolEffect(.bounce, value: planSaved)

            Text(verbatim: "بسم الله")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Programme créé")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            Text("Qu'Allah te facilite l'apprentissage")
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .purple.opacity(0.3), radius: 24)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
