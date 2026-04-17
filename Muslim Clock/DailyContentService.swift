import Foundation
import SwiftUI
import Combine

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

// MARK: - Modèle JSON local Hadith
struct CuratedHadith: Codable {
    let text: String
    let arabic: String
    let source: String
    let theme: String
    let season: String
}

// MARK: - Enum Season
enum HadithSeason: String, CaseIterable {
   case general, ramadan, hajj, joumouha, muharram, shaban, shawwal
   case lundiJeudi = "lundi_jeudi"
   case matin, soir, aid
}

// MARK: - Service
@MainActor
class DailyContentService: ObservableObject {
    
    // Coran
    @Published var dailyAyah: String = "Chargement..."
    @Published var dailyAyahArabic: String = ""
    @Published var dailyAyahSource: String = ""
    @Published var dailyAyahAudioURL: URL? = nil
    @Published var isFetchingQuran: Bool = false
    
    // Hadith
    @Published var dailyHadith: String = "Chargement..."
    @Published var dailyHadithArabic: String = ""
    @Published var dailyHadithSource: String = ""
    
    @Published var isLoading: Bool = true
    /// `true` si le dernier chargement a échoué (réseau absent)
    @Published var hasNetworkError: Bool = false
    
    // Calendrier Hégirien
    private let islamicCalendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar")
        return cal
    }()
    
    // MARK: - Chargement Initial
    func fetchDailyContent() async {
        self.isLoading = true
        self.hasNetworkError = false
        await loadSeasonalHadith()
        await fetchRandomQuranVerse()
        self.isLoading = false
    }
    
    // MARK: - Coran aléatoire avec audio
    func fetchRandomQuranVerse() async {
        self.isFetchingQuran = true
        let randomAyahNumber = Int.random(in: 1...6236)
        self.dailyAyahAudioURL = URL(string: "https://cdn.islamic.network/quran/audio/128/ar.alafasy/\(randomAyahNumber).mp3")
        
        async let frenchFetch = fetchAyah(number: randomAyahNumber, edition: "fr.hamidullah")
        async let arabicFetch = fetchAyah(number: randomAyahNumber, edition: "quran-uthmani")
        
        let (frenchResult, arabicResult) = await (frenchFetch, arabicFetch)
        
        if let french = frenchResult {
            self.dailyAyah = french.data.text
            let surahName = french.data.surah.name ?? french.data.surah.englishName
            self.dailyAyahSource = "Sourate \(french.data.surah.englishName) (\(surahName)), Verset \(french.data.numberInSurah)"
        } else {
            self.hasNetworkError = true
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
    
    private func fetchAyah(number: Int, edition: String) async -> QuranAPIResponse? {
        guard let url = URL(string: "https://api.alquran.cloud/v1/ayah/\(number)/\(edition)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(QuranAPIResponse.self, from: data)
        } catch {
            print("❌ Erreur API Coran (\(edition)) : \(error)")
            return nil
        }
    }
    
    // MARK: - Détection des saisons actives
    private func currentSeasons() -> [HadithSeason] {
        var seasons: [HadithSeason] = []
        let now = Date()
        
        // Mois Hégirien
        let hijriMonth = islamicCalendar.component(.month, from: now)
        switch hijriMonth {
        case 1: seasons.append(.muharram)
        case 8: seasons.append(.shaban)
        case 9: seasons.append(.ramadan)
        case 10: seasons.append(.shawwal)
        case 12: seasons.append(.hajj)
        default: break
        }
        
        // Jour grégorien
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: now)
        switch weekday {
        case 6: seasons.append(.joumouha)
        case 2,5: seasons.append(.lundiJeudi)
        default: break
        }
        
        // Moment de la journée
        let hour = Calendar(identifier: .gregorian).component(.hour, from: now)
        if hour >= 4 && hour < 12 { seasons.append(.matin) }
        else if hour >= 17 || hour < 4 { seasons.append(.soir) }
        
        return seasons
    }
    
    // MARK: - Chargement du hadith saisonnier aléatoire
    private func loadSeasonalHadith() async {
        let githubURL = "https://sulayman74.github.io/Muslim_clock_app/hadiths.json"
        guard let allHadiths = await RemoteJSONLoader.load(
            filename: "hadiths.json",
            remoteURL: githubURL,
            type: [CuratedHadith].self
        ) else {
            self.hasNetworkError = true
            setFallbackHadith()
            return
        }
        
        let activeSeasonsRaw = currentSeasons().map(\.rawValue)
        let seasonalHadiths = allHadiths.filter { $0.season != "general" && activeSeasonsRaw.contains($0.season) }
        let generalHadiths = allHadiths.filter { $0.season == "general" }
        
        let chosenHadith: CuratedHadith
        if !seasonalHadiths.isEmpty && !generalHadiths.isEmpty {
            // Le vendredi, on privilegie fortement les hadiths du joumouha (80%)
            let isFriday = Calendar.current.component(.weekday, from: Date()) == 6
            let seasonalWeight = isFriday ? 0.8 : 0.5
            chosenHadith = Double.random(in: 0...1) < seasonalWeight
                ? seasonalHadiths.randomElement()!
                : generalHadiths.randomElement()!
        } else if !seasonalHadiths.isEmpty {
            chosenHadith = seasonalHadiths.randomElement()!
        } else {
            chosenHadith = generalHadiths.randomElement()!
        }
        
        self.dailyHadith = chosenHadith.text
        self.dailyHadithArabic = chosenHadith.arabic
        self.dailyHadithSource = "\(chosenHadith.source) • \(chosenHadith.theme)"
    }
    
    // MARK: - Fallback
    private func setFallbackHadith() {
        self.dailyHadith = "« Les actes ne valent que par les intentions. »"
        self.dailyHadithArabic = "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ"
        self.dailyHadithSource = "Sahih Bukhari"
    }
}
