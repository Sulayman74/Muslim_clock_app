//
//  RecitationEntryCard.swift
//  Muslim Clock — onglet Apprendre, correcteur de récitation
//
//  Carte du hub (riwaya courante, versets à retravailler) et écran de
//  préparation d'une séance (riwaya, sourate, plage, mémorisation).
//

import SwiftUI

/// Préférences du correcteur (UserDefaults, inventaire des clés dans le plan §5).
enum RecitationPreferences {
    static let riwayaKey = "recitation_riwaya"
    static let hideTextKey = "recitation_hide_text"
}

struct RecitationEntryCard: View {
    @AppStorage(RecitationPreferences.riwayaKey) private var riwaya: Riwaya = .hafs
    @State private var reworkCount = 0
    @State private var showSetup = false

    var body: some View {
        Button { showSetup = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ModuleAccent.quran.opacity(0.22))
                        .frame(width: 44, height: 44)
                    Image(systemName: "waveform.and.mic")
                        .font(.title3)
                        .foregroundStyle(ModuleAccent.quran)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Corriger ma récitation")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(verbatim: riwaya.label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if reworkCount > 0 {
                    Text("\(reworkCount) à retravailler")
                        .font(.system(size: 9, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                        .chipStyle(color: .orange)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassCardSecondary(cornerRadius: CornerRadius.card, tint: ModuleAccent.quran)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSetup, onDismiss: refresh) {
            RecitationSetupView()
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        reworkCount = RecitationProgressStore.load().versesToRework().count
    }
}

// MARK: - Préparation de la séance

struct RecitationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RecitationPreferences.riwayaKey) private var riwaya: Riwaya = .hafs
    @AppStorage(RecitationPreferences.hideTextKey) private var hideText = false

    @State private var surahs: [(id: Int, nameArabic: String, nameLatin: String)] = []
    @State private var surah = 1
    @State private var fromAyah = 1
    @State private var toAyah = 7
    @State private var ayahCount = 7
    @State private var rework: [String] = []
    @State private var session: RecitationSessionRoute?
    @State private var errorMessage: String?
    @State private var engineAvailable = true

    private let availableRiwayat = RecitationReferenceLoader.availableRiwayat()

    var body: some View {
        NavigationStack {
            Form {
                if !engineAvailable {
                    Section {
                        Label("La reconnaissance vocale arabe n'est pas disponible sur cet appareil. Le correcteur fonctionne uniquement sur l'appareil, sans serveur.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.footnote)
                    }
                }

                Section {
                    Picker("Riwaya", selection: $riwaya) {
                        ForEach(availableRiwayat) { r in
                            Text(verbatim: r.label).tag(r)
                        }
                    }
                } footer: {
                    Text("Le texte et la numérotation des versets suivent la riwaya choisie.")
                }

                Section("Passage") {
                    Picker("Sourate", selection: $surah) {
                        ForEach(surahs, id: \.id) { s in
                            Text(verbatim: "\(s.id). \(s.nameLatin)  \(s.nameArabic)").tag(s.id)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Stepper(value: $fromAyah, in: 1...max(1, ayahCount)) {
                        LabeledContent("Du verset") { Text("\(fromAyah)").monospacedDigit() }
                    }
                    Stepper(value: $toAyah, in: fromAyah...min(ayahCount, fromAyah + RecitationReferenceLoader.maxAyahsPerSession - 1)) {
                        LabeledContent("Au verset") { Text("\(toAyah)").monospacedDigit() }
                    }
                    Toggle("Masquer le texte (de mémoire)", isOn: $hideText)
                }

                if !rework.isEmpty {
                    Section("À retravailler") {
                        ForEach(rework.prefix(10), id: \.self) { key in
                            if let parsed = Self.parse(key) {
                                Button {
                                    select(riwaya: parsed.riwaya, surah: parsed.surah, ayah: parsed.ayah)
                                } label: {
                                    LabeledContent {
                                        Image(systemName: "arrow.uturn.backward")
                                    } label: {
                                        Text(verbatim: "\(surahName(parsed.surah)) · \(parsed.ayah)")
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(action: start) {
                        Label("Commencer", systemImage: "mic.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!engineAvailable || surahs.isEmpty)
                } footer: {
                    Text("Un mot non signalé n'est pas forcément juste. Fais valider ta récitation par un enseignant.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(CosmicBackground(season: IslamicSeasonInfo.current()).ignoresSafeArea())
            .navigationTitle("Récitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .navigationDestination(item: $session) { route in
                RecitationSessionView(reference: route.reference, hideText: hideText)
            }
            .alert("Passage indisponible", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .tint(ModuleAccent.quran)
        .task {
            engineAvailable = await RecitationTranscriber.availableEngine() != nil
            await reload(keepSelection: false)
        }
        .onChange(of: riwaya) { _, _ in Task { await reload(keepSelection: false) } }
        .onChange(of: surah) { _, _ in Task { await reloadAyahCount() } }
        .onChange(of: fromAyah) { _, newValue in
            toAyah = min(max(toAyah, newValue), newValue + RecitationReferenceLoader.maxAyahsPerSession - 1, ayahCount)
        }
    }

    // MARK: - Actions

    private func start() {
        Task {
            do {
                let reference = try await RecitationReferenceLoader.load(riwaya: riwaya, surah: surah, ayahRange: fromAyah...toAyah)
                session = RecitationSessionRoute(reference: reference)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func select(riwaya selected: Riwaya, surah selectedSurah: Int, ayah: Int) {
        if selected != riwaya { riwaya = selected }
        surah = selectedSurah
        Task {
            await reloadAyahCount()
            fromAyah = ayah
            toAyah = ayah
        }
    }

    private func reload(keepSelection: Bool) async {
        surahs = await RecitationReferenceLoader.surahNames(riwaya: riwaya)
        rework = RecitationProgressStore.load().versesToRework()
        if !surahs.contains(where: { $0.id == surah }) { surah = 1 }
        await reloadAyahCount()
    }

    private func reloadAyahCount() async {
        ayahCount = await RecitationReferenceLoader.ayahCount(surah: surah, riwaya: riwaya) ?? 1
        fromAyah = min(fromAyah, ayahCount)
        toAyah = min(max(toAyah, fromAyah), fromAyah + RecitationReferenceLoader.maxAyahsPerSession - 1, ayahCount)
    }

    private func surahName(_ id: Int) -> String {
        surahs.first { $0.id == id }?.nameLatin ?? "\(id)"
    }

    static func parse(_ key: String) -> (riwaya: Riwaya, surah: Int, ayah: Int)? {
        let parts = key.split(separator: ":")
        guard parts.count == 3, let r = Riwaya(rawValue: String(parts[0])),
              let s = Int(parts[1]), let a = Int(parts[2]) else { return nil }
        return (r, s, a)
    }
}

struct RecitationSessionRoute: Identifiable, Hashable {
    let reference: RecitationReference
    var id: String { "\(reference.riwaya.rawValue):\(reference.surah):\(reference.ayahRange)" }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
