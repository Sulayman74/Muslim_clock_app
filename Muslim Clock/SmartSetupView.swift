import SwiftUI
import Adhan
import CoreLocation

struct SmartSetupView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    @State private var inputFajr: Date = .now
    @State private var inputDhuhr: Date = .now
    @State private var inputAsr: Date = .now
    @State private var inputMaghrib: Date = .now
    @State private var inputIsha: Date = .now
    
    @State private var isAnalyzing = false
    @State private var analysisResult: String? = nil
    
    // Accès aux AppStorage
    @AppStorage("userCalculationMethod") private var savedMethod = "UOIF (12°)"
    @AppStorage("userFajrOffset") private var savedFajrOffset = 0
    @AppStorage("userMaghribOffset") private var savedMaghribOffset = 0
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var savedIshaFixedDuration = 90
    @AppStorage("userIshaOffset") private var savedIshaOffset = 0
    @AppStorage("lastSmartSetupDate") private var lastSmartSetupDate: Double = 0
    @AppStorage("userDhuhrOffset") private var savedDhuhrOffset = 0
        @AppStorage("userAsrOffset") private var savedAsrOffset = 0
    
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            Form {
                Section {
                    Text("Saisissez les horaires affichés à votre mosquée aujourd'hui. L'app va analyser leur méthode et s'y conformer.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .listRowBackground(Color.clear)
                }
                
                Section("Horaires affichés à la Mosquée") {
                    DatePicker("Fajr", selection: $inputFajr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Dhuhr", selection: $inputDhuhr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    // L'Asr est souvent standard, on le garde pour le formulaire, mais le calcul astronomique se fait surtout sur Fajr/Isha
                    DatePicker("Asr", selection: $inputAsr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Maghrib", selection: $inputMaghrib, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Isha", selection: $inputIsha, displayedComponents: .hourAndMinute).colorScheme(.dark)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                Section {
                    Button(action: runAnalysis) {
                        HStack {
                            Spacer()
                            if isAnalyzing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Lancer l'analyse magique ✨").fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.orange)
                    .listRowBackground(Color.white.opacity(0.1))
                }
                
                if let result = analysisResult {
                    Section("Résultat de l'analyse") {
                        Text(result)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .listRowBackground(Color.green.opacity(0.2))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                prefillForm()
            }
        }
        .navigationTitle("Configuration Magique")
        .preferredColorScheme(.dark)
    }
    
    // MARK: - 🧠 LE CERVEAU MATHÉMATIQUE
    private func runAnalysis() {
        guard let location = prayerVM.lastLocation else {
            analysisResult = "⚠️ Erreur : Position GPS introuvable. Veuillez activer la localisation."
            return
        }
        
        isAnalyzing = true
        analysisResult = nil
        
        // On simule un petit délai pour l'UX (laisser le temps à l'utilisateur de voir que ça travaille)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let coords = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let dateComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            
            // 1️⃣ Calcul du Maghrib (L'ancre absolue)
            // Le Maghrib ne dépend d'aucun angle. On peut utiliser n'importe quelle méthode pour obtenir la base.
            guard let baseTimes = PrayerTimes(coordinates: coords, date: dateComps, calculationParameters: CalculationMethod.muslimWorldLeague.params) else {
                isAnalyzing = false
                analysisResult = "Erreur de calcul astronomique."
                return
            }
            let detectedDhuhrOffset = minutesBetween(calculated: baseTimes.dhuhr, user: inputDhuhr)
            let detectedAsrOffset = minutesBetween(calculated: baseTimes.asr, user: inputAsr)
            let detectedMaghribOffset = minutesBetween(calculated: baseTimes.maghrib, user: inputMaghrib)
            
            // 2️⃣ Détection de l'Isha Fixe
            let ishaDifference = minutesBetween(calculated: inputMaghrib, user: inputIsha)
            var detectedIshaFixed = false
            var detectedIshaDuration = 90
            var detectedIshaOffset = 0
            
            // Si l'Isha est entre 60 et 120 minutes après le Maghrib, c'est presque toujours un lissage.
            if ishaDifference >= 60 && ishaDifference <= 120 {
                detectedIshaFixed = true
                detectedIshaDuration = ishaDifference
            }
            
            // 3️⃣ Rétro-ingénierie du Fajr (Trouver le meilleur Angle)
            let testAngles = [
                ("UOIF (12°)", 12.0),
                ("ISNA (15°)", 15.0),
                ("Ligue Islamique (18°)", 18.0)
            ]
            
            var bestMethodName = "UOIF (12°)"
            var bestFajrOffset = 0
            var bestScore = Int.max
            
            for (methodName, angle) in testAngles {
                var testParams = CalculationMethod.other.params
                testParams.fajrAngle = angle
                testParams.ishaAngle = angle
                
                if let testTimes = PrayerTimes(coordinates: coords, date: dateComps, calculationParameters: testParams) {
                    let fajrOffset = minutesBetween(calculated: testTimes.fajr, user: inputFajr)
                    
                    // SCORING : On cherche un offset le plus proche de 0 possible.
                    // Les mosquées ont tendance à faire des offsets POSITIFS (ajouter des minutes).
                    // On pénalise très lourdement les offsets négatifs (sauf -1 ou -2 qui sont des arrondis).
                    let score = fajrOffset >= -2 ? fajrOffset : abs(fajrOffset) + 100
                    
                    if score < bestScore {
                        bestScore = score
                        bestMethodName = methodName
                        bestFajrOffset = fajrOffset
                    }
                    
                    // Si l'Isha n'est pas fixe, on calcule l'offset d'Isha pour cet angle gagnant
                    if !detectedIshaFixed && score == bestScore {
                        detectedIshaOffset = minutesBetween(calculated: testTimes.isha, user: inputIsha)
                    }
                }
            }
            
            // 4️⃣ Application des résultats !
            self.savedMethod = bestMethodName
            self.savedFajrOffset = bestFajrOffset
            self.savedDhuhrOffset = detectedDhuhrOffset
            self.savedAsrOffset = detectedAsrOffset     
            self.savedMaghribOffset = detectedMaghribOffset
            self.isIshaFixed = detectedIshaFixed
            self.savedIshaFixedDuration = detectedIshaDuration
            self.savedIshaOffset = detectedIshaOffset
            
            self.lastSmartSetupDate = Date().timeIntervalSince1970
            
            // On force la vue Salat à se mettre à jour
            prayerVM.forceRecalculation()
            
            // Affichage du compte-rendu
            let ishaText = detectedIshaFixed ? "Fixe (\(detectedIshaDuration) min après Maghrib)" : "Astronomique (Décalage: \(detectedIshaOffset) min)"
            
            // 🚀 MISE À JOUR DE L'AFFICHAGE
                        self.analysisResult = """
                        ✅ Analyse réussie !
                        
                        D'après les mathématiques, votre mosquée utilise :
                        • Angle : \(bestMethodName)
                        • Fajr : \(bestFajrOffset > 0 ? "+" : "")\(bestFajrOffset) min
                        • Dhuhr : \(detectedDhuhrOffset > 0 ? "+" : "")\(detectedDhuhrOffset) min
                        • Asr : \(detectedAsrOffset > 0 ? "+" : "")\(detectedAsrOffset) min
                        • Maghrib : \(detectedMaghribOffset > 0 ? "+" : "")\(detectedMaghribOffset) min
                        • Isha : \(ishaText)
                        
                        Ces réglages sont appliqués à l'application.
                        """
                        
                        isAnalyzing = false
        }
    }
    
    // MARK: - 🎯 PRÉ-REMPLISSAGE (Baseline)
        private func prefillForm() {
            // On vérifie qu'on a bien le GPS de l'utilisateur
            guard let location = prayerVM.lastLocation else { return }
            
            let coords = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let dateComps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            
            // On utilise la méthode Umm Al-Qura comme base "pure" (sans aucun de nos offsets)
            var params = CalculationMethod.ummAlQura.params
            params.madhab = .shafi // Très important pour l'Asr majoritaire en Europe
            
            if let baseTimes = PrayerTimes(coordinates: coords, date: dateComps, calculationParameters: params) {
                // On met à jour les DatePicker avec ces valeurs par défaut !
                self.inputFajr = baseTimes.fajr
                self.inputDhuhr = baseTimes.dhuhr
                self.inputAsr = baseTimes.asr
                self.inputMaghrib = baseTimes.maghrib
                self.inputIsha = baseTimes.isha
            }
        }
    
    // Helper : Compare seulement les heures et les minutes pour éviter les bugs de dates (jours différents)
    private func minutesBetween(calculated: Date, user: Date) -> Int {
        let calComps = Calendar.current.dateComponents([.hour, .minute], from: calculated)
        let userComps = Calendar.current.dateComponents([.hour, .minute], from: user)
        
        let calTotalMinutes = (calComps.hour ?? 0) * 60 + (calComps.minute ?? 0)
        let userTotalMinutes = (userComps.hour ?? 0) * 60 + (userComps.minute ?? 0)
        
        return userTotalMinutes - calTotalMinutes
    }
}
