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

/// Modèle unique pour toutes les invocations (matin/soir ET après la prière).
/// `timing` est renseigné dans adhkar.json, `prayer` dans post_prayer_adhkar.json —
/// les deux sont optionnels pour décoder chaque fichier avec le même type.
struct Dhikr: Codable, Identifiable {
    let id: Int
    let text: String
    let arabic: String
    let source: String
    let `repeat`: Int
    /// "morning", "evening", "both" — adhkar matin/soir uniquement.
    let timing: String?
    /// "all", "fajr", "fajr_maghrib", "qiyam" — adhkar post-prière uniquement.
    let prayer: String?
    /// Répétition spécifique après Fajr et Maghrib (ex : sourates protectrices ×3
    /// au lieu de ×1 — Abu Dawud 5082). `nil` ⇒ `repeat` s'applique partout.
    let repeatFajrMaghrib: Int?
    let benefit: String

    /// Niveau d'authenticité du hadith — "sahih" (authentique) ou "hasan" (bon).
    /// Optional pour rester rétrocompatible avec les anciens JSON bundlés/distants.
    let authenticity: String?

    /// Nombre de répétitions effectif pour la prière donnée (clé en minuscules :
    /// "fajr", "dhuhr", ...). Applique l'exception Fajr/Maghrib si définie.
    func effectiveRepeat(for prayerKey: String) -> Int {
        if let override = repeatFajrMaghrib, prayerKey == "fajr" || prayerKey == "maghrib" {
            return override
        }
        return `repeat`
    }
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

    /// Fond de la sheet Adhkar (matin doré / soir bleu nuit) — une seule définition
    /// pour le bouton d'accès rapide et les deep-links (Control Widget, notification).
    var sheetGradient: LinearGradient {
        LinearGradient(
            colors: self == .morning
                ? [Color(red: 0.15, green: 0.1, blue: 0.05), Color(red: 0.25, green: 0.18, blue: 0.08)]
                : [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.1, blue: 0.25)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Période du moment : matin de Fajr à Asr d'après les heures réelles ;
    /// repli horaire 4 h–15 h tant que les horaires sont inconnus.
    static func current(now: Date = Date(), fajr: Date?, asr: Date?, calendar: Calendar = .current) -> AdhkarTiming {
        if let fajr, let asr {
            return now >= fajr && now < asr ? .morning : .evening
        }
        let hour = calendar.component(.hour, from: now)
        return (hour >= 4 && hour < 15) ? .morning : .evening
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

    // MARK: - Clés UserDefaults (partagées avec le bouton d'accès rapide, qui
    // lit la progression du jour sans instancier le service)

    static func countsKey(for timing: AdhkarTiming) -> String {
        "adhkar_counts_\(timing.rawValue)"
    }

    static func periodKey(for timing: AdhkarTiming) -> String {
        "adhkar_period_\(timing.rawValue)"
    }

    private static let periodFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Identifiant unique de la période active :
    /// - Matin  → "morning-YYYY-MM-DD"  (Fajr est toujours avant minuit)
    /// - Soir   → "evening-YYYY-MM-DD"  (peut déborder après minuit jusqu'au Fajr ;
    ///   repli 4 h si l'heure du Fajr est inconnue)
    static func periodID(for timing: AdhkarTiming, now: Date, fajr: Date?, calendar: Calendar = .current) -> String {
        switch timing {
        case .morning:
            return "morning-\(periodFormatter.string(from: now))"
        case .evening:
            let isBeforeFajr: Bool
            if let fajr {
                isBeforeFajr = now < fajr
            } else {
                isBeforeFajr = calendar.component(.hour, from: now) < 4
            }
            let reference = isBeforeFajr ? (calendar.date(byAdding: .day, value: -1, to: now) ?? now) : now
            return "evening-\(periodFormatter.string(from: reference))"
        }
    }

    private func countsKey(for timing: AdhkarTiming) -> String { Self.countsKey(for: timing) }
    private func periodKey(for timing: AdhkarTiming) -> String { Self.periodKey(for: timing) }
    private func currentPeriodID(for timing: AdhkarTiming) -> String {
        Self.periodID(for: timing, now: Date(), fajr: storedFajr)
    }

    /// Progression persistée pour `timing` : nombre d'adhkar complétés sur le
    /// total, ou `nil` si la période enregistrée n'est plus celle du moment
    /// (compteurs périmés ⇒ 0 implicite côté appelant).
    static func savedProgress(for timing: AdhkarTiming, adhkar: [Dhikr], now: Date, fajr: Date?) -> (done: Int, total: Int)? {
        let list = adhkar.filter { $0.timing == "both" || $0.timing == timing.rawValue }
        guard !list.isEmpty else { return nil }
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: periodKey(for: timing)) == periodID(for: timing, now: now, fajr: fajr),
              let saved = defaults.dictionary(forKey: countsKey(for: timing)) as? [String: Int] else {
            return (0, list.count)
        }
        let done = list.filter { (saved["\($0.id)"] ?? 0) >= $0.repeat }.count
        return (done, list.count)
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

        Task { @MainActor in
            let githubURL = "https://sulayman74.github.io/Muslim_clock_app/adhkar.json"
            guard let allAdhkar = await RemoteJSONLoader.load(
                filename: "adhkar.json",
                remoteURL: githubURL,
                type: [Dhikr].self
            ) else { return }

            adhkarList = allAdhkar.filter { $0.timing == "both" || $0.timing == timing.rawValue }

            // Base : tous à 0, puis restauration ou reset selon la période
            completedCounts = Dictionary(uniqueKeysWithValues: adhkarList.map { ($0.id, 0) })
            applyOrResetCounts(for: timing)
        }
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
    /// Si fourni, force le timing affiché (utilisé par les deep-links notif :
    /// `adhkar_morning` et `adhkar_evening`). Si `nil`, auto-détection via
    /// `service.autoTiming` selon l'heure courante et Fajr/Asr.
    var initialTiming: AdhkarTiming? = nil

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
                            repeatCount: dhikr.repeat,
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
            // 2. Timing forcé (deep-link notif) ou auto-détection avec Fajr/Asr
            selectedTiming = initialTiming ?? service.autoTiming
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
            .glassEffect(.regular, in: Capsule())
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
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
    /// Répétitions affichées — passer `dhikr.effectiveRepeat(for:)` côté post-prière
    /// pour appliquer l'exception Fajr/Maghrib.
    let repeatCount: Int
    let count: Int
    let isCompleted: Bool
    let showArabic: Bool
    let showBenefit: Bool
    let accentColor: Color
    /// `nil` ⇒ mode consultation : badge statique "x N" au lieu du compteur interactif.
    let onTap: (() -> Void)?
    let onToggleArabic: () -> Void
    let onToggleBenefit: () -> Void

    /// Couleur du badge d'authenticité : vert (sahih), jaune (hasan),
    /// gris (à vérifier / inconnu — contenu à ne pas diffuser tel quel).
    private var authColor: Color {
        switch dhikr.authenticity {
        case "sahih": return .green
        case "hasan": return .yellow
        default:      return .gray
        }
    }

    /// Libellé lisible du badge d'authenticité.
    private var authLabel: String {
        switch dhikr.authenticity {
        case "sahih":      return "SAHIH"
        case "hasan":      return "HASAN"
        case "a_verifier": return String(localized: "À VÉRIFIER")
        default:           return dhikr.authenticity?.uppercased() ?? ""
        }
    }

    /// Pastille d'authenticité affichée à côté de la source (rien si absente).
    @ViewBuilder
    private var authBadge: some View {
        if dhikr.authenticity != nil {
            Text(verbatim: authLabel)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.5)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .glassEffect(.clear.tint(authColor.opacity(0.18)), in: Capsule())
                .foregroundStyle(authColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // ── TEXTE ARABE ──
            if showArabic {
                Text(dhikr.arabic)
                    .font(.system(size: 20, weight: .regular))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineSpacing(10)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.9))
            }

            // ── TEXTE FRANÇAIS ──
            if !showArabic {
                Text(verbatim: dhikr.text)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // Badge authenticité (sahih / hasan / à vérifier)
                authBadge

                Spacer()
                
                // Toggle langue
                Button(action: onToggleArabic) {
                    Text(verbatim: showArabic ? "FR" : "عربي")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassEffect(.clear, in: Capsule())
                }
                
                // Toggle bienfait
                Button(action: onToggleBenefit) {
                    Image(systemName: showBenefit ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 12))
                        .foregroundColor(showBenefit ? accentColor : .white.opacity(0.5))
                }
                
                // ── COMPTEUR / TAP ZONE (ou badge statique en mode consultation) ──
                if let onTap {
                    Button(action: onTap) {
                        HStack(spacing: 6) {
                            if isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 18))
                            } else {
                                Text(verbatim: "\(count)/\(repeatCount)")
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
                } else {
                    Text(verbatim: "x \(repeatCount)")
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
    /// Variante compacte (demi-largeur, zone secondaire de l'écran Salat) :
    /// icône + libellé FR une ligne, verre secondaire.
    var compact: Bool = false
    @State private var showAdhkarSheet = false
    @EnvironmentObject var prayerVM: PrayerTimesViewModel

    /// Ce que le bouton propose selon le moment. Il remplace les boutons qui
    /// vivaient dans la jauge de prière (quatre portes d'entrée Adhkar à l'écran).
    private enum Mode {
        /// Fenêtre de prière en cours → adhkar après la prière nommée.
        case postPrayer(String)
        /// Nuit (après le milieu de la nuit, avant Fajr) → invocations de la nuit.
        case night
        /// Sinon : adhkar du matin ou du soir.
        case daily(AdhkarTiming)

        var icon: String {
            switch self {
            case .postPrayer: "hands.sparkles.fill"
            case .night: "moon.haze.fill"
            case .daily(let timing): timing.icon
            }
        }

        var accent: Color {
            switch self {
            case .postPrayer: PrayerStateTint.now
            case .night: PrayerStateTint.night
            case .daily(let timing): timing.accentColor
            }
        }

        var labelFr: String {
            switch self {
            case .postPrayer: String(localized: "Invocations après la prière")
            case .night: String(localized: "Invocations de la nuit")
            case .daily(let timing): timing.labelFr
            }
        }

        var labelAr: String {
            switch self {
            case .postPrayer: "أذكار بعد الصلاة"
            case .night: "أذكار قيام الليل"
            case .daily(let timing): timing.label
            }
        }
    }

    private var mode: Mode {
        if prayerVM.currentPrayerWindow != .none {
            return .postPrayer(prayerVM.currentPrayerWindow.rawValue)
        }
        if prayerVM.nextPrayerName == "Fajr", prayerVM.lastThirdOfNight != nil {
            return .night
        }
        return .daily(AdhkarTiming.current(fajr: prayerVM.fajrDate, asr: prayerVM.asrDate))
    }

    /// Liste des adhkar matin/soir (cache local), pour la progression du jour.
    @State private var adhkar: [Dhikr] = []
    /// Relit la progression persistée à la fermeture de la sheet.
    @State private var progressTick = 0

    /// « Ai-je fait mes adhkar ? » — fait / total pour la période courante
    /// (mode matin/soir uniquement). `nil` tant que la liste n'est pas chargée.
    private func progress(for mode: Mode) -> (done: Int, total: Int)? {
        guard case .daily(let timing) = mode else { return nil }
        _ = progressTick
        return AdhkarService.savedProgress(for: timing, adhkar: adhkar, now: Date(), fajr: prayerVM.fajrDate)
    }

    var body: some View {
        let mode = mode
        let progress = progress(for: mode)

        Button {
            showAdhkarSheet = true
        } label: {
            if compact {
                HStack(spacing: 8) {
                    if let progress {
                        progressRing(progress, accent: mode.accent)
                    } else {
                        Image(systemName: mode.icon)
                            .font(.system(size: 18))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(mode.accent, .white.opacity(0.6))
                    }
                    Text(verbatim: mode.labelFr)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 4)
                .glassCardSecondary(cornerRadius: CornerRadius.card, tint: mode.accent)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progress.map { Text("\(mode.labelFr), \($0.done) sur \($0.total) complétés") } ?? Text(verbatim: mode.labelFr))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 22))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(mode.accent, .white.opacity(0.6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: mode.labelAr)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(verbatim: mode.labelFr)
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
                .glassCard(tint: mode.accent)
            }
        }
        // Haptique à l'ouverture seulement (pas à la fermeture de la sheet).
        .sensoryFeedback(.impact(weight: .light), trigger: showAdhkarSheet) { _, opened in opened }
        .task {
            if adhkar.isEmpty {
                adhkar = await RemoteJSONLoader.load(
                    filename: "adhkar.json",
                    remoteURL: "https://sulayman74.github.io/Muslim_clock_app/adhkar.json",
                    type: [Dhikr].self
                ) ?? []
            }
        }
        .onChange(of: showAdhkarSheet) { _, open in
            if !open { progressTick &+= 1 }
        }
        .sheet(isPresented: $showAdhkarSheet) {
            switch mode {
            case .postPrayer(let prayerName):
                PostPrayerAdhkarView(prayerName: prayerName)
                    .presentationDetents([.large])
            case .night:
                PostPrayerAdhkarView(prayerName: "qiyam")
                    .presentationDetents([.large])
            case .daily(let timing):
                ZStack {
                    timing.sheetGradient
                        .ignoresSafeArea()
                    AdhkarView()
                }
                .environmentObject(prayerVM)  // Transmission des heures de prière à la sheet
                .presentationDragIndicator(.visible)
            }
        }
    }

    /// Anneau fait / total (coche quand tout est complété).
    private func progressRing(_ progress: (done: Int, total: Int), accent: Color) -> some View {
        let fraction = progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.35), value: fraction)
            if progress.done >= progress.total {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent)
            } else {
                Text(verbatim: "\(progress.done)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: 24, height: 24)
    }
}
