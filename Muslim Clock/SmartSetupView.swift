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
    @AppStorage(StorageKeys.calculationMethod) private var savedMethod = "UOIF (12°)"
    @AppStorage(StorageKeys.fajrOffset) private var savedFajrOffset = 0
    @AppStorage(StorageKeys.maghribOffset) private var savedMaghribOffset = 0
    @AppStorage(StorageKeys.isIshaFixed) private var isIshaFixed = true
    @AppStorage(StorageKeys.ishaFixedDuration) private var savedIshaFixedDuration = 90
    @AppStorage(StorageKeys.ishaOffset) private var savedIshaOffset = 0
    @AppStorage("lastSmartSetupDate") private var lastSmartSetupDate: Double = 0
    @AppStorage(StorageKeys.dhuhrOffset) private var savedDhuhrOffset = 0
    @AppStorage(StorageKeys.asrOffset) private var savedAsrOffset = 0

    /// Mode voyage : l'analyse utilise la position courante, pas celle de la mosquée.
    @AppStorage(TravelKeys.active) private var travelModeActive = false
    
    // Mosquée & Iqamah
    @AppStorage("mosqueName") private var savedMosqueName = ""
    @AppStorage("iqamahFajrDelay") private var savedIqamahFajr = 20
    @AppStorage("iqamahDhuhrDelay") private var savedIqamahDhuhr = 15
    @AppStorage("iqamahAsrDelay") private var savedIqamahAsr = 15
    @AppStorage("iqamahMaghribDelay") private var savedIqamahMaghrib = 5
    @AppStorage("iqamahIshaDelay") private var savedIqamahIsha = 15

    // Jumu'ah
    @AppStorage(StorageKeys.jumuahEnabled) private var jumuahEnabled = false
    @AppStorage(StorageKeys.jumuahHour) private var jumuahHour = 13
    @AppStorage(StorageKeys.jumuahMinute) private var jumuahMinute = 0
    @State private var inputJumuah: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 13; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    /// Petit délai UX avant d'afficher le résultat (laisser voir que « ça travaille »).
    private static let analysisDelay: Duration = .seconds(1)

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
                            Text("Heure Jumu'ah personnalisée")
                                .foregroundColor(.white)
                        }
                    }
                    .tint(.green)

                    if jumuahEnabled {
                        DatePicker("Heure Jumu'ah", selection: $inputJumuah, displayedComponents: .hourAndMinute)
                            .colorScheme(.dark)
                    }
                } header: {
                    Text("Prière du Vendredi")
                } footer: {
                    Text("Le vendredi, Dhuhr sera remplacé par l'heure de la Jumu'ah de votre mosquée.")
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
            // Persistance immédiate de l'heure Jumu'ah : sans ça, le DatePicker
            // n'écrit que dans le @State local `inputJumuah` et la valeur n'est
            // sauvegardée QUE si l'utilisateur relance l'analyse magique — l'heure
            // restait donc figée à l'ancienne valeur (bug « bloqué à 12h45 »).
            .onChange(of: inputJumuah) { _, newValue in
                saveJumuahTimeIfChanged(from: newValue)
            }
            .onChange(of: jumuahEnabled) { _, isOn in
                if isOn { saveJumuahTimeIfChanged(from: inputJumuah) }
                prayerVM.forceRecalculation()
            }
        }
        .navigationTitle("Configuration Magique")
        .preferredColorScheme(.dark)
        // Feedback haptique : medium au tap (analyse lancée) + success quand le
        // résultat arrive (analyse terminée).
        .sensoryFeedback(.impact(weight: .medium), trigger: isAnalyzing)
        .sensoryFeedback(.success, trigger: analysisResult)
    }
    
    /// Persiste l'heure Jumu'ah choisie et déclenche le recalcul des horaires.
    /// Idempotent : ne fait rien si (heure, minute) n'ont pas changé — le
    /// pré-remplissage de `prefillForm()` ne déclenche donc pas de recalcul.
    private func saveJumuahTimeIfChanged(from date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let newHour = comps.hour ?? 13
        let newMinute = comps.minute ?? 0
        guard newHour != jumuahHour || newMinute != jumuahMinute else { return }
        jumuahHour = newHour
        jumuahMinute = newMinute
        prayerVM.forceRecalculation()
    }

    // MARK: - 🧠 LE CERVEAU MATHÉMATIQUE

    private func runAnalysis() {
        guard let location = prayerVM.lastLocation else {
            analysisResult = "⚠️ Erreur : Position GPS introuvable. Veuillez activer la localisation."
            return
        }
        
        isAnalyzing = true
        analysisResult = nil

        Task { @MainActor in
            try? await Task.sleep(for: Self.analysisDelay)
            analysisResult = performAnalysis(at: location)
            isAnalyzing = false
        }
    }

    /// Paramètres Adhan d'une méthode SANS offsets : exactement ceux que le moteur
    /// appliquera ensuite (`PrayerCalculationEngine.parameters`), pour que l'écart
    /// mesuré ici soit l'offset réellement nécessaire — aucune construction parallèle.
    private func zeroOffsetParameters(method: String) -> CalculationParameters {
        PrayerCalculationEngine.parameters(
            method: method,
            fajrOffset: 0, dhuhrOffset: 0, asrOffset: 0, maghribOffset: 0, ishaOffset: 0,
            isIshaFixed: false, ishaFixedDuration: 0
        )
    }

    /// Analyse les horaires saisis et applique les réglages déduits.
    /// - Returns: le compte-rendu affiché à l'utilisateur.
    private func performAnalysis(at location: CLLocation) -> String {
        let coords = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let today = Date()
        let dateComps = Calendar.current.dateComponents([.year, .month, .day], from: today)
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: today) ?? 1
        var warnings: [String] = []

        // 1️⃣ Dhuhr / Asr / Maghrib : indépendants de l'angle → méthode de référence.
        guard let baseTimes = PrayerTimes(
            coordinates: coords, date: dateComps,
            calculationParameters: zeroOffsetParameters(method: SmartSetupMath.referenceMethod)
        ) else {
            return "Erreur de calcul astronomique."
        }

        let dhuhr = SmartSetupMath.clamped(minutesBetween(calculated: baseTimes.dhuhr, user: inputDhuhr), to: SmartSetupMath.minorOffsetRange)
        let asr = SmartSetupMath.clamped(minutesBetween(calculated: baseTimes.asr, user: inputAsr), to: SmartSetupMath.minorOffsetRange)
        let maghrib = SmartSetupMath.clamped(minutesBetween(calculated: baseTimes.maghrib, user: inputMaghrib), to: SmartSetupMath.minorOffsetRange)
        if dhuhr.wasClamped { warnings.append(clampWarning("Dhuhr", raw: minutesBetween(calculated: baseTimes.dhuhr, user: inputDhuhr), kept: dhuhr.value)) }
        if asr.wasClamped {
            warnings.append(clampWarning("Asr", raw: minutesBetween(calculated: baseTimes.asr, user: inputAsr), kept: asr.value)
                + " Un grand écart sur Asr peut indiquer une mosquée de rite Hanafi.")
        }
        if maghrib.wasClamped { warnings.append(clampWarning("Maghrib", raw: minutesBetween(calculated: baseTimes.maghrib, user: inputMaghrib), kept: maghrib.value)) }

        // 2️⃣ Isha fixe : écart Maghrib → Isha saisi, arrondi au pas du stepper.
        let ishaDifference = minutesBetween(calculated: inputMaghrib, user: inputIsha)
        let detectedIshaFixed = SmartSetupMath.isFixedIsha(ishaDifference)
        let detectedIshaDuration = detectedIshaFixed ? SmartSetupMath.roundedIshaDuration(ishaDifference) : savedIshaFixedDuration

        // 3️⃣ Fajr : rétro-ingénierie de l'angle parmi les trois méthodes classiques.
        // Un angle non atteint ce jour-là (été, latitude élevée) est écarté : Adhan
        // lui substitue une règle de haute latitude, pas une vraie heure astronomique.
        var candidates: [(name: String, offset: Int, isReliable: Bool)] = []
        var ishaOffsetByMethod: [String: Int] = [:]
        var excludedMethods: [String] = []

        for (methodName, angle) in SmartSetupMath.candidateMethods {
            guard let testTimes = PrayerTimes(
                coordinates: coords, date: dateComps,
                calculationParameters: zeroOffsetParameters(method: methodName)
            ) else { continue }

            let reachable = SmartSetupMath.isTwilightAngleReachable(
                angle: angle, latitude: location.coordinate.latitude, dayOfYear: dayOfYear
            )
            if !reachable { excludedMethods.append(methodName) }

            candidates.append((
                name: methodName,
                offset: minutesBetween(calculated: testTimes.fajr, user: inputFajr),
                isReliable: reachable
            ))
            ishaOffsetByMethod[methodName] = minutesBetween(calculated: testTimes.isha, user: inputIsha)
        }

        guard !candidates.isEmpty else {
            return "Erreur de calcul astronomique."
        }

        let best = SmartSetupMath.bestAngle(SmartSetupMath.reliableCandidates(candidates))
        let fajr = SmartSetupMath.clamped(best.offset, to: SmartSetupMath.fajrOffsetRange)
        if fajr.wasClamped { warnings.append(clampWarning("Fajr", raw: best.offset, kept: fajr.value)) }

        var detectedIshaOffset = 0
        if !detectedIshaFixed {
            let raw = ishaOffsetByMethod[best.name] ?? 0
            let isha = SmartSetupMath.clamped(raw, to: SmartSetupMath.ishaOffsetRange)
            detectedIshaOffset = isha.value
            if isha.wasClamped { warnings.append(clampWarning("Isha", raw: raw, kept: isha.value)) }
        }

        if !excludedMethods.isEmpty {
            let list = excludedMethods.joined(separator: ", ")
            warnings.append("ℹ️ \(list) : angle non atteint à cette date et cette latitude, candidat écarté.")
        }
        if travelModeActive {
            warnings.append("⚠️ Mode voyage actif : l'analyse utilise votre position actuelle, pas celle de votre mosquée.")
        }

        // 4️⃣ Application des résultats.
        savedMethod = best.name
        savedFajrOffset = fajr.value
        savedDhuhrOffset = dhuhr.value
        savedAsrOffset = asr.value
        savedMaghribOffset = maghrib.value
        isIshaFixed = detectedIshaFixed
        savedIshaFixedDuration = detectedIshaDuration
        savedIshaOffset = detectedIshaOffset

        if jumuahEnabled {
            let jComps = Calendar.current.dateComponents([.hour, .minute], from: inputJumuah)
            jumuahHour = jComps.hour ?? 13
            jumuahMinute = jComps.minute ?? 0
        }

        lastSmartSetupDate = today.timeIntervalSince1970
        prayerVM.forceRecalculation()

        // 5️⃣ Compte-rendu.
        let ishaText = detectedIshaFixed
            ? "Fixe (\(detectedIshaDuration) min après Maghrib)"
            : "Astronomique (Décalage: \(signed(detectedIshaOffset)) min)"
        let jumuahText = jumuahEnabled
            ? "\n🕌 Jumu'ah : \(String(format: "%02d:%02d", jumuahHour, jumuahMinute)) (remplace Dhuhr le vendredi)"
            : ""
        let warningsText = warnings.isEmpty ? "" : "\n\n" + warnings.joined(separator: "\n")

        return """
        ✅ Analyse réussie !

        D'après les mathématiques, votre mosquée utilise :
        • Angle : \(best.name)
        • Fajr : \(signed(fajr.value)) min
        • Dhuhr : \(signed(dhuhr.value)) min
        • Asr : \(signed(asr.value)) min
        • Maghrib : \(signed(maghrib.value)) min
        • Isha : \(ishaText)\(jumuahText)

        🕌 Délais Iqamah configurés :
        • Fajr +\(savedIqamahFajr) min  •  Dhuhr +\(savedIqamahDhuhr) min  •  Asr +\(savedIqamahAsr) min
        • Maghrib +\(savedIqamahMaghrib) min  •  Isha +\(savedIqamahIsha) min

        Ces réglages sont appliqués à l'application. Vous pouvez changer la méthode (angles) à tout moment dans Réglages › Ajustements.\(warningsText)
        """
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func clampWarning(_ prayer: String, raw: Int, kept: Int) -> String {
        "⚠️ \(prayer) : écart de \(signed(raw)) min peu plausible, ramené à \(signed(kept)). Vérifiez l'heure saisie et votre position."
    }
    
    // MARK: - 🎯 PRÉ-REMPLISSAGE
    // On utilise directement les horaires déjà calculés par le ViewModel
    // (méthode + offsets de l'utilisateur déjà appliqués) — pas de recalcul nécessaire.
    private func prefillForm() {
        guard !prayerVM.dailyPrayers.isEmpty else { return }
        for prayer in prayerVM.dailyPrayers {
            switch prayer.name {
            case "Fajr":    inputFajr    = prayer.date
            case "Dhuhr":   inputDhuhr   = prayer.date
            case "Jumu'ah":
                // Vendredi : la ligne Dhuhr du ViewModel porte l'heure de la Jumu'ah.
                // L'analyse compare des horaires d'adhan Dhuhr : pré-remplir avec la
                // Jumu'ah appliquerait +45…+90 min à Dhuhr toute la semaine.
                inputDhuhr = prayerVM.dhuhrDate ?? prayer.date
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
    
    /// Adaptateur Date → (heure, minute) vers `SmartSetupMath.minutesBetween`
    /// (comparaison pure sur (h, m) avec repli minuit — testée unitairement).
    private func minutesBetween(calculated: Date, user: Date) -> Int {
        let calComps = Calendar.current.dateComponents([.hour, .minute], from: calculated)
        let userComps = Calendar.current.dateComponents([.hour, .minute], from: user)
        return SmartSetupMath.minutesBetween(
            calc: (calComps.hour ?? 0, calComps.minute ?? 0),
            user: (userComps.hour ?? 0, userComps.minute ?? 0)
        )
    }
}
