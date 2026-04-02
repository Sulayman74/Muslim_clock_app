//
//  SettingsView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//

import SwiftUI

struct SettingsView: View {
    // 💾 Sauvegarde persistante avec @AppStorage
    @EnvironmentObject var prayerVM: PrayerTimesViewModel
    @AppStorage("userCalculationMethod") private var selectedCalculationMethod = "UOIF (12°)"
    @AppStorage("userMaghribOffset") private var maghribOffset = 0
    @AppStorage("userIshaOffset") private var ishaOffset = 0
    @AppStorage("userFajrOffset") private var fajrOffset = 0
    @AppStorage("userDhuhrOffset") private var dhuhrOffset = 0
    @AppStorage("userAsrOffset") private var asrOffset = 0
    
    // Réglages spécifiques Isha Fixe (très commun en Europe)
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var ishaFixedDuration = 90
    
    let calculationMethods = ["UOIF (12°)", "Ligue Islamique (18°)", "ISNA (15°)", "Mosquée de Paris"]
    
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
                    
                    // ── SECTION 1 : MÉTHODES DE CALCUL ──
                    Section {
                        Picker("Méthode (Angles)", selection: $selectedCalculationMethod) {
                            ForEach(calculationMethods, id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .tint(.orange)
                    } header: {
                        Text("Horaires & Précision")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // ── SECTION 2 : AJUSTEMENTS (TEMKINE) & LISSAGE ──
                    Section {
                        
                        HStack {
                            Text("Ajustement Fajr")
                            Spacer()
                            Stepper(value: $fajrOffset, in: -30...30) { EmptyView() }.labelsHidden()
                            Text("\(fajrOffset > 0 ? "+" : "")\(fajrOffset) min")
                                .fontWeight(.bold)
                                .foregroundColor(fajrOffset != 0 ? .orange : .white)
                                .frame(width: 60, alignment: .trailing)
                                                }
                                .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { withAnimation { fajrOffset = 0 } } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.tint(.orange)
                                }
                        
                        HStack {
                                                    Text("Ajustement Dhuhr")
                                                    Spacer()
                                                    Stepper(value: $dhuhrOffset, in: -15...15) { EmptyView() }.labelsHidden()
                                                    Text("\(dhuhrOffset > 0 ? "+" : "")\(dhuhrOffset) min")
                                                        .fontWeight(.bold)
                                                        .foregroundColor(dhuhrOffset != 0 ? .orange : .white)
                                                        .frame(width: 60, alignment: .trailing)
                                                }
                                                .swipeActions(edge: .trailing) { Button(role: .destructive) { withAnimation { dhuhrOffset = 0 } } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.tint(.orange) }
                                                
                                                HStack {
                                                    Text("Ajustement Asr")
                                                    Spacer()
                                                    Stepper(value: $asrOffset, in: -15...15) { EmptyView() }.labelsHidden()
                                                    Text("\(asrOffset > 0 ? "+" : "")\(asrOffset) min")
                                                        .fontWeight(.bold)
                                                        .foregroundColor(asrOffset != 0 ? .orange : .white)
                                                        .frame(width: 60, alignment: .trailing)
                                                }
                                                .swipeActions(edge: .trailing) { Button(role: .destructive) { withAnimation { asrOffset = 0 } } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.tint(.orange) }
                        
                        // 1. Ajustement Maghrib
                        HStack {
                            Text("Ajustement Maghrib")
                            Spacer()
                            Stepper(value: $maghribOffset, in: -15...15) { EmptyView() }.labelsHidden()
                            Text("\(maghribOffset > 0 ? "+" : "")\(maghribOffset) min")
                                .fontWeight(.bold)
                                .foregroundColor(maghribOffset != 0 ? .orange : .white)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { withAnimation { maghribOffset = 0 } } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.tint(.orange)
                        }
                        
                        // 2. Le Toggle de l'Isha Fixe
                        Toggle(isOn: $isIshaFixed.animation()) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Isha fixe après Maghrib")
                                Text("Pratique courante en Europe")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .tint(.indigo)
                        
                        // 3. Choix dynamique
                        if isIshaFixed {
                            HStack {
                                Text("Durée")
                                    .foregroundColor(.indigo)
                                Spacer()
                                Stepper(value: $ishaFixedDuration, in: 60...120, step: 5) { EmptyView() }.labelsHidden()
                                Text("\(ishaFixedDuration) min")
                                    .fontWeight(.bold)
                                    .foregroundColor(.indigo)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        } else {
                            HStack {
                                Text("Ajustement Isha")
                                Spacer()
                                Stepper(value: $ishaOffset, in: -15...30) { EmptyView() }.labelsHidden()
                                Text("\(ishaOffset > 0 ? "+" : "")\(ishaOffset) min")
                                    .fontWeight(.bold)
                                    .foregroundColor(ishaOffset != 0 ? .teal : .white)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { withAnimation { ishaOffset = 0 } } label: { Label("Reset", systemImage: "arrow.counterclockwise") }.tint(.teal)
                            }
                        }
                    } header: {
                        Text("Ajustement Manuel (Temkine)")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // ── SECTION 3 : INFOS & SOURCES ──
                    Section {
                        NavigationLink(destination: SourcesDetailView()) {
                            Label("Sources Authentiques", systemImage: "book.closed.fill")
                                .foregroundColor(.orange)
                        }
                        NavigationLink(destination: WidgetsDetailView()) {
                            Label("Fonctionnement des Widgets", systemImage: "square.grid.2x2.fill")
                                .foregroundColor(.blue)
                        }
                    } header: {
                        Text("Transparence & À propos")
                            .foregroundColor(.white.opacity(0.6))
                    }
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
                
            }
            .navigationTitle("Réglages")
            .preferredColorScheme(.dark)
        }
    }
}

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
                        Text("4. Choisissez la taille du widget (Prochaine prière, Phase de la Lune, etc.) et appuyez sur 'Ajouter'.")
                    }
                    .foregroundColor(.white.opacity(0.8)).padding().background(.ultraThinMaterial).cornerRadius(15)
                }
                .padding()
            }
        }
        .navigationTitle("Widgets").navigationBarTitleDisplayMode(.inline)
    }
}
