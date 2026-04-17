//
//  PostPrayerAdhkarService.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 04/04/2026.
//

import Foundation
import SwiftUI
import Combine

struct PostPrayerDhikr: Codable, Identifiable {
    let id: Int
    let text: String
    let arabic: String
    let source: String
    let repeatCount: Int
    let prayer: String
    let benefit: String
    
    enum CodingKeys: String, CodingKey {
        case id, text, arabic, source, prayer, benefit
        case repeatCount = "repeat"
    }
}

@MainActor
class PostPrayerAdhkarService: ObservableObject {
    @Published var adhkarList: [PostPrayerDhikr] = []
    @Published var isCompleted: Bool = false
    
    func loadAdhkar(for prayerName: String) {
        let currentPrayerKey = prayerName.lowercased()
        
        guard let url = Bundle.main.url(forResource: "post_prayer_adhkar", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Erreur : Impossible de charger post_prayer_adhkar.json")
            return
        }
        
        do {
            let allAdhkar = try JSONDecoder().decode([PostPrayerDhikr].self, from: data)
            self.adhkarList = allAdhkar.filter { dhikr in
                dhikr.prayer == "all" ||
                dhikr.prayer == currentPrayerKey ||
                (dhikr.prayer == "fajr_maghrib" && (currentPrayerKey == "fajr" || currentPrayerKey == "maghrib"))
            }
        } catch {
            print("Erreur de décodage JSON : \(error)")
        }
    }
}

// MARK: - CurrentPrayerGaugeView
struct CurrentPrayerGaugeView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @State private var showAdhkarSheet = false
    
    // ✨ RAPPELS SPIRITUELS POUR LE TEMPS D'ATTENTE
    private struct SpiritualReminder: Identifiable {
        let id = UUID()
        let arabic: String
        let french: String
        let source: String
        let color: Color
        let icon: String
    }
    
    private var currentReminder: SpiritualReminder {
        let reminders = [
            SpiritualReminder(
                arabic: "إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا",
                french: "La Salât demeure, pour les croyants, une prescription, à des temps déterminés.",
                source: "Sourate An-Nisa (4:103)",
                color: .teal,
                icon: "book.closed.fill"
            ),
            SpiritualReminder(
                arabic: "حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلَاةِ الْوُسْطَىٰ",
                french: "Soyez assidus aux Salâts, et surtout la Salât médiane.",
                source: "Sourate Al-Baqara (2:238)",
                color: .indigo,
                icon: "moon.stars.fill"
            ),
            SpiritualReminder(
                arabic: "قَدْ أَفْلَحَ الْمُؤْمِنُونَ ۝ الَّذِينَ هُمْ فِي صَلَاتِهِمْ خَاشِعُونَ",
                french: "Bienheureux sont certes les croyants, ceux qui sont humbles dans leur Salât.",
                source: "Sourate Al-Mu'minun (23:1-2)",
                color: .purple,
                icon: "hands.sparkles.fill"
            ),
            SpiritualReminder(
                arabic: "وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ",
                french: "Cherchez secours dans l'endurance et la Salât.",
                source: "Sourate Al-Baqara (2:45)",
                color: .green,
                icon: "heart.fill"
            )
        ]
        
        // Rotation basée sur l'heure actuelle pour éviter de toujours voir le même
        let hour = Calendar.current.component(.hour, from: Date())
        let index = hour % reminders.count
        return reminders[index]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if prayerVM.currentPrayerWindow != .none,
               let start = prayerVM.currentWindowStart,
               let end = prayerVM.currentWindowEnd {
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // 1. CARTE : PRIÈRE EN COURS
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                VStack(spacing: 20) {
                    // En-tête aéré
                    HStack {
                        Image(systemName: prayerVM.currentPrayerWindow.icon)
                            .font(.title2)
                        Text("Temps du \(prayerVM.currentPrayerWindow.rawValue)")
                            .font(.headline)
                        Spacer()
                        Text(prayerVM.currentPrayerWindow.arabicName)
                            .font(.title2.bold())
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    .foregroundColor(.orange)
                    
                    // Jauge et Timer
                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                        let now = context.date
                        let totalDuration = end.timeIntervalSince(start)
                        let elapsed = now.timeIntervalSince(start)
                        let progress = max(0.0, min(1.0, elapsed / totalDuration))
                        let timeRemaining = max(0, end.timeIntervalSince(now))
                        
                        let gaugeColor = progress > 0.85 ? Color.red : Color.orange
                        
                        VStack(spacing: 12) {
                            // La barre plus épaisse
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                    
                                    Capsule()
                                        .fill(LinearGradient(colors: [gaugeColor.opacity(0.6), gaugeColor], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * CGFloat(progress))
                                        .animation(.linear(duration: 1.0), value: progress)
                                }
                            }
                            .frame(height: 10)
                            
                            // Textes sous la barre
                            HStack {
                                Text("\(start.formatted(date: .omitted, time: .shortened)) → \(end.formatted(date: .omitted, time: .shortened))")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Spacer()
                                
                                Text(timeString(from: timeRemaining))
                                    .font(.system(.body, design: .monospaced).bold())
                                    .foregroundColor(gaugeColor)
                            }
                        }
                    }
                    
                    // Bouton Adhkar plus grand
                    Button(action: { showAdhkarSheet = true }) {
                        HStack {
                            Image(systemName: "hands.sparkles.fill")
                            Text("Invocations après la prière")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassEffect()
                        .foregroundColor(.orange)

                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
            } else if prayerVM.nextPrayerName == "Fajr",
                      let middle = prayerVM.middleOfNight,
                      let lastThird = prayerVM.lastThirdOfNight {
                
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // 2. CARTE : NUIT (QIYAM)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                VStack(alignment: .leading, spacing: 20) {
                    // En-tête
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.title2)
                        Text("Prière de la Nuit")
                            .font(.headline)
                        Spacer()
                        Text("قيام الليل")
                            .font(.title2.bold())
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    .foregroundColor(.indigo)
                    
                    Text("« Notre Seigneur descend chaque nuit vers le ciel le plus bas lorsqu'il ne reste que le dernier tiers... » (Bukhari)")
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Horaires aérés
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Moitié de la nuit")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(middle.formatted(date: .omitted, time: .shortened))
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Dernier tiers")
                                .font(.caption)
                                .foregroundColor(.indigo)
                            Text(lastThird.formatted(date: .omitted, time: .shortened))
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundColor(.indigo)
                        }
                    }
                    
                    // Bouton Invocations DE RETOUR À SA PLACE !
                    Button(action: { showAdhkarSheet = true }) {
                        HStack {
                            Image(systemName: "moon.haze.fill")
                            Text("Invocations de la nuit")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.indigo.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .foregroundColor(.indigo)
                    }
                }
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.indigo.opacity(0.4), lineWidth: 1)
                )
                
            } else {
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                // 3. CARTE : RAPPEL CORANIQUE (Rotation intelligente)
                // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                let reminder = currentReminder
                
                VStack(alignment: .leading, spacing: 16) {
                    // En-tête avec icône et badge "Rappel"
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(reminder.color.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: reminder.icon)
                                .font(.title3)
                                .foregroundColor(reminder.color)
                                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rappel")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(reminder.color.opacity(0.8))
                            
                            Text("En attendant la prochaine Salât")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Spacer()
                        
                        // Petit bouton pour partager
                        ShareLink(item: "\(reminder.arabic)\n\n\(reminder.french)\n\n— \(reminder.source)") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(reminder.color.opacity(0.7))
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Verset en arabe
                    Text(reminder.arabic)
                        .font(.system(size: 19, weight: .medium))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineSpacing(8)
                        .foregroundColor(.white)
                    
                    // Traduction
                    Text("« \(reminder.french) »")
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Source avec design amélioré
                    HStack {
                        Spacer()
                        
                        Text("— \(reminder.source)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(reminder.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(reminder.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [reminder.color.opacity(0.4), reminder.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                // Petite ombre colorée subtile
                .shadow(color: reminder.color.opacity(0.15), radius: 8, x: 0, y: 4)
                // Animation d'apparition
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showAdhkarSheet) {
            // Logique dynamique pour charger le bon JSON
            let sheetContext = prayerVM.currentPrayerWindow != .none ? prayerVM.currentPrayerWindow.rawValue : "qiyam"
            PostPrayerAdhkarView(prayerName: sheetContext)
                .presentationDetents([.large])
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let h = Int(timeInterval) / 3600
        let m = Int(timeInterval) / 60 % 60
        let s = Int(timeInterval) % 60
        if h > 0 { return String(format: "-%d:%02d:%02d", h, m, s) }
        return String(format: "-%02d:%02d", m, s)
    }
}

// MARK: - PostPrayerAdhkarView (Sheet)
struct PostPrayerAdhkarView: View {
    let prayerName: String
    @StateObject private var service = PostPrayerAdhkarService()
    
    // Déduction d'un nom propre pour l'affichage
    private var displayName: String {
        if prayerName.lowercased() == "qiyam" {
            return "la Prière de la Nuit"
        }
        return "la prière (\(prayerName.capitalized))"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── EN-TÊTE PREMIUM ──
            VStack(spacing: 8) {
                Text("أذكار بعد الصلاة")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .environment(\.layoutDirection, .rightToLeft)
                
                Text("Adhkar après \(displayName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            // ── LISTE DES ADHKAR ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(service.adhkarList) { dhikr in
                        PostPrayerDhikrCardView(dhikr: dhikr)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        // Fond harmonisé avec ton thème sombre/chaud
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.05, blue: 0.05), Color(red: 0.2, green: 0.1, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .task {
            service.loadAdhkar(for: prayerName)
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// CARTE INDIVIDUELLE (Design sans clic/compteur)
// ═══════════════════════════════════════════════════════════

struct PostPrayerDhikrCardView: View {
    let dhikr: PostPrayerDhikr
    let accentColor: Color = .orange // Couleur raccord avec le thème Salat
    
    // État local pour chaque carte (pas besoin de les sauvegarder globalement ici)
    @State private var showArabic: Bool = true
    @State private var showBenefit: Bool = false
    
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
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // ── TEXTE FRANÇAIS ──
            if !showArabic {
                Text(dhikr.text)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.white.opacity(0.8))
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
            
            // ── BARRE DU BAS : Source + Boutons + Badge ──
            HStack(spacing: 10) {
                // Source
                Text(dhikr.source)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                // Toggle langue
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showArabic.toggle()
                    }
                } label: {
                    Text(showArabic ? "FR" : "عربي")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
                
                // Toggle bienfait
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBenefit.toggle()
                    }
                } label: {
                    Image(systemName: showBenefit ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 12))
                        .foregroundColor(showBenefit ? accentColor : .white.opacity(0.5))
                }
                
                // ── BADGE DE RÉPÉTITION (Statique) ──
                // On l'affiche toujours pour être clair sur ce qu'il faut faire
                Text("x \(dhikr.repeatCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.2))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(accentColor.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: showArabic)
        .animation(.easeInOut(duration: 0.2), value: showBenefit)
    }
}

// MARK: - GPSRelocationIndicator
struct GPSRelocationIndicator: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    var body: some View {
        if prayerVM.hasMovedSignificantly {
            Button(action: {
                withAnimation { prayerVM.relocateAndRecalculate() }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill.viewfinder")
                    Text("Recalculer position (> 15km)")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.blue.opacity(0.5), lineWidth: 1))
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}
