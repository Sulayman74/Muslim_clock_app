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
        case .morning: return "Adhkar du Matin"
        case .evening: return "Adhkar du Soir"
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
    @Published var completedCounts: [Int: Int] = [:]  // [dhikr.id: nombre de fois complétées]
    
    /// Timing auto-détecté selon l'heure
    var autoTiming: AdhkarTiming {
        let hour = Calendar.current.component(.hour, from: Date())
        // Matin : entre Fajr (~4-5h) et le début d'après-midi
        // Soir : après Asr (~15-16h) jusqu'à la nuit
        return (hour >= 4 && hour < 15) ? .morning : .evening
    }
    
    func loadAdhkar(for timing: AdhkarTiming) {
        guard let url = Bundle.main.url(forResource: "adhkar", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let allAdhkar = try? JSONDecoder().decode([Dhikr].self, from: data) else {
            return
        }
        
        self.adhkarList = allAdhkar.filter { dhikr in
            dhikr.timing == "both" || dhikr.timing == timing.rawValue
        }
        
        // Reset les compteurs
        self.completedCounts = [:]
        for dhikr in adhkarList {
            completedCounts[dhikr.id] = 0
        }
    }
    
    func increment(dhikr: Dhikr) {
        let current = completedCounts[dhikr.id] ?? 0
        if current < dhikr.repeat {
            completedCounts[dhikr.id] = current + 1
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
            selectedTiming = service.autoTiming
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
                Text("\(service.completedDhikrs)/\(service.totalDhikrs) complétés")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(Int(service.progress * 100))%")
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
            
            Text("تقبّل الله")
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
                Text(dhikr.arabic)
                    .font(.system(size: 20, weight: .regular))
                    .multilineTextAlignment(.trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineSpacing(10)
                    .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.9))
            }
            
            // ── TEXTE FRANÇAIS ──
            if !showArabic {
                Text(dhikr.text)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.8))
            }
            
            // ── BIENFAIT (EXPANDABLE) ──
            if showBenefit {
                Text(dhikr.benefit)
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
                Text(dhikr.source)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                // Toggle langue
                Button(action: onToggleArabic) {
                    Text(showArabic ? "FR" : "عربي")
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
                            Text("\(count)/\(dhikr.repeat)")
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
    
    /// Auto-détecte matin ou soir
    private var timing: AdhkarTiming {
        let hour = Calendar.current.component(.hour, from: Date())
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
            .presentationDragIndicator(.visible)
        }
    }
}
