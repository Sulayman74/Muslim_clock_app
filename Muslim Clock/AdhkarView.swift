//
//  AdhkarView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//

import SwiftUI
import Combine

// MARK: - ═══════════════════════════════════════════════════
// MODÈLE ADHKAR
// ═══════════════════════════════════════════════════════════

struct Dhikr: Codable, Identifiable {
    let id: Int
    let text: String
    let arabic: String
    let source: String
    let `repeat`: Int
    let timing: String       // "morning", "evening", "both"
    let benefit: String
}

enum AdhkarTiming: String, CaseIterable {
    case morning = "morning"
    case evening = "evening"
    
    var label: String {
        switch self {
        case .morning: return "أذكار الصباح"
        case .evening: return "أذكار المساء"
        }
    }
    
    var labelFr: String {
        switch self {
        case .morning: return String(localized: "Adhkar du Matin")
        case .evening: return String(localized: "Adhkar du Soir")
        }
    }
    
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "sunset.fill"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .morning: return Color(red: 1.0, green: 0.75, blue: 0.2)   // Doré matin
        case .evening: return Color(red: 0.4, green: 0.5, blue: 0.85)   // Bleu soir
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// SERVICE ADHKAR
// ═══════════════════════════════════════════════════════════

@MainActor
class AdhkarService: ObservableObject {
    @Published var adhkarList: [Dhikr] = []
    @Published var completedCounts: [Int: Int] = [:]

    /// Timing courant, mémorisé pour sauvegarder vers la bonne clé
    private var currentTiming: AdhkarTiming = .morning

    /// Heures réelles fournies par PrayerTimesViewModel
    private var storedFajr: Date? = nil
    private var storedAsr:  Date? = nil

    /// Met à jour les limites de période depuis PrayerTimesViewModel.
    /// À appeler avant loadAdhkar pour que autoTiming et currentPeriodID soient précis.
    func setPrayerBoundaries(fajr: Date?, asr: Date?) {
        storedFajr = fajr
        storedAsr  = asr
    }

    // MARK: - Clés UserDefaults

    private func countsKey(for timing: AdhkarTiming) -> String {
        "adhkar_counts_\(timing.rawValue)"
    }

    private func periodKey(for timing: AdhkarTiming) -> String {
        "adhkar_period_\(timing.rawValue)"
    }

    /// Identifiant unique de la période active :
    /// - Matin  → "morning-YYYY-MM-DD"  (Fajr est toujours avant minuit)
    /// - Soir   → "evening-YYYY-MM-DD"  (peut déborder après minuit jusqu'à ~4h)
    private func currentPeriodID(for timing: AdhkarTiming) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        switch timing {
        case .morning:
            return "morning-\(fmt.string(from: Date()))"
        case .evening:
            // On est encore dans le soir si maintenant < Fajr d'aujourd'hui
            // Fallback : hour < 4 si storedFajr n'est pas encore disponible
            let now = Date()
            let isBeforeFajr: Bool
            if let fajr = storedFajr {
                isBeforeFajr = now < fajr
            } else {
                isBeforeFajr = cal.component(.hour, from: now) < 4
            }
            let ref = isBeforeFajr ? cal.date(byAdding: .day, value: -1, to: now)! : now
            return "evening-\(fmt.string(from: ref))"
        }
    }

    // MARK: - Persistence

    /// Sérialise completedCounts → UserDefaults (String keys car plist l'exige)
    private func saveCounts() {
        let stringKeyed: [String: Int] = Dictionary(uniqueKeysWithValues:
            completedCounts.map { ("\($0.key)", $0.value) }
        )
        UserDefaults.standard.set(stringKeyed, forKey: countsKey(for: currentTiming))
    }

    /// Restaure les compteurs si la période n'a pas changé, sinon remet à zéro.
    /// Appelée après avoir initialisé adhkarList et completedCounts à 0.
    private func applyOrResetCounts(for timing: AdhkarTiming) {
        let savedPeriod  = UserDefaults.standard.string(forKey: periodKey(for: timing)) ?? ""
        let activePeriod = currentPeriodID(for: timing)

        if savedPeriod == activePeriod,
           let saved = UserDefaults.standard.dictionary(forKey: countsKey(for: timing)) as? [String: Int] {
            // Même période → fusion des valeurs sauvegardées dans les adhkar actuels
            for (key, val) in saved {
                if let id = Int(key), completedCounts[id] != nil {
                    completedCounts[id] = val
                }
            }
        } else {
            // Nouvelle période (Fajr ou Asr est passé) → 0 + enregistrement de la période
            UserDefaults.standard.set(activePeriod, forKey: periodKey(for: timing))
            saveCounts()
        }
    }

    // MARK: - API publique

    /// Timing auto-détecté.
    /// Utilise les heures réelles de Fajr/Asr si disponibles, sinon heuristique horaire.
    var autoTiming: AdhkarTiming {
        let now = Date()
        if let fajr = storedFajr, let asr = storedAsr {
            return now >= fajr && now < asr ? .morning : .evening
        }
        // Fallback quand PrayerTimesViewModel n'a pas encore calculé
        let hour = Calendar.current.component(.hour, from: now)
        return (hour >= 4 && hour < 15) ? .morning : .evening
    }

    func loadAdhkar(for timing: AdhkarTiming) {
        currentTiming = timing

        guard let url = Bundle.main.url(forResource: "adhkar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let allAdhkar = try? JSONDecoder().decode([Dhikr].self, from: data) else {
            return
        }

        adhkarList = allAdhkar.filter { $0.timing == "both" || $0.timing == timing.rawValue }

        // Base : tous à 0, puis restauration ou reset selon la période
        completedCounts = Dictionary(uniqueKeysWithValues: adhkarList.map { ($0.id, 0) })
        applyOrResetCounts(for: timing)
    }

    func increment(dhikr: Dhikr) {
        let current = completedCounts[dhikr.id] ?? 0
        if current < dhikr.repeat {
            completedCounts[dhikr.id] = current + 1
            saveCounts()  // Sauvegarde immédiate après chaque tap
        }
    }

    func isCompleted(dhikr: Dhikr) -> Bool {
        (completedCounts[dhikr.id] ?? 0) >= dhikr.repeat
    }

    var totalDhikrs: Int { adhkarList.count }

    var completedDhikrs: Int {
        adhkarList.filter { isCompleted(dhikr: $0) }.count
    }

    var progress: Double {
        guard totalDhikrs > 0 else { return 0 }
        return Double(completedDhikrs) / Double(totalDhikrs)
    }

    var allCompleted: Bool {
        completedDhikrs == totalDhikrs && totalDhikrs > 0
    }
}

// MARK: - ═══════════════════════════════════════════════════
// VUE PRINCIPALE ADHKAR
// ═══════════════════════════════════════════════════════════

struct AdhkarView: View {
    @StateObject private var service = AdhkarService()
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @State private var selectedTiming: AdhkarTiming = .morning
    @State private var showArabic: [Int: Bool] = [:]
    @State private var showBenefit: [Int: Bool] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ── EN-TÊTE ──
            headerView
            
            // ── BARRE DE PROGRESSION ──
            progressBar
            
            // ── LISTE DES ADHKAR ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(service.adhkarList) { dhikr in
                        DhikrCardView(
                            dhikr: dhikr,
                            count: service.completedCounts[dhikr.id] ?? 0,
                            isCompleted: service.isCompleted(dhikr: dhikr),
                            showArabic: showArabic[dhikr.id] ?? true,
                            showBenefit: showBenefit[dhikr.id] ?? false,
                            accentColor: selectedTiming.accentColor,
                            onTap: { service.increment(dhikr: dhikr) },
                            onToggleArabic: { showArabic[dhikr.id] = !(showArabic[dhikr.id] ?? true) },
                            onToggleBenefit: { showBenefit[dhikr.id] = !(showBenefit[dhikr.id] ?? false) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            // 1. Injecter les heures réelles avant de déterminer le timing
            service.setPrayerBoundaries(fajr: prayerVM.fajrDate, asr: prayerVM.asrDate)
            // 2. Détecter matin/soir avec les vraies heures de Fajr/Asr
            selectedTiming = service.autoTiming
            // 3. Charger (restaure ou réinitialise selon la période)
            service.loadAdhkar(for: selectedTiming)
        }
        .onChange(of: selectedTiming) { _, newTiming in
            service.loadAdhkar(for: newTiming)
            showArabic = [:]
            showBenefit = [:]
        }
        // ── OVERLAY FÉLICITATION ──
        .overlay {
            if service.allCompleted {
                completionOverlay
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 12) {
            // Titre arabe
            Text(selectedTiming.label)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .environment(\.layoutDirection, .rightToLeft)
            
            // Toggle Matin / Soir
            HStack(spacing: 0) {
                ForEach(AdhkarTiming.allCases, id: \.self) { timing in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTiming = timing
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: timing.icon)
                                .font(.system(size: 14))
                            Text(timing.labelFr)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(selectedTiming == timing ? .white : .white.opacity(0.5))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            selectedTiming == timing
                            ? timing.accentColor.opacity(0.3)
                            : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text(verbatim: "\(service.completedDhikrs)/\(service.totalDhikrs) \(String(localized: "complétés"))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(verbatim: "\(Int(service.progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(selectedTiming.accentColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [selectedTiming.accentColor.opacity(0.6), selectedTiming.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * service.progress), height: 5)
                        .animation(.easeInOut(duration: 0.3), value: service.progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Completion Overlay
    private var completionOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text(verbatim: "تقبّل الله")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Qu'Allah accepte tes adhkar")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .green.opacity(0.3), radius: 20)
        .transition(.scale.combined(with: .opacity))
        .onTapGesture {
            // Dismiss en tappant
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// CARTE INDIVIDUELLE D'UN DHIKR
// ═══════════════════════════════════════════════════════════

struct DhikrCardView: View {
    let dhikr: Dhikr
    let count: Int
    let isCompleted: Bool
    let showArabic: Bool
    let showBenefit: Bool
    let accentColor: Color
    let onTap: () -> Void
    let onToggleArabic: () -> Void
    let onToggleBenefit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ── TEXTE ARABE ──
            if showArabic {
                Text(verbatim: dhikr.arabic)
                    .font(.system(size: 20, weight: .regular))
                    .multilineTextAlignment(.trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineSpacing(10)
                    .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.9))
            }
            
            // ── TEXTE FRANÇAIS ──
            if !showArabic {
                Text(verbatim: dhikr.text)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.8))
            }
            
            // ── BIENFAIT (EXPANDABLE) ──
            if showBenefit {
                Text(verbatim: dhikr.benefit)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(accentColor.opacity(0.8))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // ── BARRE DU BAS : Source + Boutons + Compteur ──
            HStack(spacing: 10) {
                // Source
                Text(verbatim: dhikr.source)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                // Toggle langue
                Button(action: onToggleArabic) {
                    Text(verbatim: showArabic ? "FR" : "عربي")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                
                // Toggle bienfait
                Button(action: onToggleBenefit) {
                    Image(systemName: showBenefit ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 12))
                        .foregroundColor(showBenefit ? accentColor : .white.opacity(0.5))
                }
                
                // ── COMPTEUR / TAP ZONE ──
                Button(action: onTap) {
                    HStack(spacing: 6) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 18))
                        } else {
                            Text(verbatim: "\(count)/\(dhikr.repeat)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        isCompleted
                        ? Color.green.opacity(0.15)
                        : accentColor.opacity(0.2)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                isCompleted ? Color.green.opacity(0.3) : accentColor.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                .sensoryFeedback(.impact(weight: .light), trigger: count)
            }
        }
        .padding(16)
        .background(
            isCompleted
            ? Color.white.opacity(0.03)
            : Color.white.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isCompleted ? Color.green.opacity(0.15) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
        .animation(.easeInOut(duration: 0.2), value: showArabic)
        .animation(.easeInOut(duration: 0.2), value: showBenefit)
    }
}

// MARK: - ═══════════════════════════════════════════════════
// BOUTON D'ACCÈS RAPIDE (pour la tab Salat)
// Widget compact qui s'affiche après le Fajr ou après le Asr
// ═══════════════════════════════════════════════════════════

struct AdhkarQuickAccessButton: View {
    @State private var showAdhkarSheet = false
    @EnvironmentObject var prayerVM: PrayerTimesViewModel

    /// Détecte matin/soir avec les heures réelles de Fajr/Asr si disponibles
    private var timing: AdhkarTiming {
        let now = Date()
        if let fajr = prayerVM.fajrDate, let asr = prayerVM.asrDate {
            return now >= fajr && now < asr ? .morning : .evening
        }
        let hour = Calendar.current.component(.hour, from: now)
        return (hour >= 4 && hour < 15) ? .morning : .evening
    }
    
    var body: some View {
        Button {
            showAdhkarSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: timing.icon)
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(timing.accentColor, .white.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(timing.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(timing.labelFr)
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
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(timing.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showAdhkarSheet) {
            ZStack {
                LinearGradient(
                    colors: timing == .morning
                    ? [Color(red: 0.15, green: 0.1, blue: 0.05), Color(red: 0.25, green: 0.18, blue: 0.08)]
                    : [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                AdhkarView()
            }
            .environmentObject(prayerVM)  // Transmission des heures de prière à la sheet
            .presentationDragIndicator(.visible)
        }
    }
}
