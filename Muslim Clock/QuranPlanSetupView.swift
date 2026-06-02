//
//  QuranPlanSetupView.swift
//  Muslim Clock — module Programme de lecture du Quran
//
//  Sheet de création / modification d'un plan. Propose des presets ou un mode "expert".
//

import SwiftUI

struct QuranPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: QuranPlanViewModel

    @State private var goalType: PlanGoalType = .byDuration
    @State private var durationDays: Int = 30
    @State private var targetPages: Int = 604
    @State private var targetDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var startPage: Int = 1
    @State private var endPage: Int = 604
    @State private var prayersToUse: Set<String> = QuranPlan.allPrayers
    @State private var notificationsEnabled: Bool = true

    /// Preset actuellement sélectionné (feedback UX). Remis à `nil` dès qu'un réglage
    /// est modifié manuellement par l'utilisateur.
    @State private var selectedPreset: QuranPlanPreset?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(QuranPlanPreset.allCases) { preset in
                        Button { apply(preset) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedPreset == preset ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(selectedPreset == preset ? .teal : .white.opacity(0.3))
                                    .symbolEffect(.bounce, value: selectedPreset == preset)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.label)
                                        .foregroundColor(.white)
                                        .font(.system(size: 14, weight: selectedPreset == preset ? .bold : .medium))
                                    Text("≈ \(presetPagesPerDay(preset)) pages/jour")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .listRowBackground(
                            selectedPreset == preset
                                ? Color.teal.opacity(0.18)
                                : Color.white.opacity(0.08)
                        )
                    }
                } header: {
                    Text("Preset rapide")
                } footer: {
                    if let preset = selectedPreset {
                        Text("« \(preset.label) » appliqué — ajuste si besoin ci-dessous.")
                            .foregroundStyle(.teal.opacity(0.85))
                    } else {
                        Text("Choisis un rythme pour pré-remplir le formulaire.")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Section("Objectif") {
                    Picker("Type", selection: $goalType) {
                        ForEach(PlanGoalType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .onChange(of: goalType) { _, _ in selectedPreset = nil }

                    switch goalType {
                    case .byDuration:
                        Stepper(value: $durationDays, in: 7...365) {
                            Text("\(durationDays) jours")
                                .contentTransition(.numericText())
                        }
                        .onChange(of: durationDays) { _, newValue in
                            // Si l'utilisateur ajuste manuellement → invalide le preset sélectionné
                            // (sauf si la valeur correspond toujours pile-poil à un preset).
                            if selectedPreset?.defaultDurationDays != newValue {
                                selectedPreset = nil
                            }
                        }
                    case .byPages:
                        Stepper(value: $targetPages, in: 10...604, step: 10) {
                            Text("\(targetPages) pages")
                                .contentTransition(.numericText())
                        }
                        .onChange(of: targetPages) { _, _ in selectedPreset = nil }
                    case .byDate:
                        DatePicker("Date cible", selection: $targetDate, in: Date()..., displayedComponents: .date)
                            .onChange(of: targetDate) { _, _ in selectedPreset = nil }
                    }
                }
                .listRowBackground(Color.white.opacity(0.08))

                Section("Portée du Mushaf") {
                    Stepper(value: $startPage, in: 1...604) {
                        Text("De la page \(startPage)")
                    }
                    Stepper(value: $endPage, in: startPage...604) {
                        Text("Jusqu'à la page \(endPage)")
                    }
                }
                .listRowBackground(Color.white.opacity(0.08))

                Section("Rappels post-prière") {
                    Toggle("Activer les rappels", isOn: $notificationsEnabled)
                    ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { prayer in
                        Toggle(prayer, isOn: Binding(
                            get: { prayersToUse.contains(prayer) },
                            set: { isOn in
                                if isOn { prayersToUse.insert(prayer) }
                                else    { prayersToUse.remove(prayer) }
                            }
                        ))
                        .disabled(!notificationsEnabled)
                    }
                }
                .listRowBackground(Color.white.opacity(0.08))

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Text("Créer le plan").bold()
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.teal.opacity(0.4))
                    .disabled(!isValid)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Khatma — Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onAppear(perform: prefillFromCurrent)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Validation

    private var isValid: Bool {
        endPage >= startPage && !prayersToUse.isEmpty && (
            (goalType == .byDuration && durationDays > 0) ||
            (goalType == .byPages    && targetPages > 0) ||
            (goalType == .byDate     && targetDate > .now)
        )
    }

    // MARK: - Actions

    private func apply(_ preset: QuranPlanPreset) {
        // Haptic feedback léger pour confirmer le tap
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Animation smooth sur les changements de State pour que le Stepper/Picker
        // se mette à jour visiblement (anti-wiggle silencieux).
        withAnimation(.smooth(duration: 0.3)) {
            goalType = .byDuration
            durationDays = preset.defaultDurationDays
            // Un preset cible toujours le Mushaf complet — l'utilisateur peut ajuster ensuite.
            startPage = 1
            endPage = 604
            selectedPreset = preset
        }
    }

    /// Pages/jour dérivées d'un preset (affichage en footer du preset).
    private func presetPagesPerDay(_ preset: QuranPlanPreset) -> Int {
        Int(ceil(604.0 / Double(preset.defaultDurationDays)))
    }

    private func save() {
        let value: Double
        switch goalType {
        case .byDuration: value = Double(durationDays)
        case .byPages:    value = Double(targetPages)
        case .byDate:     value = targetDate.timeIntervalSince1970
        }
        let plan = QuranPlan(
            goalType: goalType,
            goalValue: value,
            startDate: .now,
            startPage: startPage,
            endPage: endPage,
            prayersToUse: prayersToUse,
            notificationsEnabled: notificationsEnabled
        )
        vm.savePlan(plan)
        dismiss()
    }

    private func prefillFromCurrent() {
        guard let p = vm.plan else { return }
        goalType = p.goalType
        switch p.goalType {
        case .byDuration: durationDays = Int(p.goalValue)
        case .byPages:    targetPages = Int(p.goalValue)
        case .byDate:     targetDate = Date(timeIntervalSince1970: p.goalValue)
        }
        startPage = p.startPage
        endPage = p.endPage
        prayersToUse = p.prayersToUse
        notificationsEnabled = p.notificationsEnabled
    }
}
