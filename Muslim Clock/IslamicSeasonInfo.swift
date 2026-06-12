//
//  IslamicSeasonInfo.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//

import SwiftUI

// MARK: - ═══════════════════════════════════════════════════
// ISLAMIC SEASON INFO
// Détection du mois hégirien + couleurs + labels
// Réutilisable dans les vues ET le service
// ═══════════════════════════════════════════════════════════

struct IslamicSeasonInfo {
    let hijriMonth: Int
    let hijriDay: Int               // Jour hijri (1-30) — utile pour les vues qui dépendent du jour
    let seasonKey: String           // "ramadan", "hajj", "muharram", "shaban", "shawwal", ou "general"
    let labelFr: String             // "Ramadan Mubarak", etc.
    let labelAr: String             // "رمضان مبارك", etc.
    let icon: String                // SF Symbol
    let bannerColors: [Color]       // Gradient du bandeau
    let backgroundColors: [Color]   // Gradient du fond de la tab Salat
    let isSacredMonth: Bool

    // MARK: - Factory
    static func current(for date: Date = .now) -> IslamicSeasonInfo {
        // En DEBUG, une date de substitution peut être injectée depuis le panneau debug
        #if DEBUG
        let debugTimestamp = UserDefaults.standard.double(forKey: "debugSeasonDate")
        let effectiveDate = debugTimestamp > 0 ? Date(timeIntervalSince1970: debugTimestamp) : date
        #else
        let effectiveDate = date
        #endif

        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar")
        let month = cal.component(.month, from: effectiveDate)
        let day = cal.component(.day, from: effectiveDate)

        switch month {
        case 1: // Muharram
            return IslamicSeasonInfo(
                hijriMonth: 1,
                hijriDay: day,
                seasonKey: "muharram",
                labelFr: "Muharram — Mois Sacré",
                labelAr: "شهر الله المحرّم",
                icon: "moon.stars.fill",
                bannerColors: [Color(red: 0.15, green: 0.2, blue: 0.4), Color(red: 0.1, green: 0.12, blue: 0.3)],
                backgroundColors: [Color(red: 0.1, green: 0.15, blue: 0.35).opacity(0.8), Color(red: 0.08, green: 0.1, blue: 0.3)],
                isSacredMonth: true
            )
        case 7: // Rajab
            return IslamicSeasonInfo(
                hijriMonth: 7,
                hijriDay: day,
                seasonKey: "rajab",
                labelFr: "Rajab — Mois Sacré",
                labelAr: "رجب الحرام",
                icon: "sparkles",
                bannerColors: [Color(red: 0.3, green: 0.2, blue: 0.45), Color(red: 0.2, green: 0.12, blue: 0.35)],
                backgroundColors: [Color(red: 0.25, green: 0.15, blue: 0.4).opacity(0.7), Color(red: 0.15, green: 0.1, blue: 0.35)],
                isSacredMonth: true
            )
        case 8: // Sha'ban
            return IslamicSeasonInfo(
                hijriMonth: 8,
                hijriDay: day,
                seasonKey: "shaban",
                labelFr: "Sha'ban — Préparation au Ramadan",
                labelAr: "شعبان",
                icon: "leaf.fill",
                bannerColors: [Color(red: 0.35, green: 0.25, blue: 0.5), Color(red: 0.25, green: 0.15, blue: 0.4)],
                backgroundColors: [Color(red: 0.3, green: 0.2, blue: 0.45).opacity(0.7), Color(red: 0.2, green: 0.12, blue: 0.4)],
                isSacredMonth: false
            )
        case 9: // Ramadan
            return IslamicSeasonInfo(
                hijriMonth: 9,
                hijriDay: day,
                seasonKey: "ramadan",
                labelFr: "Ramadan Mubarak",
                labelAr: "رمضان مبارك 🌙",
                icon: "moon.fill",
                bannerColors: [Color(red: 0.6, green: 0.45, blue: 0.1), Color(red: 0.45, green: 0.3, blue: 0.05)],
                backgroundColors: [Color(red: 0.35, green: 0.25, blue: 0.05).opacity(0.8), Color(red: 0.25, green: 0.18, blue: 0.05)],
                isSacredMonth: false  // pas sacré au sens "haram" mais mois à part
            )
        case 10: // Shawwal — bandeau Aïd uniquement le 1er jour
            if day == 1 {
                return IslamicSeasonInfo(
                    hijriMonth: 10,
                    hijriDay: day,
                    seasonKey: "shawwal",
                    labelFr: "Aïd al-Fitr Mubarak",
                    labelAr: "عيد الفطر المبارك 🎉",
                    icon: "gift.fill",
                    bannerColors: [Color(red: 0.1, green: 0.45, blue: 0.35), Color(red: 0.05, green: 0.3, blue: 0.25)],
                    backgroundColors: [Color(red: 0.08, green: 0.35, blue: 0.28).opacity(0.7), Color(red: 0.05, green: 0.25, blue: 0.2)],
                    isSacredMonth: false
                )
            } else {
                // Reste de Shawwal → pas de bandeau, fond par défaut
                return IslamicSeasonInfo(
                    hijriMonth: 10,
                    hijriDay: day,
                    seasonKey: "general",
                    labelFr: "",
                    labelAr: "",
                    icon: "",
                    bannerColors: [],
                    backgroundColors: [.blue.opacity(0.4), .indigo.opacity(0.6)],
                    isSacredMonth: false
                )
            }
        case 11: // Dhu al-Qi'dah (sacré) — teal pour différencier du vert émeraude de Dhul-Hijjah
            return IslamicSeasonInfo(
                hijriMonth: 11,
                hijriDay: day,
                seasonKey: "dhulqidah",
                labelFr: "Dhu al-Qi'dah — Mois Sacré",
                labelAr: "ذو القعدة",
                icon: "shield.fill",
                bannerColors: [Color(red: 0.08, green: 0.45, blue: 0.50), Color(red: 0.04, green: 0.30, blue: 0.35)],
                backgroundColors: [Color(red: 0.06, green: 0.32, blue: 0.38).opacity(0.75), Color(red: 0.04, green: 0.22, blue: 0.28)],
                isSacredMonth: true
            )
        case 12: // Dhu al-Hijjah
            if day >= 10 && day <= 13 { // Aïd al-Adha + jours de Tashreeq
                return IslamicSeasonInfo(
                    hijriMonth: 12,
                    hijriDay: day,
                    seasonKey: "hajj",
                    labelFr: "Aïd al-Adha Mubarak",
                    labelAr: "عيد الأضحى المبارك 🐑",
                    icon: "star.fill",
                    bannerColors: [Color(red: 0.08, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.28, blue: 0.12)],
                    backgroundColors: [Color(red: 0.06, green: 0.32, blue: 0.18).opacity(0.8), Color(red: 0.04, green: 0.22, blue: 0.1)],
                    isSacredMonth: true
                )
            } else if day <= 9 { // Les 10 premiers jours bénis
                return IslamicSeasonInfo(
                    hijriMonth: 12,
                    hijriDay: day,
                    seasonKey: "hajj",
                    labelFr: "Les 10 jours bénis — Dhu al-Hijjah",
                    labelAr: "ذو الحجّة — لبّيك اللهم لبّيك",
                    icon: "building.columns.fill",
                    bannerColors: [Color(red: 0.08, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.28, blue: 0.12)],
                    backgroundColors: [Color(red: 0.06, green: 0.32, blue: 0.18).opacity(0.8), Color(red: 0.04, green: 0.22, blue: 0.1)],
                    isSacredMonth: true
                )
            } else { // Reste du mois (jour 14+)
                return IslamicSeasonInfo(
                    hijriMonth: 12,
                    hijriDay: day,
                    seasonKey: "hajj",
                    labelFr: "Dhu al-Hijjah — Mois Sacré",
                    labelAr: "ذو الحجّة",
                    icon: "shield.fill",
                    bannerColors: [Color(red: 0.08, green: 0.4, blue: 0.2), Color(red: 0.05, green: 0.28, blue: 0.12)],
                    backgroundColors: [Color(red: 0.06, green: 0.32, blue: 0.18).opacity(0.8), Color(red: 0.04, green: 0.22, blue: 0.1)],
                    isSacredMonth: true
                )
            }
        default: // Mois normal
            return IslamicSeasonInfo(
                hijriMonth: month,
                hijriDay: day,
                seasonKey: "general",
                labelFr: "",
                labelAr: "",
                icon: "",
                bannerColors: [],
                backgroundColors: [.blue.opacity(0.4), .indigo.opacity(0.6)],
                isSacredMonth: false
            )
        }
    }
    
    /// true si on a un bandeau à afficher
    var hasBanner: Bool {
        seasonKey != "general"
    }

    // MARK: - Helpers Ramadan

    /// `true` si la date donnée tombe pendant le mois de Ramadan (mois hégirien 9).
    /// Respecte l'override DEBUG `debugSeasonDate` via `current(for:)`.
    static func isRamadan(at date: Date = .now) -> Bool {
        current(for: date).hijriMonth == 9
    }

    /// Renvoie le badge contextuel Ramadan à afficher **à côté** du nom de la prière,
    /// ou `nil` si aucun badge n'est pertinent. Le nom canonique de la prière
    /// (« Maghrib » / « Fajr ») est conservé partout — c'est le badge qui apporte
    /// le contexte Ramadan (rupture du jeûne / fin du sahari).
    static func ramadanBadge(for prayerName: String, at date: Date = .now) -> String? {
        guard isRamadan(at: date) else { return nil }
        switch prayerName {
        case "Maghrib": return String(localized: "Iftar")
        case "Fajr":    return String(localized: "Fin du Sohoor")
        default:        return nil
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// BANDEAU VUE
// ═══════════════════════════════════════════════════════════

struct SeasonBannerView: View {
    let season: IslamicSeasonInfo
    
    var body: some View {
        if season.hasBanner {
            HStack(spacing: 10) {
                Image(systemName: season.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(season.labelAr)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    Text(season.labelFr)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if season.isSacredMonth {
                    Text("حرام")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: season.bannerColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
