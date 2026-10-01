import SwiftUI
import CoreLocation

struct SmartSetupView: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    
    // Horaires saisis (adhan de la mosquée)
    @State private var inputFajr: Date = .now
    @State private var inputDhuhr: Date = .now
    @State private var inputAsr: Date = .now
    @State private var inputMaghrib: Date = .now
    @State private var inputIsha: Date = .now
    /// Observation persistée (dernière analyse), source des pré-remplissages.
    @State private var storedObservation: MosqueObservation? = nil
    
    @State private var isAnalyzing = false
    @State private var errorMessage: String? = nil
    /// Résultat de la dernière analyse de la session + méthode choisie/affichée.
    @State private var proposal: SmartSetupProposal? = nil
    @State private var selectedMethod: String = PrayerCalculationEngine.defaultMethod
    
    // Accès aux AppStorage – Calcul
    @AppStorage(StorageKeys.calculationMethod) private var savedMethod = PrayerCalculationEngine.defaultMethod
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
                Section {
                    DatePicker("Fajr", selection: $inputFajr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Dhuhr", selection: $inputDhuhr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Asr", selection: $inputAsr, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Maghrib", selection: $inputMaghrib, displayedComponents: .hourAndMinute).colorScheme(.dark)
                    DatePicker("Isha", selection: $inputIsha, displayedComponents: .hourAndMinute).colorScheme(.dark)
                } header: {
                    Text("Horaires Adhan")
                } footer: {
                    if let stored = storedObservation {
                        Text("Pré-rempli avec votre dernière analyse du \(stored.date.formatted(date: .abbreviated, time: .omitted)). Mettez à jour avec les horaires du jour avant de relancer.")
                            .foregroundColor(.white.opacity(0.4))
                    }
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

                if let errorMessage {
                    Section {
                        Text(verbatim: errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .listRowBackground(Color.red.opacity(0.25))
                    }
                }
                
                if let proposal {
                    methodSection(proposal)
                    appliedSection(proposal)
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
        .sensoryFeedback(.success, trigger: proposal?.observation.date)
        .sensoryFeedback(.selection, trigger: selectedMethod)
    }

    // MARK: - Résultat : choix de la méthode

    /// Les trois méthodes classiques, scorées. La recommandée est présélectionnée ;
    /// l'utilisateur peut en choisir une autre, les décalages Fajr/Isha suivent.
    private func methodSection(_ proposal: SmartSetupProposal) -> some View {
        Section {
            ForEach(proposal.candidates) { candidate in
                Button {
                    select(candidate.name, in: proposal)
                } label: {
                    methodRow(candidate, isRecommended: candidate.name == proposal.recommendedMethod)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Méthode (angles) — touchez pour changer")
        } footer: {
            Text("La méthode recommandée est présélectionnée. En cas de doute, choisissez-en une autre : les décalages Fajr et Isha sont recalculés automatiquement à partir de vos horaires.")
                .foregroundColor(.white.opacity(0.4))
        }
        .listRowBackground(Color.white.opacity(0.08))
    }

    private func methodRow(_ candidate: MethodCandidate, isRecommended: Bool) -> some View {
        let isSelected = candidate.name == selectedMethod
        return HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .orange : .white.opacity(0.35))
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: candidate.name)
                    .font(.body.weight(isSelected ? .bold : .regular))
                    .foregroundColor(.white)
                Text(verbatim: "Fajr \(SmartSetupAnalyzer.signed(candidate.fajrOffset)) min · Isha \(SmartSetupAnalyzer.signed(candidate.ishaOffset)) min")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            if isRecommended {
                badge(String(localized: "Recommandé"), color: .orange)
            }
            if !candidate.isReachable {
                badge(String(localized: "Non atteint"), color: .gray)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    // MARK: - Résultat : réglages appliqués

    private func appliedSection(_ proposal: SmartSetupProposal) -> some View {
        let settings = proposal.settings(for: selectedMethod)
        let warnings = proposal.warnings + settings.warnings
            + (travelModeActive ? [String(localized: "⚠️ Mode voyage actif : l'analyse utilise votre position actuelle, pas celle de votre mosquée.")] : [])

        return Section {
            offsetRow("Fajr", settings.fajrOffset)
            offsetRow("Dhuhr", settings.dhuhrOffset)
            offsetRow("Asr", settings.asrOffset)
            offsetRow("Maghrib", settings.maghribOffset)
            HStack {
                Text("Isha")
                Spacer()
                switch settings.ishaMode {
                case .fixed(let duration):
                    Text("Fixe · Maghrib + \(duration) min").foregroundColor(.indigo)
                case .astronomical(let offset):
                    Text("Astronomique · \(SmartSetupAnalyzer.signed(offset)) min").foregroundColor(.teal)
                }
            }
            .font(.subheadline)
            .monospacedDigit()

            if jumuahEnabled {
                HStack {
                    Text("Jumu'ah")
                    Spacer()
                    Text(verbatim: String(format: "%02d:%02d", jumuahHour, jumuahMinute))
                        .foregroundColor(.green)
                }
                .font(.subheadline)
            }

            HStack {
                Text("Iqamah")
                Spacer()
                Text(verbatim: "+\(savedIqamahFajr) · +\(savedIqamahDhuhr) · +\(savedIqamahAsr) · +\(savedIqamahMaghrib) · +\(savedIqamahIsha) min")
                    .foregroundColor(.white.opacity(0.7))
            }
            .font(.subheadline)
            .monospacedDigit()

            ForEach(warnings, id: \.self) { warning in
                Text(verbatim: warning)
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.9))
            }
        } header: {
            Text("Réglages appliqués")
        } footer: {
            Text("Analyse du \(proposal.observation.date.formatted(date: .abbreviated, time: .shortened)). Ces réglages sont appliqués à l'application ; vous pouvez aussi changer la méthode dans Réglages › Ajustements.")
                .foregroundColor(.white.opacity(0.4))
        }
        .listRowBackground(Color.green.opacity(0.15))
    }

    private func offsetRow(_ label: String, _ offset: Int) -> some View {
        HStack {
            Text(verbatim: label)
            Spacer()
            Text(verbatim: "\(SmartSetupAnalyzer.signed(offset)) min")
                .foregroundColor(offset == 0 ? .white.opacity(0.7) : .orange)
        }
        .font(.subheadline)
        .monospacedDigit()
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

    // MARK: - 🧠 Analyse

    private func runAnalysis() {
        guard let location = prayerVM.lastLocation else {
            errorMessage = String(localized: "⚠️ Erreur : Position GPS introuvable. Veuillez activer la localisation.")
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        proposal = nil

        let observation = MosqueObservation(
            date: Date(),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            fajr: inputFajr, dhuhr: inputDhuhr, asr: inputAsr, maghrib: inputMaghrib, isha: inputIsha
        )

        Task { @MainActor in
            try? await Task.sleep(for: Self.analysisDelay)
            defer { isAnalyzing = false }

            guard let result = SmartSetupAnalyzer.analyze(observation) else {
                errorMessage = String(localized: "Erreur de calcul astronomique.")
                return
            }

            // L'observation est la donnée de référence : persistée telle quelle,
            // tout le reste en est dérivé (y compris plus tard dans Ajustements).
            observation.save()
            storedObservation = observation

            if jumuahEnabled {
                let jComps = Calendar.current.dateComponents([.hour, .minute], from: inputJumuah)
                jumuahHour = jComps.hour ?? 13
                jumuahMinute = jComps.minute ?? 0
            }

            proposal = result
            select(result.recommendedMethod, in: result)
            lastSmartSetupDate = observation.date.timeIntervalSince1970
        }
    }

    /// Choisit une méthode (recommandée ou forcée par l'utilisateur) et applique
    /// les réglages dérivés pour cette méthode.
    private func select(_ method: String, in proposal: SmartSetupProposal) {
        selectedMethod = method
        apply(proposal.settings(for: method))
    }

    private func apply(_ settings: AppliedSettings) {
        savedMethod = settings.method
        savedFajrOffset = settings.fajrOffset
        savedDhuhrOffset = settings.dhuhrOffset
        savedAsrOffset = settings.asrOffset
        savedMaghribOffset = settings.maghribOffset
        switch settings.ishaMode {
        case .fixed(let duration):
            isIshaFixed = true
            savedIshaFixedDuration = duration
        case .astronomical(let offset):
            isIshaFixed = false
            savedIshaOffset = offset
        }
        prayerVM.forceRecalculation()
    }
    
    // MARK: - 🎯 Pré-remplissage

    /// Priorité à la dernière observation (les vrais horaires de la mosquée) ;
    /// sinon les horaires calculés par le ViewModel (méthode + offsets actuels).
    private func prefillForm() {
        selectedMethod = PrayerCalculationEngine.normalizedMethod(savedMethod)

        if let stored = MosqueObservation.load() {
            storedObservation = stored
            inputFajr = stored.fajr
            inputDhuhr = stored.dhuhr
            inputAsr = stored.asr
            inputMaghrib = stored.maghrib
            inputIsha = stored.isha
        } else if !prayerVM.dailyPrayers.isEmpty {
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
        }

        // Pré-remplir l'heure Jumu'ah depuis les préférences
        if jumuahEnabled {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = jumuahHour; comps.minute = jumuahMinute
            inputJumuah = Calendar.current.date(from: comps) ?? inputJumuah
        }
    }
}
