import Foundation
import SwiftUI
import Combine

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

    private let defaults = UserDefaults(suiteName: AppGroup.identifier)

    private static func arabicName(_ prayer: PrayerName) -> String {
        switch prayer {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    /// Recalcule la journée courante avec `SharedPrayerSchedule` (position + réglages
    /// reçus de l'iPhone), repli sur les horaires reçus si la position manque.
    /// La journée bascule donc toute seule à minuit, sans nouvel envoi iPhone.
    func refresh() {
        let now = Date()
        season = WatchIslamicSeason.current(for: now)

        guard let resolved = SharedPrayerSchedule.resolve(at: now, defaults: defaults) else {
            isDataAvailable = false
            prayers = []
            nextPrayer = nil
            return
        }

        let next = resolved.nextPrayer(at: now)
        let loaded: [WatchPrayer] = resolved.today.ordered.map { prayer, time in
            // Vendredi + Jumu'ah : label spécial pour Dhuhr (l'heure est déjà celle de la Jumu'ah).
            let isJumuah = prayer == .dhuhr && resolved.today.isFridayJumuah
            return WatchPrayer(
                name: isJumuah ? "Jumu'ah" : prayer.rawValue,
                arabicName: isJumuah ? "الجمعة" : Self.arabicName(prayer),
                time: time,
                isNext: prayer == next.prayer && time == next.time
            )
        }

        // Toutes les prières du jour passées → Fajr de demain (toujours futur ici).
        nextPrayer = loaded.first(where: { $0.isNext }) ?? WatchPrayer(
            name: PrayerName.fajr.rawValue,
            arabicName: Self.arabicName(.fajr),
            time: resolved.tomorrowFajr,
            isNext: true
        )
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

    private let defaults = UserDefaults(suiteName: AppGroup.identifier)

    var hasContent: Bool {
        !ayahFR.isEmpty || !hadithFR.isEmpty
    }

    func refresh() {
        ayahFR     = defaults?.string(forKey: StorageKeys.dailyAyahFr) ?? ""
        ayahAR     = defaults?.string(forKey: StorageKeys.dailyAyahAr) ?? ""
        ayahSource = defaults?.string(forKey: StorageKeys.dailyAyahSource) ?? ""

        hadithFR     = defaults?.string(forKey: StorageKeys.dailyHadithFr) ?? ""
        hadithAR     = defaults?.string(forKey: StorageKeys.dailyHadithAr) ?? ""
        hadithSource = defaults?.string(forKey: StorageKeys.dailyHadithSource) ?? ""
    }
}
