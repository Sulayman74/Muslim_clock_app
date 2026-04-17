import SwiftUI
import Adhan
import CoreLocation

struct SmartSetupView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    // Adhan inputs
    @State private var inputFajr: Date = .now
    @State private var inputDhuhr: Date = .now
    @State private var inputAsr: Date = .now
    @State private var inputMaghrib: Date = .now
    @State private var inputIsha: Date = .now
    
    @State private var isAnalyzing = false
    @State private var analysisResult: String? = nil
    
    // Accès aux AppStorage – Calcul
    @AppStorage("userCalculationMethod") private var savedMethod = "UOIF (12°)"
    @AppStorage("userFajrOffset") private var savedFajrOffset = 0
    @AppStorage("userMaghribOffset") private var savedMaghribOffset = 0
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var savedIshaFixedDuration = 90
    @AppStorage("userIshaOffset") private var savedIshaOffset = 0
    @AppStorage("lastSmartSetupDate") private var lastSmartSetupDate: Double = 0
    @AppStorage("userDhuhrOffset") private var savedDhuhrOffset = 0
    @AppStorage("userAsrOffset") private var savedAsrOffset = 0
    
    // Mosquée & Iqamah
    @AppStorage("mosqueName") private var savedMosqueName = ""
    @AppStorage("iqamahFajrDelay") private var savedIqamahFajr = 20
    @AppStorage("iqamahDhuhrDelay") private var savedIqamahDhuhr = 15
    @AppStorage("iqamahAsrDelay") private var savedIqamahAsr = 15
    @AppStorage("iqamahMaghribDelay") private var savedIqamahMaghrib = 5
    @AppStorage("iqamahIshaDelay") private var savedIqamahIsha = 15

    // Jumu'ah
    @AppStorage("jumuahEnabled") private var jumuahEnabled = false
    @AppStorage("jumuahHour") private var jumuahHour = 13
    @AppStorage("jumuahMinute") private var jumuahMinute = 0
    @State private var inputJumuah: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 13; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            Form {
                Section {
                    Text("Saisissez les horaires de votre mosquée aujourd'hui. L'app va en déduire la méthode de calcul et les délais Iqamah.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .listRowBackground(Color.clear)
                }
                
                // ── NOM DE LA MOSQUÉE ──
                Section("Ma Mosquée") {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.teal)
                        TextField("Nom de la mosquée", text: $savedMosqueName)
                            .foregroundColor(.white)
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // ── HORAIRES ADHAN ──
                Section("Horaires Adhan") {
                    DatePicker("Fajr", selection: $inputFajr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Dhuhr", selection: $inputDhuhr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Asr", selection: $inputAsr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Maghrib", selection: $inputMaghrib, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Isha", selection: $inputIsha, displayedComponents: .hourAndMinute).colorScheme(.dark)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // ── DÉLAIS IQAMAH (en minutes) ──
                Section {
                    IqamahRow(prayerName: "Fajr",    icon: "sun.and.horizon.fill", delay: $savedIqamahFajr)
                    IqamahRow(prayerName: "Dhuhr",   icon: "sun.max.fill",          delay: $savedIqamahDhuhr)
                    IqamahRow(prayerName: "Asr",     icon: "sun.dust.fill",         delay: $savedIqamahAsr)
                    IqamahRow(prayerName: "Maghrib", icon: "sunset.fill",            delay: $savedIqamahMaghrib)
                    IqamahRow(prayerName: "Isha",    icon: "moon.stars.fill",        delay: $savedIqamahIsha)
                } header: {
                    Text("Délai Adhan → Iqamah")
                } footer: {
                    Text("Durée entre l'adhan et l'iqamah dans votre mosquée (en minutes).")
                        .foregroundColor(.white.opacity(0.4))
                }
                .listRowBackground(Color.white.opacity(0.05))

                // ── JUMU'AH (VENDREDI) ──
                Section {
                    Toggle(isOn: $jumuahEnabled.animation()) {
                        HStack(spacing: 10) {
                            Image(systemName: "building.columns.fill")
                                .foregroundColor(.green)
                            Text("Heure Jumu'ah personnalisee")
                                .foregroundColor(.white)
                        }
                    }
                    .tint(.green)

                    if jumuahEnabled {
                        DatePicker("Heure Jumu'ah", selection: $inputJumuah, displayedComponents: .hourAndMinute)
                            .colorScheme(.dark)
                    }
                } header: {
                    Text("Priere du Vendredi")
                } footer: {
                    Text("Le vendredi, Dhuhr sera remplace par l'heure de la Jumu'ah de votre mosquee.")
                        .foregroundColor(.white.opacity(0.4))
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
                        Text(verbatim: result)
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
            
            // Sauvegarder l'heure Jumu'ah si active
            if self.jumuahEnabled {
                let jComps = Calendar.current.dateComponents([.hour, .minute], from: self.inputJumuah)
                self.jumuahHour = jComps.hour ?? 13
                self.jumuahMinute = jComps.minute ?? 0
            }

            self.lastSmartSetupDate = Date().timeIntervalSince1970
            
            // On force la vue Salat à se mettre à jour
            prayerVM.forceRecalculation()
            
            // Affichage du compte-rendu
            let ishaText = detectedIshaFixed
                ? "Fixe (\(detectedIshaDuration) min après Maghrib)"
                : "Astronomique (Décalage: \(detectedIshaOffset) min)"
            
            // 🚀 MISE À JOUR DE L'AFFICHAGE
            let jumuahText = self.jumuahEnabled
                ? "\n🕌 Jumu'ah : \(String(format: "%02d:%02d", self.jumuahHour, self.jumuahMinute)) (remplace Dhuhr le vendredi)"
                : ""

            self.analysisResult = """
            ✅ Analyse réussie !

            D'après les mathématiques, votre mosquée utilise :
            • Angle : \(bestMethodName)
            • Fajr : \(bestFajrOffset > 0 ? "+" : "")\(bestFajrOffset) min
            • Dhuhr : \(detectedDhuhrOffset > 0 ? "+" : "")\(detectedDhuhrOffset) min
            • Asr : \(detectedAsrOffset > 0 ? "+" : "")\(detectedAsrOffset) min
            • Maghrib : \(detectedMaghribOffset > 0 ? "+" : "")\(detectedMaghribOffset) min
            • Isha : \(ishaText)\(jumuahText)

            🕌 Délais Iqamah configurés :
            • Fajr +\(savedIqamahFajr) min  •  Dhuhr +\(savedIqamahDhuhr) min  •  Asr +\(savedIqamahAsr) min
            • Maghrib +\(savedIqamahMaghrib) min  •  Isha +\(savedIqamahIsha) min

            Ces réglages sont appliqués à l'application.
            """
            
            isAnalyzing = false
        }
    }
    
    // MARK: - 🎯 PRÉ-REMPLISSAGE
    // On utilise directement les horaires déjà calculés par le ViewModel
    // (méthode + offsets de l'utilisateur déjà appliqués) — pas de recalcul nécessaire.
    private func prefillForm() {
        guard !prayerVM.dailyPrayers.isEmpty else { return }
        for prayer in prayerVM.dailyPrayers {
            switch prayer.name {
            case "Fajr":    inputFajr    = prayer.date
            case "Dhuhr", "Jumu'ah": inputDhuhr = prayer.date
            case "Asr":     inputAsr     = prayer.date
            case "Maghrib": inputMaghrib = prayer.date
            case "Isha":    inputIsha    = prayer.date
            default: break
            }
        }
        // Pre-remplir l'heure Jumu'ah depuis les preferences
        if jumuahEnabled {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = jumuahHour; comps.minute = jumuahMinute
            inputJumuah = Calendar.current.date(from: comps) ?? inputJumuah
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
