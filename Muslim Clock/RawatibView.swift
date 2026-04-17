//
//  RawatibView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//
import SwiftUI

struct RawatibCardView: View {
    var prayerContext: String // Ancien nextPrayer
        
        private var rawatibInfo: (title: String, text: String, icon: String) {
            switch prayerContext.lowercased() {
            case "fajr":
                return (String(localized: "Sunnah du Fajr"), String(localized: "2 Rak'at très méritoires avant l'obligatoire."), "sun.and.horizon.fill")
            case "dhuhr":
                return (String(localized: "Rawatib du Dhuhr"), String(localized: "4 Rak'at avant, et 2 Rak'at après."), "sun.max.fill")
            case "jumu'ah":
                return (String(localized: "Jumu'ah"), String(localized: "Priere du Vendredi. Sourate Al-Kahf recommandee."), "building.columns.fill")
            case "asr":
                return (String(localized: "Autour de l'Asr"), String(localized: "Pas de Rawatib, mais l'invocation entre l'Adhan et l'Iqama est exaucée."), "sun.dust.fill")
            case "maghrib":
                return (String(localized: "Rawatib du Maghrib"), String(localized: "2 Rak'at après l'obligatoire."), "sunset.fill")
            case "isha":
                return (String(localized: "Clôture de la nuit"), String(localized: "2 Rak'at après l'Isha, puis clôturez par le Witr."), "moon.stars.fill")
            default:
                return (String(localized: "La Prière"), String(localized: "Accomplissez la prière à son heure."), "sparkles")
            }
        }
    
    var body: some View {
        HStack(spacing: 16) {
            
            // L'icône dynamique (Soleil, Lune, etc.)
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: rawatibInfo.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rawatibInfo.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                
                Text(rawatibInfo.text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true) // Permet au texte de passer à la ligne proprement
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        // Petite animation quand le texte change
        .animation(.easeInOut, value: prayerContext)
    }
}
