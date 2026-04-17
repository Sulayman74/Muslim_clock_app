import Foundation
import CoreLocation
import Combine
import Adhan
import WidgetKit
import SwiftUI

enum PrayerWindow: String {
    case fajr = "Fajr", dhuhr = "Dhuhr", asr = "Asr"
    case maghrib = "Maghrib", isha = "Isha", none = "none"
    
    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        case .none: return ""
        }
    }
    
    var icon: String {
        switch self {
        case .fajr: return "sun.and.horizon.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.dust.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        case .none: return "clock.fill"
        }
    }
}

// MARK: - Model de DailyPrayer
struct DailyPrayer: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let date: Date
    let isNext: Bool
    let isCurrent: Bool
}


@MainActor
class PrayerTimesViewModel: ObservableObject {
    @Published var nextPrayerName: String = "..."
    @Published var nextPrayerTime: String = "--:--"
    private var cancellables = Set<AnyCancellable>()
    @Published var isLoading: Bool = true
    
    @Published var nextPrayerDate: Date? = nil
    @Published var dailyPrayers: [DailyPrayer] = []
    @Published var currentPrayerWindow: PrayerWindow = .none
    @Published var currentWindowStart: Date? = nil
    @Published var currentWindowEnd: Date? = nil
    @Published var sunriseTime: Date? = nil
    @Published var middleOfNight: Date? = nil
    @Published var hasMovedSignificantly: Bool = false
    @Published var lastThirdOfNight: Date? = nil
    /// Heures réelles du Fajr et du Asr, utilisées par AdhkarService pour délimiter les périodes
    @Published var fajrDate: Date? = nil
    @Published var asrDate: Date? = nil
    
    // 1. LE GARDE-FOU
    var lastLocation: CLLocation?
    private var lastCalculationDate: Date? = nil
    private var calculationLocation: CLLocation?
    
    // 2. LECTURE DES RÉGLAGES UTILISATEUR (SMART SETUP)
    @AppStorage("userFajrOffset") private var fajrOffset = 0
    @AppStorage("userCalculationMethod") private var calculationMethod = "UOIF (12°)"
    @AppStorage("userMaghribOffset") private var maghribOffset = 0
    @AppStorage("isIshaFixed") private var isIshaFixed = true
    @AppStorage("userIshaFixedDuration") private var ishaFixedDuration = 90
    @AppStorage("userIshaOffset") private var ishaOffset = 0
    @AppStorage("userDhuhrOffset") private var dhuhrOffset = 0
    @AppStorage("userAsrOffset") private var asrOffset = 0

    // Jumu'ah (vendredi)
    @AppStorage("jumuahEnabled") private var jumuahEnabled = false
    @AppStorage("jumuahHour") private var jumuahHour = 13
    @AppStorage("jumuahMinute") private var jumuahMinute = 0

    /// True si on est vendredi et que le Jumu'ah est active
    @Published var isFridayJumuah: Bool = false

    init() {
        SharedLocationManager.shared.$currentLocation
            .compactMap { $0 }
            .removeDuplicates { old, new in
                old.distance(from: new) < 300
            }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] newLocation in
                self?.checkRelocation(for: newLocation)
                self?.calculatePrayers(for: newLocation)
            }
            .store(in: &cancellables)
        
        // Vérifie si l'heure a tourné pendant que le téléphone était verrouillé
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkIfPrayerTimePassed()
            }
            .store(in: &cancellables)
        
        // 🔥 NOUVEAU : quand une prière tombe (déclenché par AppDelegate.willPresent
        // ou didReceive), on rafraîchit immédiatement pour passer à la suivante.
        NotificationCenter.default.publisher(for: NSNotification.Name("AdhanTriggered"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.forceRecalculation()
            }
            .store(in: &cancellables)
    }
    // MARK: - Logique de relocalisation GPS
        private func checkRelocation(for location: CLLocation) {
            guard let calcLoc = calculationLocation else {
                calculationLocation = location
                return
            }
            let distance = calcLoc.distance(from: location)
            if distance > 15000 { // 15 km
                self.hasMovedSignificantly = true
            }
        }
        
        func relocateAndRecalculate() {
            self.hasMovedSignificantly = false
            self.lastCalculationDate = nil
            if let currentLoc = SharedLocationManager.shared.currentLocation {
                self.calculationLocation = currentLoc
                calculatePrayers(for: currentLoc)
            }
        }
    // Fonction qui force le recalcul si on a dépassé l'heure
        private func checkIfPrayerTimePassed() {
            guard let targetDate = nextPrayerDate else { return }
            if Date() >= targetDate {
                self.forceRecalculation()
            }
        }
    // NOUVEAU : Fonction pour forcer le recalcul si l'utilisateur change un réglage
    func forceRecalculation() {
        // On efface la date pour forcer le passage du garde-fou
        self.lastCalculationDate = nil
        
        if let loc = self.lastLocation {
            // 💡 Petit délai de 0.5s pour être sûr que la bibliothèque Adhan
            // voit bien que la prière est passée.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.calculatePrayers(for: loc)
            }
        }
    }
    
    func calculatePrayers(for location: CLLocation) {
        let now = Date()
        
        if let lastDate = lastCalculationDate {
                let isSameDay = Calendar.current.isDate(now, inSameDayAs: lastDate)
                let isSamePlace = (lastLocation?.distance(from: location) ?? .infinity) < 2000
                
                if isSameDay && isSamePlace && !self.dailyPrayers.isEmpty {
                    return
                }
            }
        
        // LE GARDE-FOU ANTI-BOUCLE
        let isSameDay = Calendar.current.isDate(now, inSameDayAs: lastCalculationDate ?? Date.distantPast)
        let isSamePlace = (lastLocation?.distance(from: location) ?? .infinity) < 2000
        
        if isSameDay && isSamePlace && !self.dailyPrayers.isEmpty {
            return
        }
        
        self.lastLocation = location
        self.lastCalculationDate = now
        
        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // ⚙️ APPLICATION DE LA MÉTHODE (ANGLES)
        var params: CalculationParameters
        
        switch calculationMethod {
        case "UOIF (12°)":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 12
            params.ishaAngle = 12
        case "ISNA (15°)":
            params = CalculationMethod.northAmerica.params
        case "Mosquée de Paris":
            params = CalculationMethod.muslimWorldLeague.params
            params.fajrAngle = 18
            params.ishaAngle = 18
        default: // "Ligue Islamique (18°)"
            params = CalculationMethod.muslimWorldLeague.params
        }
        
        params.madhab = .shafi
        
        // 🎛️ APPLICATION DU TEMKINE ET DU LISSAGE
        params.adjustments.fajr = fajrOffset
        params.adjustments.dhuhr = dhuhrOffset
        params.adjustments.asr = asrOffset
        params.adjustments.maghrib = maghribOffset
        
        if isIshaFixed {
            params.ishaInterval = ishaFixedDuration
            params.adjustments.isha = maghribOffset
        } else {
            params.adjustments.isha = ishaOffset
        }
        
        let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        if let prayerTimesToday = PrayerTimes(coordinates: coordinates, date: todayComponents, calculationParameters: params) {
            updateNextPrayer(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)
            self.isLoading = false
            // Write prayer times for Watch app and complications
            let sharedWatch = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
            sharedWatch?.set(prayerTimesToday.fajr.timeIntervalSince1970, forKey: "prayer_fajr")
            // Si vendredi + Jumu'ah active, ecrire l'heure Jumu'ah a la place de Dhuhr
            if isFridayJumuah {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = jumuahHour; comps.minute = jumuahMinute; comps.second = 0
                let jumuahDate = Calendar.current.date(from: comps) ?? prayerTimesToday.dhuhr
                sharedWatch?.set(jumuahDate.timeIntervalSince1970, forKey: "prayer_dhuhr")
            } else {
                sharedWatch?.set(prayerTimesToday.dhuhr.timeIntervalSince1970, forKey: "prayer_dhuhr")
            }
            sharedWatch?.set(prayerTimesToday.asr.timeIntervalSince1970, forKey: "prayer_asr")
            sharedWatch?.set(prayerTimesToday.maghrib.timeIntervalSince1970, forKey: "prayer_maghrib")
            sharedWatch?.set(prayerTimesToday.isha.timeIntervalSince1970, forKey: "prayer_isha")
            sharedWatch?.set(prayerTimesToday.sunrise.timeIntervalSince1970, forKey: "prayer_sunrise")
            // Sync vers Apple Watch via WatchConnectivity
            WatchSessionManager.shared.sendPrayerTimes([
                "prayer_fajr":    prayerTimesToday.fajr.timeIntervalSince1970,
                "prayer_dhuhr":   prayerTimesToday.dhuhr.timeIntervalSince1970,
                "prayer_asr":     prayerTimesToday.asr.timeIntervalSince1970,
                "prayer_maghrib": prayerTimesToday.maghrib.timeIntervalSince1970,
                "prayer_isha":    prayerTimesToday.isha.timeIntervalSince1970,
            ])
        }
        //  📅 NOUVEAU : PLANIFICATION SUR 14 JOURS POUR LES NOTIFICATIONS
                schedule14DaysNotifications(coordinates: coordinates, params: params)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // ✅ SYNCHRONISATION VERS SHARED USERDEFAULTS
        // Le widget lit ces valeurs pour appliquer la même logique
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        let shared = UserDefaults(suiteName: "group.kappsi.Muslim-Clock")
        shared?.set(location.coordinate.latitude, forKey: "saved_latitude")
        shared?.set(location.coordinate.longitude, forKey: "saved_longitude")
        
        // Réglages de calcul
        shared?.set(calculationMethod, forKey: "w_calculationMethod")
        shared?.set(fajrOffset, forKey: "w_fajrOffset")
        shared?.set(dhuhrOffset, forKey: "w_dhuhrOffset")
        shared?.set(asrOffset, forKey: "w_asrOffset")
        shared?.set(maghribOffset, forKey: "w_maghribOffset")
        shared?.set(isIshaFixed, forKey: "w_isIshaFixed")
        shared?.set(ishaFixedDuration, forKey: "w_ishaFixedDuration")
        shared?.set(ishaOffset, forKey: "w_ishaOffset")
        shared?.set(jumuahEnabled, forKey: "w_jumuahEnabled")
        shared?.set(jumuahHour, forKey: "w_jumuahHour")
        shared?.set(jumuahMinute, forKey: "w_jumuahMinute")

        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func updateNextPrayer(prayerTimesToday: PrayerTimes, coordinates: Coordinates, params: CalculationParameters) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let currentNext = prayerTimesToday.nextPrayer()
        determineCurrentPrayerWindow(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)

        self.fajrDate = prayerTimesToday.fajr
        self.asrDate  = prayerTimesToday.asr

        // Jumu'ah : remplace Dhuhr le vendredi si active
        let isFriday = Calendar.current.component(.weekday, from: Date()) == 6
        self.isFridayJumuah = isFriday && jumuahEnabled

        let dhuhrDate: Date
        let dhuhrLabel: String
        if isFridayJumuah {
            // Construire la date Jumu'ah pour aujourd'hui
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = jumuahHour
            comps.minute = jumuahMinute
            comps.second = 0
            dhuhrDate = Calendar.current.date(from: comps) ?? prayerTimesToday.dhuhr
            dhuhrLabel = "Jumu'ah"
        } else {
            dhuhrDate = prayerTimesToday.dhuhr
            dhuhrLabel = "Dhuhr"
        }

        self.dailyPrayers = [
                    DailyPrayer(name: "Fajr", time: formatter.string(from: prayerTimesToday.fajr), date: prayerTimesToday.fajr, isNext: currentNext == .fajr, isCurrent: self.currentPrayerWindow == .fajr),
                    DailyPrayer(name: dhuhrLabel, time: formatter.string(from: dhuhrDate), date: dhuhrDate, isNext: currentNext == .dhuhr, isCurrent: self.currentPrayerWindow == .dhuhr),
                    DailyPrayer(name: "Asr", time: formatter.string(from: prayerTimesToday.asr), date: prayerTimesToday.asr, isNext: currentNext == .asr, isCurrent: self.currentPrayerWindow == .asr),
                    DailyPrayer(name: "Maghrib", time: formatter.string(from: prayerTimesToday.maghrib), date: prayerTimesToday.maghrib, isNext: currentNext == .maghrib, isCurrent: self.currentPrayerWindow == .maghrib),
                    DailyPrayer(name: "Isha", time: formatter.string(from: prayerTimesToday.isha), date: prayerTimesToday.isha, isNext: currentNext == .isha, isCurrent: self.currentPrayerWindow == .isha)
                ]
        
        if let next = currentNext {
            let targetDate: Date
            let targetName: String
            if next == .dhuhr && isFridayJumuah {
                targetDate = dhuhrDate
                targetName = "Jumu'ah"
            } else {
                targetDate = prayerTimesToday.time(for: next)
                targetName = getPrayerName(for: next)
            }
            self.nextPrayerDate = targetDate
            self.nextPrayerName = targetName
            self.nextPrayerTime = formatter.string(from: targetDate)
        } else {
            fetchTomorrowsFajr(coordinates: coordinates, params: params, formatter: formatter)
        }
    }
    
    // MARK: - 📅 PLANIFICATION 14 JOURS
        private func schedule14DaysNotifications(coordinates: Coordinates, params: CalculationParameters) {
            var allDates: [Date] = []
            var allNames: [String] = []
            let calendar = Calendar.current
            
            // Boucle sur les 14 prochains jours
            for i in 0..<14 {
                if let date = calendar.date(byAdding: .day, value: i, to: Date()) {
                    let comps = calendar.dateComponents([.year, .month, .day], from: date)

                    if let p = PrayerTimes(coordinates: coordinates, date: comps, calculationParameters: params) {
                        // Vendredi + Jumu'ah active : remplacer Dhuhr par l'heure Jumu'ah
                        let dayIsFriday = calendar.component(.weekday, from: date) == 6
                        let dhuhrTime: Date
                        let dhuhrName: String
                        if dayIsFriday && jumuahEnabled {
                            var jComps = comps
                            jComps.hour = jumuahHour; jComps.minute = jumuahMinute; jComps.second = 0
                            dhuhrTime = calendar.date(from: jComps) ?? p.dhuhr
                            dhuhrName = "Jumu'ah"
                        } else {
                            dhuhrTime = p.dhuhr
                            dhuhrName = "Dhuhr"
                        }

                        let dayPrayers = [
                            ("Fajr", p.fajr), (dhuhrName, dhuhrTime), ("Asr", p.asr),
                            ("Maghrib", p.maghrib), ("Isha", p.isha)
                        ]

                        for (name, time) in dayPrayers {
                            if time > Date() {
                                allDates.append(time)
                                allNames.append(name)
                            }
                        }
                    }
                }
            }
            
            // 🚀 Envoi de tout le calendrier au gestionnaire de notifications
            // Tu devras t'assurer que ton NotificationManager a une fonction "scheduleBatchNotifications" !
            NotificationManager.shared.scheduleBatchNotifications(names: allNames, dates: allDates)
        }
        
    private func fetchTomorrowsFajr(coordinates: Coordinates, params: CalculationParameters, formatter: DateFormatter) {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return }
        let tomorrowComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        
        if let prayerTimesTomorrow = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) {
            let nextFajrDate = prayerTimesTomorrow.fajr
            let nextFajrTimeString = formatter.string(from: nextFajrDate) // 💡 Formulé une seule fois
            
            self.nextPrayerDate = nextFajrDate
            self.nextPrayerName = "Fajr"
            self.nextPrayerTime = nextFajrTimeString
            UserDefaults(suiteName: "group.kappsi.Muslim-Clock")?.set(nextFajrDate.timeIntervalSince1970, forKey: "prayer_fajr_tomorrow")
            WatchSessionManager.shared.sendPrayerTimes(["prayer_fajr_tomorrow": nextFajrDate.timeIntervalSince1970])
            
            if let firstIndex = self.dailyPrayers.firstIndex(where: { $0.name == "Fajr" }) {
                self.dailyPrayers[firstIndex] = DailyPrayer(
                    name: "Fajr",
                    time: nextFajrTimeString,
                    date: nextFajrDate,
                    isNext: true,
                    isCurrent: false
                )
            }
        }
    }
    
    private func getPrayerName(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "Fajr"
        case .sunrise: return "Chourouq"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
    

    // MARK: - Logique des fenêtres de prière (Jurisprudence Islamique)
        private func determineCurrentPrayerWindow(prayerTimesToday: PrayerTimes, coordinates: Coordinates, params: CalculationParameters) {
            let now = Date()
            self.sunriseTime = prayerTimesToday.sunrise
            
            // Calcul du Fajr de demain pour le calcul du milieu de la nuit
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return }
            let tomorrowComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            
            guard let prayerTimesTomorrow = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) else { return }
            
            // Calcul du milieu de la nuit : Maghrib + (Fajr demain - Maghrib) / 2
            let nightDuration = prayerTimesTomorrow.fajr.timeIntervalSince(prayerTimesToday.maghrib)
            let middleNight = prayerTimesToday.maghrib.addingTimeInterval(nightDuration / 2)
            // 🌙 NOUVEAU : Calcul du dernier tiers de la nuit
            // On prend le Fajr de demain et on recule d'un tiers de la nuit
            let lastThird = prayerTimesTomorrow.fajr.addingTimeInterval(-(nightDuration / 3))
            self.middleOfNight = middleNight
            self.lastThirdOfNight = lastThird
            
            if now >= prayerTimesToday.fajr && now < prayerTimesToday.sunrise {
                currentPrayerWindow = .fajr
                currentWindowStart = prayerTimesToday.fajr
                currentWindowEnd = prayerTimesToday.sunrise
            } else if now >= prayerTimesToday.dhuhr && now < prayerTimesToday.asr {
                currentPrayerWindow = .dhuhr
                currentWindowStart = prayerTimesToday.dhuhr
                currentWindowEnd = prayerTimesToday.asr
            } else if now >= prayerTimesToday.asr && now < prayerTimesToday.maghrib {
                currentPrayerWindow = .asr
                currentWindowStart = prayerTimesToday.asr
                currentWindowEnd = prayerTimesToday.maghrib
            } else if now >= prayerTimesToday.maghrib && now < prayerTimesToday.isha {
                currentPrayerWindow = .maghrib
                currentWindowStart = prayerTimesToday.maghrib
                currentWindowEnd = prayerTimesToday.isha
            } else if now >= prayerTimesToday.isha && now < middleNight {
                currentPrayerWindow = .isha
                currentWindowStart = prayerTimesToday.isha
                currentWindowEnd = middleNight
            } else {
                currentPrayerWindow = .none
                currentWindowStart = nil
                currentWindowEnd = nil
            }
        }
    }

