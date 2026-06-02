import Foundation
import SwiftUI
import Combine

/// Identifiant du App Group partagé iOS ↔ Watch.
/// Doit rester aligné avec `WatchExtension Watch App.entitlements`.
private let appGroupIdentifier = "group.kappsi.Muslim-Clock"

struct WatchPrayer: Identifiable {
    let id = UUID()
    let name: String
    let arabicName: String
    let time: Date
    var isNext: Bool
}

// MARK: - Islamic Season (Watch — lightweight, no SwiftUI Color deps from iOS)

struct WatchIslamicSeason {
    let hijriMonth: Int
    let hijriDay: Int
    let labelAr: String
    let icon: String
    let isSacredMonth: Bool
    let isEid: Bool
    let isFriday: Bool

    var hasBanner: Bool { !labelAr.isEmpty }

    static func current(for date: Date = .now) -> WatchIslamicSeason {
        let cal = Calendar(identifier: .islamicUmmAlQura)
        let month = cal.component(.month, from: date)
        let day   = cal.component(.day, from: date)
        let isFriday = Calendar.current.component(.weekday, from: date) == 6

        // (label, icon, sacred, eid) — un mois spécial l'emporte sur Friday.
        // Cas Friday seul → banner générique en fallback.
        let (label, icon, sacred, eid): (String, String, Bool, Bool) = {
            switch month {
            case 1:                                  return ("شهر حرام",         "moon.stars.fill",      true,  false)
            case 7:                                  return ("شهر حرام",         "sparkles",             true,  false)
            case 9:                                  return ("رمضان مبارك",       "moon.fill",            false, false)
            case 10 where day == 1:                  return ("عيد الفطر المبارك", "gift.fill",            false, true)
            case 11:                                 return ("شهر حرام",         "shield.fill",          true,  false)
            case 12 where (10...13).contains(day):   return ("عيد الأضحى المبارك","star.fill",            true,  true)
            case 12:                                 return ("شهر حرام",         "building.columns.fill",true,  false)
            default:
                return isFriday
                    ? ("يوم الجمعة", "building.columns.fill", false, false)
                    : ("", "", false, false)
            }
        }()

        return WatchIslamicSeason(
            hijriMonth: month,
            hijriDay: day,
            labelAr: label,
            icon: icon,
            isSacredMonth: sacred,
            isEid: eid,
            isFriday: isFriday
        )
    }
}

@MainActor
class WatchPrayerViewModel: ObservableObject {
    @Published var prayers: [WatchPrayer] = []
    @Published var nextPrayer: WatchPrayer?
    @Published var isDataAvailable = false
    @Published var season = WatchIslamicSeason.current()

    private let defaults = UserDefaults(suiteName: appGroupIdentifier)

    private let prayerDefs: [(name: String, arabic: String, key: String)] = [
        ("Fajr",    "الفجر",  "prayer_fajr"),
        ("Dhuhr",   "الظهر",  "prayer_dhuhr"),
        ("Asr",     "العصر",  "prayer_asr"),
        ("Maghrib", "المغرب", "prayer_maghrib"),
        ("Isha",    "العشاء", "prayer_isha"),
    ]

    func refresh() {
        guard let def = defaults else {
            isDataAvailable = false
            return
        }

        let now = Date()
        season = WatchIslamicSeason.current(for: now)

        // Jumu'ah : remplacer Dhuhr le vendredi si activé
        let isFriday = Calendar.current.component(.weekday, from: now) == 6
        let jumuahEnabled = def.bool(forKey: "w_jumuahEnabled")
        let isFridayJumuah = isFriday && jumuahEnabled

        var loaded: [WatchPrayer] = []

        for pd in prayerDefs {
            let interval = def.double(forKey: pd.key)
            guard interval > 0 else {
                isDataAvailable = false
                prayers = []
                nextPrayer = nil
                return
            }

            // Vendredi + Jumu'ah : label spécial pour Dhuhr
            let name: String
            let arabic: String
            if pd.key == "prayer_dhuhr" && isFridayJumuah {
                name = "Jumu'ah"
                arabic = "الجمعة"
            } else {
                name = pd.name
                arabic = pd.arabic
            }

            loaded.append(WatchPrayer(
                name: name,
                arabicName: arabic,
                time: Date(timeIntervalSince1970: interval),
                isNext: false
            ))
        }

        // Find next upcoming prayer
        if let idx = loaded.firstIndex(where: { $0.time > now }) {
            loaded[idx].isNext = true
            nextPrayer = loaded[idx]
        } else {
            // All today's prayers have passed — use tomorrow's Fajr
            let tomorrowInterval = def.double(forKey: "prayer_fajr_tomorrow")
            if tomorrowInterval > 0 {
                nextPrayer = WatchPrayer(
                    name: "Fajr",
                    arabicName: "الفجر",
                    time: Date(timeIntervalSince1970: tomorrowInterval),
                    isNext: true
                )
            } else {
                nextPrayer = nil
            }
        }

        prayers = loaded
        isDataAvailable = true
    }

    var islamicDateString: String {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar")
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        let monthNames = [
            "محرم", "صفر", "ربيع الأول", "ربيع الثاني",
            "جمادى الأولى", "جمادى الثانية", "رجب", "شعبان",
            "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
        ]
        let monthIdx = max(0, min(11, (comps.month ?? 1) - 1))
        return "\(comps.day ?? 0) \(monthNames[monthIdx])"
    }
}

// MARK: - Daily Content (verset + hadith) Watch view model

@MainActor
class WatchDailyContentViewModel: ObservableObject {
    @Published var ayahFR: String = ""
    @Published var ayahAR: String = ""
    @Published var ayahSource: String = ""

    @Published var hadithFR: String = ""
    @Published var hadithAR: String = ""
    @Published var hadithSource: String = ""

    private let defaults = UserDefaults(suiteName: appGroupIdentifier)

    var hasContent: Bool {
        !ayahFR.isEmpty || !hadithFR.isEmpty
    }

    func refresh() {
        ayahFR     = defaults?.string(forKey: "daily_ayah_fr") ?? ""
        ayahAR     = defaults?.string(forKey: "daily_ayah_ar") ?? ""
        ayahSource = defaults?.string(forKey: "daily_ayah_source") ?? ""

        hadithFR     = defaults?.string(forKey: "daily_hadith_fr") ?? ""
        hadithAR     = defaults?.string(forKey: "daily_hadith_ar") ?? ""
        hadithSource = defaults?.string(forKey: "daily_hadith_source") ?? ""
    }
}
