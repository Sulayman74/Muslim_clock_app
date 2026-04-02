import Foundation
import Combine
import SwiftUI

// MARK: - Modèles API Coran
struct QuranAPIResponse: Codable {
    let data: AyahData
}
struct AyahData: Codable {
    let text: String
    let numberInSurah: Int
    let surah: SurahData
}
struct SurahData: Codable {
    let englishName: String
    let name: String?       // Nom arabe de la sourate (ex: الفاتحة)
}

// MARK: - Modèle JSON local
struct CuratedHadith: Codable {
    let text: String
    let arabic: String
    let source: String
    let theme: String
    let season: String
}


// MARK: - Enum Season
enum HadithSeason: String, CaseIterable {
   case general
   case ramadan
   case hajj
   case joumouha
   case muharram
   case shaban
   case shawwal
   case lundiJeudi = "lundi_jeudi"
   case matin
   case soir
    case aid
}

// MARK: - Service
@MainActor
class DailyContentService: ObservableObject {
    
    // Coran
    @Published var dailyAyah: String = "Chargement..."
    @Published var dailyAyahArabic: String = ""
    @Published var dailyAyahSource: String = ""
    @Published var isFetchingQuran: Bool = false
    
    // Hadith
    @Published var dailyHadith: String = "Chargement..."
    @Published var dailyHadithArabic: String = ""
    @Published var dailyHadithSource: String = ""
    
    @Published var isLoading: Bool = true
    
    // MARK: - Calendrier Hégirien
    private let islamicCalendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar")
        return cal
    }()
    
    // MARK: - Chargement Initial (Appel au lancement)
        func fetchDailyContent() async {
            self.isLoading = true
            
            // 1. HADITH local filtré par saison (Reste fixe toute la journée)
            loadSeasonalHadith()
            
            // 2. CORAN : On lance le premier chargement aléatoire
            await fetchRandomQuranVerse()
            
            self.isLoading = false
        }
    // MARK: - 📖 CORAN : Totalement Aléatoire et sur demande
        func fetchRandomQuranVerse() async {
            // Active l'état de chargement pour l'UI (le bouton de refresh par exemple)
            self.isFetchingQuran = true
            
            // 🚀 Vrai random (1 à 6236) à CHAQUE appel !
            // (J'ai supprimé getDeterministicAyahNumber() qui bloquait le verset)
            let randomAyahNumber = Int.random(in: 1...6236)
            
            async let frenchFetch = fetchAyah(number: randomAyahNumber, edition: "fr.hamidullah")
            async let arabicFetch = fetchAyah(number: randomAyahNumber, edition: "quran-uthmani")
            
            let (frenchResult, arabicResult) = await (frenchFetch, arabicFetch)
            
            if let french = frenchResult {
                self.dailyAyah = french.data.text
                let surahName = french.data.surah.name ?? french.data.surah.englishName
                self.dailyAyahSource = "Sourate \(french.data.surah.englishName) (\(surahName)), Verset \(french.data.numberInSurah)"
            } else {
                self.dailyAyah = "« Dieu est avec les patients. »"
                self.dailyAyahSource = "Sourate Al-Baqara, Verset 153"
            }
            
            if let arabic = arabicResult {
                self.dailyAyahArabic = arabic.data.text
            } else {
                self.dailyAyahArabic = "إِنَّ اللَّهَ مَعَ الصَّابِرِينَ"
            }
            
            self.isFetchingQuran = false
        }
    
    // MARK: - Fetch générique
    private func fetchAyah(number: Int, edition: String) async -> QuranAPIResponse? {
        let urlString = "https://api.alquran.cloud/v1/ayah/\(number)/\(edition)"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(QuranAPIResponse.self, from: data)
        } catch {
            print("❌ Erreur API Coran (\(edition)) : \(error)")
            return nil
        }
    }
    
    // MARK: - Détection de la saison courante
    
    /// Retourne les seasons actives en ce moment (peut en avoir plusieurs)
    private func currentSeasons() -> [HadithSeason] {
        var seasons: [HadithSeason] = []
        let now = Date()
        
        // ── Mois Hégirien ──
        let hijriMonth = islamicCalendar.component(.month, from: now)
        
        switch hijriMonth {
        case 1:  // Muharram
            seasons.append(.muharram)
        case 8:  // Sha'ban
            seasons.append(.shaban)
        case 9:  // Ramadan
            seasons.append(.ramadan)
        case 10: // Shawwal
            seasons.append(.shawwal)
        case 12: // Dhu al-Hijjah
            seasons.append(.hajj)
        default:
            break
        }
        
        // ── Jour de la semaine (grégorien) ──
        let gregorian = Calendar(identifier: .gregorian)
        let weekday = gregorian.component(.weekday, from: now) // 1=Dim, 2=Lun, ... 6=Ven, 7=Sam
        
        switch weekday {
        case 6: // Vendredi
            seasons.append(.joumouha)
        case 2, 5: // Lundi, Jeudi
            seasons.append(.lundiJeudi)
        default:
            break
        }
        
        // ── Moment de la journée ──
        let hour = gregorian.component(.hour, from: now)
        
        if hour >= 4 && hour < 12 {
            seasons.append(.matin)
        } else if hour >= 17 || hour < 4 {
            seasons.append(.soir)
        }
        
        return seasons
    }
    
    // MARK: - Chargement du Hadith saisonnier
    private func loadSeasonalHadith() {
        guard let url = Bundle.main.url(forResource: "hadiths", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let allHadiths = try? JSONDecoder().decode([CuratedHadith].self, from: data) else {
            setFallbackHadith()
            return
        }
        
        let activeSeasonsRaw = currentSeasons().map(\.rawValue)
        
        // 1. Filtrer les hadiths saisonniers (hors "general")
        let seasonalHadiths = allHadiths.filter { h in
            h.season != "general" && activeSeasonsRaw.contains(h.season)
        }
        
        // 2. Sélection déterministe (même hadith toute la journée)
        let chosenHadith: CuratedHadith
        
        if !seasonalHadiths.isEmpty {
            // 70% de chance de piocher un hadith saisonnier, 30% general
            let seed = dailySeed()
            var rng = SeededRandomNumberGenerator(seed: seed)
            let roll = Int.random(in: 1...10, using: &rng)
            
            if roll <= 7 {
                // Hadith saisonnier
                let index = Int.random(in: 0..<seasonalHadiths.count, using: &rng)
                chosenHadith = seasonalHadiths[index]
            } else {
                // Hadith general
                let generalHadiths = allHadiths.filter { $0.season == "general" }
                let index = Int.random(in: 0..<generalHadiths.count, using: &rng)
                chosenHadith = generalHadiths[index]
            }
        } else {
            // Pas de saison spéciale → general uniquement
            let generalHadiths = allHadiths.filter { $0.season == "general" }
            var rng = SeededRandomNumberGenerator(seed: dailySeed())
            let index = Int.random(in: 0..<generalHadiths.count, using: &rng)
            chosenHadith = generalHadiths[index]
        }
        
        self.dailyHadith = chosenHadith.text
        self.dailyHadithArabic = chosenHadith.arabic
        self.dailyHadithSource = "\(chosenHadith.source) • \(chosenHadith.theme)"
    }
    
    // MARK: - Seed déterministe par jour
    private func dailySeed() -> UInt64 {
        let gregorian = Calendar(identifier: .gregorian)
        let components = gregorian.dateComponents([.year, .month, .day], from: Date())
        let dayValue = (components.year ?? 2025) * 10000 + (components.month ?? 1) * 100 + (components.day ?? 1)
        return UInt64(dayValue) &+ 0xCAFE  // Offset pour varier vs le Coran
    }
    
    // MARK: - Fallback
    private func setFallbackHadith() {
        self.dailyHadith = "« Les actes ne valent que par les intentions. »"
        self.dailyHadithArabic = "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ"
        self.dailyHadithSource = "Sahih Bukhari"
    }
}
 
// MARK: - Générateur pseudo-aléatoire seedé (pour contenu stable dans la journée)
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
 
