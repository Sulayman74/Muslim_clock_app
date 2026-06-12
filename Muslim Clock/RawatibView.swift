//
//  RawatibView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//
import SwiftUI

/// Représente une recommandation Rawatib affichée dans la card.
private struct RawatibInfo {
    let title: String
    let text: String
    let icon: String
    /// Récitation rapportée du Prophète ﷺ pour la Sunnah associée (optionnel).
    let recitation: String?
    /// Source du hadith (Sahih Muslim X, Bukhari Y…) — affichée si `recitation` présent.
    let source: String?
}

struct RawatibCardView: View {
    var prayerContext: String

    private var info: RawatibInfo {
        switch prayerContext.lowercased() {
        case "fajr":
            return RawatibInfo(
                title: String(localized: "Sunnah du Fajr"),
                text: String(localized: "2 Rak'at très méritoires avant l'obligatoire."),
                icon: "sun.and.horizon.fill",
                recitation: String(localized: "Le Prophète ﷺ y récitait **Al-Kafirun (109)** + **Al-Ikhlas (112)**."),
                source: "Sahih Muslim 726"
            )
        case "dhuhr":
            return RawatibInfo(
                title: String(localized: "Rawatib du Dhuhr"),
                text: String(localized: "4 Rak'at avant, et 2 Rak'at après."),
                icon: "sun.max.fill",
                recitation: nil,
                source: nil
            )
        case "jumu'ah", "jumuah":
            return RawatibInfo(
                title: String(localized: "Jumu'ah"),
                text: String(localized: "Prière du Vendredi. Sourate Al-Kahf recommandée."),
                icon: "building.columns.fill",
                recitation: nil,
                source: nil
            )
        case "asr":
            return RawatibInfo(
                title: String(localized: "Autour de l'Asr"),
                text: String(localized: "Pas de Rawatib, mais l'invocation entre l'Adhan et l'Iqama est exaucée."),
                icon: "sun.dust.fill",
                recitation: nil,
                source: nil
            )
        case "maghrib":
            return RawatibInfo(
                title: String(localized: "Rawatib du Maghrib"),
                text: String(localized: "2 Rak'at après l'obligatoire."),
                icon: "sunset.fill",
                recitation: String(localized: "Parmi ce qui est rapporté, le Prophète ﷺ y récitait **Al-Kafirun (109)** + **Al-Ikhlas (112)**."),
                source: "Sahih Muslim 727 / Tirmidhi 431"
            )
        case "isha":
            return RawatibInfo(
                title: String(localized: "Clôture de la nuit"),
                text: String(localized: "2 Rak'at après l'Isha, puis clôturez par le Witr."),
                icon: "moon.stars.fill",
                recitation: String(localized: "**Witr** : 1ère **Al-A'la (87)**, 2ème **Al-Kafirun (109)**, 3ème **Al-Ikhlas (112)** (parfois + Al-Falaq et An-Nas)."),
                source: "Abu Dawud 1424 / An-Nasa'i 1729"
            )
        default:
            return RawatibInfo(
                title: String(localized: "La Prière"),
                text: String(localized: "Accomplissez la prière à son heure."),
                icon: "sparkles",
                recitation: nil,
                source: nil
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {

            // Icône dynamique
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: info.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(info.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)

                Text(info.text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                // Récitation rapportée (uniquement Fajr/Maghrib/Isha pour l'instant)
                if let recitation = info.recitation {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.orange.opacity(0.75))
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(.init(recitation))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                            if let source = info.source {
                                Text(verbatim: source)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.top, 2)
                }
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
        .animation(.easeInOut, value: prayerContext)
    }
}
