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

@MainActor
class WatchPrayerViewModel: ObservableObject {
    @Published var prayers: [WatchPrayer] = []
    @Published var nextPrayer: WatchPrayer?
    @Published var isDataAvailable = false

    private let defaults = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")

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
        var loaded: [WatchPrayer] = []

        for pd in prayerDefs {
            let interval = def.double(forKey: pd.key)
            guard interval > 0 else {
                isDataAvailable = false
                prayers = []
                nextPrayer = nil
                return
            }
            loaded.append(WatchPrayer(
                name: pd.name,
                arabicName: pd.arabic,
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
