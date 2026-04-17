//
//  SettingsView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    // 💾 Sauvegarde persistante avec @AppStorage
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("userCalculationMethod") private var selectedCalculationMethod = "UOIF (12°)"
    @AppStorage("userMaghribOffset") private var maghribOffset = 0
    @AppStorage("userIshaOffset") private var ishaOffset = 0
    @AppStorage("userFajrOffset") private var fajrOffset = 0
    @AppStorage("userDhuhrOffset") private var dhuhrOffset = 0
    @AppStorage("userAsrOffset") private var asrOffset = 0
    
    // Réglages spécifiques Isha Fixe (très commun en Europe)
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var ishaFixedDuration = 90
    
    // 🕌 Infos Mosquée & Iqamah
    @AppStorage("mosqueName") private var mosqueName = ""
    @AppStorage("mosqueAddress") private var mosqueAddress = ""
    @AppStorage("iqamahFajrDelay") private var iqamahFajrDelay = 20
    @AppStorage("iqamahDhuhrDelay") private var iqamahDhuhrDelay = 15
    @AppStorage("iqamahAsrDelay") private var iqamahAsrDelay = 15
    @AppStorage("iqamahMaghribDelay") private var iqamahMaghribDelay = 5
    @AppStorage("iqamahIshaDelay") private var iqamahIshaDelay = 15

    // Jumu'ah (vendredi)
    @AppStorage("jumuahEnabled") private var jumuahEnabled = false
    @AppStorage("jumuahHour") private var jumuahHour = 13
    @AppStorage("jumuahMinute") private var jumuahMinute = 0

    // ✨ État pour l'alerte de review
    @State private var showReviewAlert = false
    @State private var reviewAlertMessage = ""
    
    let calculationMethods = ["UOIF (12°)", "Ligue Islamique (18°)", "ISNA (15°)", "Mosquée de Paris"]

    private var hasActiveAdjustments: Bool {
        fajrOffset != 0 || dhuhrOffset != 0 || asrOffset != 0 || maghribOffset != 0 || ishaOffset != 0 || isIshaFixed || selectedCalculationMethod != "UOIF (12°)"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fond "Liquid Glass"
                LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                List {
                    // ── SECTION 0 : LE SMART SETUP (Mise en avant) ──
                    Section {
                        NavigationLink(destination: SmartSetupView()) {
                            HStack(spacing: 15) {
                                Image(systemName: "wand.and.stars")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.orange.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Configuration Magique")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Laissez l'app déduire vos réglages")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                    
                    // ── SECTION LANGUE ──
                    Section {
                        Picker("Langue", selection: $appLanguage) {
                            Text("Automatique (système)").tag("system")
                            Text("Français").tag("fr")
                            Text("English").tag("en")
                            Text("العربية").tag("ar")
                        }
                        .tint(.orange)
                    } header: {
                        Text("Langue de l'application")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // ── SECTION 1 : AJUSTEMENTS MANUELS (TIROIR) ──
                    Section {
                        NavigationLink(destination: ManualAdjustmentsView()) {
                            HStack(spacing: 15) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.indigo.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ajustements Manuels")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Méthode de calcul & Temkine")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                // Badge si des offsets sont actifs
                                if hasActiveAdjustments {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.indigo)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                    
                    // ── SECTION 3 : MA MOSQUÉE & IQAMAH ──
                    Section {
                        NavigationLink(destination: MosqueSettingsView(
                            mosqueName: $mosqueName,
                            mosqueAddress: $mosqueAddress,
                            iqamahFajrDelay: $iqamahFajrDelay,
                            iqamahDhuhrDelay: $iqamahDhuhrDelay,
                            iqamahAsrDelay: $iqamahAsrDelay,
                            iqamahMaghribDelay: $iqamahMaghribDelay,
                            iqamahIshaDelay: $iqamahIshaDelay,
                            jumuahEnabled: $jumuahEnabled,
                            jumuahHour: $jumuahHour,
                            jumuahMinute: $jumuahMinute
                        )) {
                            HStack(spacing: 15) {
                                Image(systemName: "building.columns.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.teal.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mosqueName.isEmpty ? "Ma Mosquée" : mosqueName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Iqamah & informations")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                // Badge si configuré
                                if !mosqueName.isEmpty {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.teal)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Ma Mosquée")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                    
                    // ── SECTION CACHE AUDIO ──
                    AudioCacheSection()

                    // ── SECTION 4 : INFOS & SOURCES ──
                    Section {
//                        #if DEBUG
//                        // 🧪 BOUTON TEST ADHAN (temporaire pour debug)
//                        Button {
//                            // Déclenche l'overlay immédiatement
//                            NotificationCenter.default.post(
//                                name: NSNotification.Name("AdhanTriggered"),
//                                object: nil,
//                                userInfo: [
//                                    "prayerName": "Maghrib",
//                                    "prayerTime": Date()
//                                ]
//                            )
//                        } label: {
//                            Label("🧪 Tester l'overlay Adhan", systemImage: "testtube.2")
//                                .foregroundColor(.purple)
//                        }
//                        
//                        // 🕌 BOUTON TEST NOTIFICATION (dans 5 secondes)
//                        Button {
//                            let testDate = Date().addingTimeInterval(5)
//                            NotificationManager.shared.scheduleAdhan(for: "Test Asr", at: testDate)
//                        } label: {
//                            Label("🕌 Planifier Adhan test (5s)", systemImage: "bell.badge")
//                                .foregroundColor(.indigo)
//                        }
//                        
//                        Divider()
//                        #endif
                        
                        NavigationLink(destination: SourcesDetailView()) {
                            Label("Sources Authentiques", systemImage: "book.closed.fill")
                                .foregroundColor(.orange)
                        }
                        NavigationLink(destination: WidgetsDetailView()) {
                            Label("Fonctionnement des Widgets", systemImage: "square.grid.2x2.fill")
                                .foregroundColor(.blue)
                        }
                        
                        // ✨ NOUVEAU : BOUTON REVIEW
                        Button {
                            if remainingReviewCount() == 0 {
                                reviewAlertMessage = "Vous avez déjà utilisé vos 3 demandes d'avis pour cette année. Merci pour votre soutien ! 🙏"
                                showReviewAlert = true
                            } else {
                                reviewAlertMessage = "Nous aimerions connaître votre avis sur Muslim Clock. Cela ne prend qu'une minute et nous aide énormément ! 🌙"
                                showReviewAlert = true
                            }
                        } label: {
                            HStack {
                                Label("Donner mon avis sur l'app", systemImage: "star.fill")
                                    .foregroundColor(.yellow)
                                
                                Spacer()
                                
                                // Badge du nombre de reviews restantes
                                let remainingReviews = remainingReviewCount()
                                if remainingReviews > 0 {
                                    Text(verbatim: "\(remainingReviews)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.yellow.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    } header: {
                        Text("Transparence & à propos")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    #if DEBUG
                    DebugPanelSection()
                    #endif
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.white.opacity(0.05))
                // 2. 🚀 ON FORCE LE RECALCUL DÈS QU'UN RÉGLAGE CHANGE
                .onChange(of: selectedCalculationMethod) { prayerVM.forceRecalculation() }
                .onChange(of: maghribOffset) { prayerVM.forceRecalculation() }
                .onChange(of: isIshaFixed) { prayerVM.forceRecalculation() }
                .onChange(of: ishaFixedDuration) { prayerVM.forceRecalculation() }
                .onChange(of: ishaOffset) { prayerVM.forceRecalculation() }
                .onChange(of: fajrOffset) { prayerVM.forceRecalculation() }
                .onChange(of: dhuhrOffset) { prayerVM.forceRecalculation() }
                .onChange(of: asrOffset) { prayerVM.forceRecalculation() }
                .onChange(of: jumuahEnabled) { prayerVM.forceRecalculation() }
                .onChange(of: jumuahHour) { prayerVM.forceRecalculation() }
                .onChange(of: jumuahMinute) { prayerVM.forceRecalculation() }

            }
            .navigationTitle("Réglages")
            .preferredColorScheme(.dark)
            // ✨ ALERTE DE REVIEW
            .alert("Donner votre avis", isPresented: $showReviewAlert) {
                if remainingReviewCount() > 0 {
                    Button("Oui, donner mon avis") {
                        let success = forceRequestReview()
                        if !success {
                            // Si la demande échoue, afficher un message
                            reviewAlertMessage = "Une erreur s'est produite. Veuillez réessayer plus tard."
                            showReviewAlert = true
                        }
                    }
                    Button("Plus tard", role: .cancel) { }
                } else {
                    Button("OK", role: .cancel) { }
                }
            } message: {
                Text(reviewAlertMessage)
            }
        }
    }
}

// MARK: - VUE MOSQUÉE & IQAMAH
struct MosqueSettingsView: View {
    @Binding var mosqueName: String
    @Binding var mosqueAddress: String
    @Binding var iqamahFajrDelay: Int
    @Binding var iqamahDhuhrDelay: Int
    @Binding var iqamahAsrDelay: Int
    @Binding var iqamahMaghribDelay: Int
    @Binding var iqamahIshaDelay: Int
    @Binding var jumuahEnabled: Bool
    @Binding var jumuahHour: Int
    @Binding var jumuahMinute: Int

    // Heure Jumu'ah construite a partir de hour/minute pour le DatePicker
    private var jumuahDate: Binding<Date> {
        Binding<Date>(
            get: {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = jumuahHour
                comps.minute = jumuahMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                jumuahHour = comps.hour ?? 13
                jumuahMinute = comps.minute ?? 0
            }
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            List {
                // ── INFOS MOSQUÉE ──
                Section {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.teal)
                            .frame(width: 24)
                        TextField("Nom de la mosquée", text: $mosqueName)
                            .foregroundColor(.white)
                    }
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.teal)
                            .frame(width: 24)
                        TextField("Adresse (optionnel)", text: $mosqueAddress)
                            .foregroundColor(.white)
                    }
                } header: {
                    Text("Informations")
                        .foregroundColor(.white.opacity(0.6))
                } footer: {
                    Text("Ces informations sont uniquement affichées sur votre appareil.")
                        .foregroundColor(.white.opacity(0.4))
                }
                .listRowBackground(Color.white.opacity(0.1))

                // ── DÉLAIS IQAMAH ──
                Section {
                    IqamahRow(prayerName: "Fajr", icon: "sun.and.horizon.fill", delay: $iqamahFajrDelay)
                    IqamahRow(prayerName: "Dhuhr", icon: "sun.max.fill", delay: $iqamahDhuhrDelay)
                    IqamahRow(prayerName: "Asr", icon: "sun.dust.fill", delay: $iqamahAsrDelay)
                    IqamahRow(prayerName: "Maghrib", icon: "sunset.fill", delay: $iqamahMaghribDelay)
                    IqamahRow(prayerName: "Isha", icon: "moon.stars.fill", delay: $iqamahIshaDelay)
                } header: {
                    Text("Délai Adhan → Iqamah")
                        .foregroundColor(.white.opacity(0.6))
                } footer: {
                    Text("Durée entre l'adhan et l'iqamah dans votre mosquée. Utilisé pour l'analyse de votre planning de prière.")
                        .foregroundColor(.white.opacity(0.4))
                }
                .listRowBackground(Color.white.opacity(0.1))

                // ── JUMU'AH (VENDREDI) ──
                Section {
                    Toggle(isOn: $jumuahEnabled.animation()) {
                        HStack(spacing: 10) {
                            Image(systemName: "building.columns.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Heure Jumu'ah")
                                    .foregroundColor(.white)
                                Text("Remplace Dhuhr le vendredi")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .tint(.green)

                    if jumuahEnabled {
                        DatePicker(
                            "Heure du Khoutba",
                            selection: jumuahDate,
                            displayedComponents: .hourAndMinute
                        )
                        .colorScheme(.dark)
                        .foregroundColor(.white)
                    }
                } header: {
                    Text("Priere du Vendredi")
                        .foregroundColor(.white.opacity(0.6))
                } footer: {
                    if jumuahEnabled {
                        Text("Le vendredi, l'horaire Dhuhr sera remplace par l'heure de la Jumu'ah de votre mosquee.")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .listRowBackground(Color.white.opacity(0.1))
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.white.opacity(0.05))
        }
        .navigationTitle("Ma Mosquée")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

// MARK: - VUE AJUSTEMENTS MANUELS (TEMKINE)
struct ManualAdjustmentsView: View {
    @AppStorage("userCalculationMethod") private var selectedCalculationMethod = "UOIF (12°)"
    @AppStorage("userFajrOffset") private var fajrOffset = 0
    @AppStorage("userDhuhrOffset") private var dhuhrOffset = 0
    @AppStorage("userAsrOffset") private var asrOffset = 0
    @AppStorage("userMaghribOffset") private var maghribOffset = 0
    @AppStorage("userIshaOffset") private var ishaOffset = 0
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var ishaFixedDuration = 90

    let calculationMethods = ["UOIF (12°)", "Ligue Islamique (18°)", "ISNA (15°)", "Mosquée de Paris"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            List {
                // ── MÉTHODE DE CALCUL ──
                Section {
                    Picker(selection: $selectedCalculationMethod) {
                        ForEach(calculationMethods, id: \.self) { method in
                            Text(verbatim: method).tag(method)
                        }
                    } label: {
                        Text("Méthode (Angles)")
                    }
                    .tint(.orange)
                } header: {
                    Text("Méthode de calcul")
                        .foregroundColor(.white.opacity(0.6))
                }
                .listRowBackground(Color.white.opacity(0.1))

                // ── OFFSETS TEMKINE ──
                Section {
                    OffsetRow(label: "Fajr", offset: $fajrOffset, range: -30...30, color: .orange)
                    OffsetRow(label: "Dhuhr", offset: $dhuhrOffset, range: -15...15, color: .orange)
                    OffsetRow(label: "Asr", offset: $asrOffset, range: -15...15, color: .orange)
                    OffsetRow(label: "Maghrib", offset: $maghribOffset, range: -15...15, color: .orange)

                    // Isha fixe toggle
                    Toggle(isOn: $isIshaFixed.animation()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Isha fixe après Maghrib")
                            Text("Pratique courante en Europe")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .tint(.indigo)

                    if isIshaFixed {
                        HStack {
                            Text("Durée")
                                .foregroundColor(.indigo)
                            Spacer()
                            Stepper(value: $ishaFixedDuration, in: 60...120, step: 5) { EmptyView() }.labelsHidden()
                            Text(verbatim: "\(ishaFixedDuration) min")
                                .fontWeight(.bold)
                                .foregroundColor(.indigo)
                                .frame(width: 60, alignment: .trailing)
                        }
                    } else {
                        OffsetRow(label: "Isha", offset: $ishaOffset, range: -15...30, color: .teal)
                    }
                } header: {
                    Text("Ajustement Manuel (Temkine)")
                        .foregroundColor(.white.opacity(0.6))
                } footer: {
                    Text("Ajustez chaque prière individuellement si les horaires calculés ne correspondent pas à votre mosquée. Glissez vers la gauche pour remettre à zéro.")
                        .foregroundColor(.white.opacity(0.4))
                }
                .listRowBackground(Color.white.opacity(0.1))
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.white.opacity(0.05))
        }
        .navigationTitle("Ajustements")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Row réutilisable pour les offsets
private struct OffsetRow: View {
    let label: String
    @Binding var offset: Int
    let range: ClosedRange<Int>
    let color: Color

    var body: some View {
        HStack {
            Text("Ajustement \(label)")
            Spacer()
            Stepper(value: $offset, in: range) { EmptyView() }.labelsHidden()
            Text(verbatim: "\(offset > 0 ? "+" : "")\(offset) min")
                .fontWeight(.bold)
                .foregroundColor(offset != 0 ? color : .white)
                .frame(width: 60, alignment: .trailing)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { offset = 0 }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .tint(color)
        }
    }
}

struct IqamahRow: View {
    let prayerName: String
    let icon: String
    @Binding var delay: Int
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.teal)
                .frame(width: 24)
            Text(prayerName)
            Spacer()
            Stepper(value: $delay, in: 0...60, step: 5) { EmptyView() }
                .labelsHidden()
            Text(verbatim: "\(delay) min")
                .fontWeight(.bold)
                .foregroundColor(delay > 0 ? .teal : .white.opacity(0.5))
                .frame(width: 60, alignment: .trailing)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { delay = 0 }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .tint(.teal)
        }
    }
}

// MARK: - CACHE AUDIO
struct AudioCacheSection: View {
    @State private var cacheSize: String = "..."
    @State private var fileCount: Int = 0
    @State private var showClearAlert = false

    var body: some View {
        Section {
            HStack {
                Label("Fichiers caches", systemImage: "arrow.down.circle.fill")
                    .foregroundColor(.purple)
                Spacer()
                Text(verbatim: "\(fileCount) fichiers")
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack {
                Label("Espace utilise", systemImage: "internaldrive.fill")
                    .foregroundColor(.purple)
                Spacer()
                Text(verbatim: cacheSize)
                    .foregroundColor(.white.opacity(0.6))
            }

            Button(role: .destructive) {
                showClearAlert = true
            } label: {
                Label("Vider le cache audio", systemImage: "trash")
                    .foregroundColor(.red)
            }
        } header: {
            Text("Cache Audio (hors-ligne)")
                .foregroundColor(.white.opacity(0.6))
        } footer: {
            Text("Les audios ecoutes sont sauvegardes pour une lecture instantanee et hors-ligne.")
                .foregroundColor(.white.opacity(0.4))
        }
        .listRowBackground(Color.white.opacity(0.1))
        .onAppear { refreshStats() }
        .alert("Vider le cache ?", isPresented: $showClearAlert) {
            Button("Supprimer", role: .destructive) {
                AudioCacheManager.shared.clearCache()
                refreshStats()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Tous les fichiers audio caches seront supprimes. Ils seront re-telecharges a la prochaine ecoute.")
        }
    }

    private func refreshStats() {
        cacheSize = AudioCacheManager.shared.cacheSizeFormatted()
        fileCount = AudioCacheManager.shared.cachedFileCount()
    }
}

// MARK: - DEBUG PANEL
#if DEBUG
private struct DebugPanelSection: View {
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @State private var adhanScheduled = false
    @State private var newMoonScheduled = false

    // Override de saison islamique
    @AppStorage("debugSeasonDate") private var debugSeasonTimestamp: Double = 0

    private struct SeasonScenario: Identifiable {
        let id: Int
        let label: String
        let hijriMonth: Int
        let hijriDay: Int
    }

    private let scenarios: [SeasonScenario] = [
        SeasonScenario(id: 0,  label: "— Aucun (date réelle) —",        hijriMonth: 0,  hijriDay: 0),
        SeasonScenario(id: 1,  label: "1 · Muharram",                    hijriMonth: 1,  hijriDay: 5),
        SeasonScenario(id: 2,  label: "7 · Rajab",                       hijriMonth: 7,  hijriDay: 5),
        SeasonScenario(id: 3,  label: "8 · Sha'ban",                     hijriMonth: 8,  hijriDay: 5),
        SeasonScenario(id: 4,  label: "9 · Ramadan",                     hijriMonth: 9,  hijriDay: 5),
        SeasonScenario(id: 5,  label: "10 · Aïd al-Fitr (1 Shawwal)",   hijriMonth: 10, hijriDay: 1),
        SeasonScenario(id: 6,  label: "11 · Dhu al-Qi'dah",             hijriMonth: 11, hijriDay: 5),
        SeasonScenario(id: 7,  label: "12 · Dhul Hijjah — 10 j. bénis", hijriMonth: 12, hijriDay: 5),
        SeasonScenario(id: 8,  label: "12 · Dhul Hijjah — Aïd al-Adha", hijriMonth: 12, hijriDay: 10),
        SeasonScenario(id: 9,  label: "12 · Dhul Hijjah — reste",        hijriMonth: 12, hijriDay: 20),
    ]

    private var selectedScenarioID: Int {
        if debugSeasonTimestamp == 0 { return 0 }
        return scenarios.first { s in
            guard s.hijriMonth > 0 else { return false }
            var dc = DateComponents()
            dc.year = 1447; dc.month = s.hijriMonth; dc.day = s.hijriDay
            guard let d = Calendar(identifier: .islamicUmmAlQura).date(from: dc) else { return false }
            return abs(d.timeIntervalSince1970 - debugSeasonTimestamp) < 1
        }?.id ?? 0
    }

    private func applyScenario(_ s: SeasonScenario) {
        if s.hijriMonth == 0 {
            debugSeasonTimestamp = 0
            return
        }
        var dc = DateComponents()
        dc.year = 1447; dc.month = s.hijriMonth; dc.day = s.hijriDay
        debugSeasonTimestamp = Calendar(identifier: .islamicUmmAlQura)
            .date(from: dc)?.timeIntervalSince1970 ?? 0
    }

    // Calendrier hégirien pour l'état instantané
    private var hijriDay: Int {
        Calendar(identifier: .islamicUmmAlQura).component(.day, from: .now)
    }
    private var adhkarPeriod: String {
        guard let fajr = prayerVM.fajrDate, let asr = prayerVM.asrDate else {
            let h = Calendar.current.component(.hour, from: .now)
            return (h >= 4 && h < 15) ? "🌅 Matin (fallback heure)" : "🌙 Soir (fallback heure)"
        }
        let now = Date()
        return (now >= fajr && now < asr) ? "🌅 Matin (Fajr→Asr)" : "🌙 Soir (Asr→Fajr)"
    }

    var body: some View {
        Section {
            // ── SAISON ISLAMIQUE ──
            Picker("Saison islamique", selection: Binding(
                get: { selectedScenarioID },
                set: { id in
                    if let s = scenarios.first(where: { $0.id == id }) { applyScenario(s) }
                }
            )) {
                ForEach(scenarios) { s in
                    Text(s.label).tag(s.id)
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(debugSeasonTimestamp > 0 ? .orange : .white.opacity(0.6))

            if debugSeasonTimestamp > 0 {
                let overrideDate = Date(timeIntervalSince1970: debugSeasonTimestamp)
                LabeledContent("Override actif",
                    value: overrideDate.formatted(.dateTime.day().month().year()))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.orange)
            }

            // ── ÉTAT COURANT ──
            Group {
                LabeledContent("Jour hégirien", value: "\(hijriDay) — carte hilal: \(hijriDay == 1 ? "✅" : "❌")")
                LabeledContent("Période adhkar", value: adhkarPeriod)
                if let fajr = prayerVM.fajrDate {
                    LabeledContent("Fajr réel", value: fajr.formatted(date: .omitted, time: .shortened))
                }
                if let asr = prayerVM.asrDate {
                    LabeledContent("Asr réel", value: asr.formatted(date: .omitted, time: .shortened))
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7))

            // ── ACTIONS ──
            // Test Adhan overlay (notification dans 5s)
            Button {
                let t = Date().addingTimeInterval(5)
                NotificationManager.shared.scheduleAdhan(for: "Asr", at: t)
                adhanScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { adhanScheduled = false }
            } label: {
                Label(
                    adhanScheduled ? "Adhan planifié dans 5s ✅" : "Tester overlay Adhan (5s)",
                    systemImage: "bell.badge.fill"
                )
                .foregroundStyle(adhanScheduled ? .green : .orange)
            }

            // Test notification nouvelle lune (dans 10s)
            Button {
                let center = UNUserNotificationCenter.current()
                let content = UNMutableNotificationContent()
                content.title = "🌙 Nouvelle Lune — Hilal"
                content.body  = "اللَّهُمَّ أَهِلَّهُ عَلَيْنَا بِالأَمْنِ وَالإِيمَانِ وَالسَّلَامَةِ وَالإِسْلَامِ"
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                center.add(UNNotificationRequest(identifier: "debug_newmoon", content: content, trigger: trigger))
                newMoonScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { newMoonScheduled = false }
            } label: {
                Label(
                    newMoonScheduled ? "Notif Hilal dans 10s ✅" : "Tester notif nouvelle lune (10s)",
                    systemImage: "moon.fill"
                )
                .foregroundStyle(newMoonScheduled ? .green : .yellow)
            }

            // Forcer recalcul des prières
            Button {
                prayerVM.forceRecalculation()
            } label: {
                Label("Forcer recalcul prières", systemImage: "arrow.clockwise")
                    .foregroundStyle(.teal)
            }

            // Reset compteurs adhkar
            Button(role: .destructive) {
                let keys = UserDefaults.standard.dictionaryRepresentation().keys
                    .filter { $0.hasPrefix("adhkar_") }
                keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
            } label: {
                Label("Reset compteurs adhkar", systemImage: "trash")
            }

        } header: {
            Text("🛠 DEBUG")
                .foregroundStyle(.red.opacity(0.8))
        } footer: {
            Text("Section visible uniquement en Debug. Disparaît en Release.")
                .foregroundStyle(.red.opacity(0.4))
        }
        .listRowBackground(Color.red.opacity(0.06))
    }
}
#endif

// MARK: - SOUS-PAGES
struct SourcesDetailView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "book.closed.fill").font(.system(size: 60)).foregroundColor(.orange).padding(.top, 40)
                    Text("Méthodologie").font(.title2.bold()).foregroundColor(.white)
                    Text("Tous les contenus spirituels de cette application (Hadiths, Invocations) sont rigoureusement sélectionnés. Nous nous basons sur les recueils authentiques (Sahih Al-Bukhari, Sahih Muslim) et les travaux d'authentification des grands savants de la Sounnah (comme Sheikh Al-Albani, rahimahullah).")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                }
                .padding()
            }
        }
        .navigationTitle("Sources").navigationBarTitleDisplayMode(.inline)
    }
}

struct WidgetsDetailView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.15, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 60)).foregroundColor(.blue).padding(.top, 40)
                    Text("Comment ajouter un Widget ?").font(.title2.bold()).foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("1. Maintenez votre doigt enfoncé sur un espace vide de votre écran d'accueil iPhone.")
                        Text("2. Touchez le bouton '+' en haut à gauche.")
                        Text("3. Cherchez 'Muslim Clock' dans la liste.")
                        Text("4. Choisissez la taille du widget (Prochaine prière, 5 sphères qui représentent les 5 prières, etc.) et appuyez sur 'Ajouter'.")
                    }
                    .foregroundColor(.white.opacity(0.8)).padding().background(.ultraThinMaterial).cornerRadius(15)
                }
                .padding()
            }
        }
        .navigationTitle("Widgets").navigationBarTitleDisplayMode(.inline)
    }
}
