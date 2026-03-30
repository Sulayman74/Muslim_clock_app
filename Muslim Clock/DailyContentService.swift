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
    let arabic: String       // ← NOUVEAU : texte arabe
    let source: String
    let theme: String
}

// MARK: - Service
@MainActor
class DailyContentService: ObservableObject {
    
    // Coran
    @Published var dailyAyah: String = "Chargement..."
    @Published var dailyAyahArabic: String = ""          // ← NOUVEAU
    @Published var dailyAyahSource: String = ""
    
    // Hadith
    @Published var dailyHadith: String = "Chargement..."
    @Published var dailyHadithArabic: String = ""         // ← NOUVEAU
    @Published var dailyHadithSource: String = ""
    
    @Published var isLoading: Bool = true

    func fetchDailyContent() async {
        self.isLoading = true
        
        // 1. CORAN : On fetch les DEUX langues en parallèle
        let randomAyahNumber = Int.random(in: 1...6236)
        
        async let frenchFetch = fetchAyah(number: randomAyahNumber, edition: "fr.hamidullah")
        async let arabicFetch = fetchAyah(number: randomAyahNumber, edition: "quran-uthmani")
        
        let (frenchResult, arabicResult) = await (frenchFetch, arabicFetch)
        
        if let french = frenchResult {
            self.dailyAyah = french.data.text
            // On utilise le nom arabe de la sourate si dispo
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
        
        // 2. HADITH local
        loadLocalHadith()
        
        self.isLoading = false
    }
    
    // MARK: - Fetch générique pour n'importe quelle édition
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
    
    // MARK: - Hadith local avec champ arabe
    private func loadLocalHadith() {
        guard let url = Bundle.main.url(forResource: "hadiths", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let hadithsList = try? JSONDecoder().decode([CuratedHadith].self, from: data),
              let randomHadith = hadithsList.randomElement() else {
            
            self.dailyHadith = "« Les actes ne valent que par les intentions. »"
            self.dailyHadithArabic = "إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ"
            self.dailyHadithSource = "Sahih Bukhari"
            return
        }
        
        self.dailyHadith = randomHadith.text
        self.dailyHadithArabic = randomHadith.arabic
        self.dailyHadithSource = "\(randomHadith.source) • \(randomHadith.theme)"
    }
}
