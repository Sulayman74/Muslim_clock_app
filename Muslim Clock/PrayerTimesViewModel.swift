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
    
    /// Store du mode voyage, alimenté par le sink de localisation ci-dessous.
    /// `weak` : c'est MainView qui le possède (@State). Optionnel → le VM fonctionne sans.
    weak var travelStore: TravelModeStore?

    // 1. LE GARDE-FOU
    var lastLocation: CLLocation?
    private var lastCalculationDate: Date? = nil
    /// Offset GMT (secondes) au moment du dernier calcul. Sert à détecter un
    /// changement d'heure d'été/hiver (DST) : au passage, l'offset varie alors
    /// que le jour et le lieu ne changent pas — sans ça, le garde-fou anti-boucle
    /// bloquerait le recalcul et les horaires resteraient décalés d'une heure.
    private var lastCalculationTZOffset: Int? = nil
    private var calculationLocation: CLLocation?
    
    // 2. LECTURE DES RÉGLAGES UTILISATEUR (SMART SETUP)
    @AppStorage(StorageKeys.fajrOffset) private var fajrOffset = 0
    @AppStorage(StorageKeys.calculationMethod) private var calculationMethod = "UOIF (12°)"
    @AppStorage(StorageKeys.maghribOffset) private var maghribOffset = 0
    @AppStorage(StorageKeys.isIshaFixed) private var isIshaFixed = true
    @AppStorage(StorageKeys.ishaFixedDuration) private var ishaFixedDuration = 90
    @AppStorage(StorageKeys.ishaOffset) private var ishaOffset = 0
    @AppStorage(StorageKeys.dhuhrOffset) private var dhuhrOffset = 0
    @AppStorage(StorageKeys.asrOffset) private var asrOffset = 0

    // Jumu'ah (vendredi)
    @AppStorage(StorageKeys.jumuahEnabled) private var jumuahEnabled = false
    @AppStorage(StorageKeys.jumuahHour) private var jumuahHour = 13
    @AppStorage(StorageKeys.jumuahMinute) private var jumuahMinute = 0

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
                self?.travelStore?.update(with: newLocation)   // détection voyage, zéro nouvel abonnement
            }
            .store(in: &cancellables)
        
        // Vérifie si l'heure a tourné pendant que le téléphone était verrouillé
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkIfPrayerTimePassed()
                // Recalcule si l'offset DST a changé pendant la suspension. Le
                // garde-fou de calculatePrayers court-circuite si jour, lieu et
                // fuseau sont inchangés — donc no-op dans le cas normal.
                if let loc = self?.lastLocation {
                    self?.calculatePrayers(for: loc)
                }
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
        
        // Offset GMT courant : s'il diffère du dernier calcul, on a franchi un
        // changement DST → le garde-fou ne doit PAS court-circuiter le recalcul.
        let currentTZOffset = TimeZone.current.secondsFromGMT(for: now)

        if let lastDate = lastCalculationDate {
                let isSameDay = Calendar.current.isDate(now, inSameDayAs: lastDate)
                let isSamePlace = (lastLocation?.distance(from: location) ?? .infinity) < 2000
                let isSameTZ = lastCalculationTZOffset == currentTZOffset

                if isSameDay && isSamePlace && isSameTZ && !self.dailyPrayers.isEmpty {
                    return
                }
            }

        // LE GARDE-FOU ANTI-BOUCLE
        let isSameDay = Calendar.current.isDate(now, inSameDayAs: lastCalculationDate ?? Date.distantPast)
        let isSamePlace = (lastLocation?.distance(from: location) ?? .infinity) < 2000
        let isSameTZ = lastCalculationTZOffset == currentTZOffset

        if isSameDay && isSamePlace && isSameTZ && !self.dailyPrayers.isEmpty {
            return
        }

        self.lastLocation = location
        self.lastCalculationDate = now
        self.lastCalculationTZOffset = currentTZOffset
        
        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // ⚙️ Paramètres Adhan (méthode + temkine) — moteur pur testable.
        let params = PrayerCalculationEngine.parameters(
            method: calculationMethod,
            fajrOffset: fajrOffset,
            dhuhrOffset: dhuhrOffset,
            asrOffset: asrOffset,
            maghribOffset: maghribOffset,
            ishaOffset: ishaOffset,
            isIshaFixed: isIshaFixed,
            ishaFixedDuration: ishaFixedDuration
        )

        let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        if let prayerTimesToday = PrayerTimes(coordinates: coordinates, date: todayComponents, calculationParameters: params) {
            updateNextPrayer(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)
            self.isLoading = false

            // Heure de Dhuhr effective : Jumu'ah le vendredi si activé.
            let dhuhrEffective: Date = {
                guard isFridayJumuah else { return prayerTimesToday.dhuhr }
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = jumuahHour; comps.minute = jumuahMinute; comps.second = 0
                return Calendar.current.date(from: comps) ?? prayerTimesToday.dhuhr
            }()

            // Fajr de demain — permet à la complication de calculer la fin de la
            // fenêtre Isha (middleOfNight) à n'importe quelle heure du jour.
            let tomorrowFajr: Date? = {
                guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return nil }
                let comps = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                return PrayerTimes(coordinates: coordinates, date: comps, calculationParameters: params)?.fajr
            }()

            PrayerSynchronizer.publishSchedule(
                fajr: prayerTimesToday.fajr,
                sunrise: prayerTimesToday.sunrise,
                dhuhr: dhuhrEffective,
                asr: prayerTimesToday.asr,
                maghrib: prayerTimesToday.maghrib,
                isha: prayerTimesToday.isha,
                fajrTomorrow: tomorrowFajr
            )
        }

        // 📅 Planification des notifications d'adhan.
        schedule14DaysNotifications(coordinates: coordinates, params: params)

        // Publication de la position + du miroir des réglages (App Group + Watch +
        // widgets). Effectuée même si le calcul du jour a échoué (comportement d'origine).
        PrayerSynchronizer.publishSettings(
            location: location,
            settings: PrayerSyncSettings(
                calculationMethod: calculationMethod,
                fajrOffset: fajrOffset,
                dhuhrOffset: dhuhrOffset,
                asrOffset: asrOffset,
                maghribOffset: maghribOffset,
                ishaOffset: ishaOffset,
                isIshaFixed: isIshaFixed,
                ishaFixedDuration: ishaFixedDuration,
                jumuahEnabled: jumuahEnabled,
                jumuahHour: jumuahHour,
                jumuahMinute: jumuahMinute
            )
        )
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
            refreshLiveActivity()
        } else {
            fetchTomorrowsFajr(coordinates: coordinates, params: params, formatter: formatter)
        }
    }

    /// Met à jour la Live Activity "Prochaine Salât" si on est dans la fenêtre d'annonce (≤ 30 min).
    /// Termine aussi les éventuelles activities périmées (post-prière > 5 min).
    /// `internal` pour pouvoir être appelée depuis MainView au passage `scenePhase = .active`.
    func refreshLiveActivity() {
        guard let targetDate = nextPrayerDate else { return }
        let manager = SalatLiveActivityManager.shared
        manager.syncActiveActivitiesState()
        manager.refresh(
            prayerKey: SalatLiveActivityManager.prayerKey(from: nextPrayerName),
            frenchName: nextPrayerName,
            targetTime: targetDate
        )
    }
    
    // MARK: - 📅 PLANIFICATION 14 JOURS
        private func schedule14DaysNotifications(coordinates: Coordinates, params: CalculationParameters) {
            var allDates: [Date] = []
            var allNames: [String] = []
            let calendar = Calendar.current
            
            // Boucle sur l'horizon de planification (budget notifications iOS).
            for i in 0..<NotificationManager.adhanHorizonDays {
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
            UserDefaults(suiteName: AppGroup.identifier)?.set(nextFajrDate.timeIntervalSince1970, forKey: StorageKeys.prayerFajrTomorrow)
            WatchSessionManager.shared.sendPrayerTimes([StorageKeys.prayerFajrTomorrow: nextFajrDate.timeIntervalSince1970])

            if let firstIndex = self.dailyPrayers.firstIndex(where: { $0.name == "Fajr" }) {
                self.dailyPrayers[firstIndex] = DailyPrayer(
                    name: "Fajr",
                    time: nextFajrTimeString,
                    date: nextFajrDate,
                    isNext: true,
                    isCurrent: false
                )
            }
            refreshLiveActivity()
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
            
            // Marqueurs de nuit + fenêtre courante — moteur pur testable.
            let markers = PrayerCalculationEngine.nightMarkers(
                maghrib: prayerTimesToday.maghrib,
                fajrTomorrow: prayerTimesTomorrow.fajr
            )
            self.middleOfNight = markers.middleOfNight
            self.lastThirdOfNight = markers.lastThirdOfNight

            let win = PrayerCalculationEngine.currentWindow(
                now: now,
                fajr: prayerTimesToday.fajr,
                sunrise: prayerTimesToday.sunrise,
                dhuhr: prayerTimesToday.dhuhr,
                asr: prayerTimesToday.asr,
                maghrib: prayerTimesToday.maghrib,
                isha: prayerTimesToday.isha,
                middleOfNight: markers.middleOfNight
            )
            currentPrayerWindow = win.window
            currentWindowStart = win.start
            currentWindowEnd = win.end
        }
    }

