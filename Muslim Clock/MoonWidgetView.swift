//
//  MoonWidgetView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//

import SwiftUI

struct MoonWidgetView: View {
    // Le symbole qui vient de ton WeatherKit
    var moonSymbol: String
    // La date actuelle (par défaut, maintenant)
    var date: Date = .now
    
    // 1. Calcul du jour hégirien (ex: 14)
    private var hijriDay: Int {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        return calendar.component(.day, from: date)
    }
    
    // 2. Détection magique des Jours Blancs (13, 14, 15)
    private var isWhiteDays: Bool {
        return (13...15).contains(hijriDay)
    }
    
    // 3. Formatage du mois et de l'année (ex: "Chawwal 1447")
    private var hijriMonthName: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).capitalized
    }
    
    var body: some View {
        HStack(spacing: 20) {
            
            // 🌕 L'icône dynamique de WeatherKit
            Image(systemName: moonSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .white.opacity(0.2))
                // L'ombre s'intensifie si c'est la pleine lune (Jours Blancs)
                .shadow(color: .white.opacity(isWhiteDays ? 0.8 : 0.2), radius: isWhiteDays ? 15 : 5)
            
            VStack(alignment: .leading, spacing: 4) {
                // Le titre change selon la période
                Text(isWhiteDays ? "✨ Les Jours Blancs" : "Phase Lunaire")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isWhiteDays ? .orange : .white)
                
                // La description génère la date exacte "14 Chawwal 1447"
                Text("\(hijriDay) \(hijriMonthName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isWhiteDays ? Color.indigo.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
        // Petite animation au cas où on passe minuit pendant que l'app est ouverte
        .animation(.easeInOut, value: isWhiteDays)
    }
}
