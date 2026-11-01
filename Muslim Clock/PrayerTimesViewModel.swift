import Foundation
import CoreLocation
import Combine
import Adhan
import WidgetKit
import SwiftUI

// `PrayerWindow` vit dans PrayerCalculationEngine.swift (fichier partagé avec les extensions).

// MARK: - Model de DailyPrayer
struct DailyPrayer: Identifiable {
    /// Identité stable (le nom est unique dans la journée) : un `UUID()` par
    /// recalcul détruisait et recréait chaque ligne du `ForEach`.
    var id: String { name }
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
    /// `true` pendant un calcul. Démarre à `false` : sans position, il n'y a rien
    /// à attendre — un squelette perpétuel masquait l'état vide (cf. PrayerEmptyStateCard).
    @Published var isLoading: Bool = false
    /// `true` si le dernier calcul a échoué (coordonnées invalides) : l'état vide
    /// peut alors proposer « Réessayer » sans confondre avec « pas encore calculé ».
    @Published private(set) var calculationFailed: Bool = false

    @Published var nextPrayerDate: Date? = nil
    @Published var dailyPrayers: [DailyPrayer] = []
    @Published var currentPrayerWindow: PrayerWindow = .none
    @Published var currentWindowStart: Date? = nil
    @Published var currentWindowEnd: Date? = nil
    @Published var sunriseTime: Date? = nil
    @Published var middleOfNight: Date? = nil
    @Published var hasMovedSignificantly: Bool = false
    /// Instant du dernier recalcul effectif des horaires — alimente la ligne
    /// « Horaires mis à jour à HH:mm » (fraîcheur visible pour l'utilisateur).
    @Published private(set) var lastPrayerUpdate: Date? = nil
    @Published var lastThirdOfNight: Date? = nil
    /// Heures réelles du Fajr et du Asr, utilisées par AdhkarService pour délimiter les périodes
    @Published var fajrDate: Date? = nil
    @Published var asrDate: Date? = nil
    /// Dhuhr astronomique du jour (jamais l'heure Jumu'ah) — le vendredi,
    /// `dailyPrayers` porte la Jumu'ah ; le Smart Setup a besoin du vrai Dhuhr.
    @Published var dhuhrDate: Date? = nil
    
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

    /// Minuteur d'état : réveille un recalcul à la prochaine borne (fin de la
    /// fenêtre en cours, prochaine prière, minuit). Sans lui, l'état n'évoluait
    /// que sur notification d'adhan, retour au premier plan ou déplacement —
    /// la jauge restait donc figée au lever du soleil, ou indéfiniment quand
    /// les notifications sont refusées.
    private var stateRefreshTask: Task<Void, Never>?
    /// Marge après la borne, pour que le moteur voie bien l'instant franchi.
    private static let stateRefreshMargin: TimeInterval = 1

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
        
        // Quand une prière tombe (AppDelegate.willPresent ou didReceive), on
        // rafraîchit immédiatement pour passer à la suivante. Le minuteur d'état
        // couvre le même instant ; ce chemin reste pour la réactivité au tap.
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
            if LocationMath.isSignificantMove(from: calcLoc, to: location) {
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
    /// Force un recalcul immédiat (changement de réglage, adhan, borne du
    /// minuteur d'état) en court-circuitant le garde-fou anti-boucle.
    func forceRecalculation() {
        self.lastCalculationDate = nil
        if let loc = self.lastLocation {
            calculatePrayers(for: loc)
        }
    }

    /// Programme le prochain recalcul à la borne la plus proche (fin de fenêtre,
    /// prochaine prière, minuit). Relancé à chaque calcul ; l'ancien minuteur est annulé.
    private func scheduleStateRefresh() {
        stateRefreshTask?.cancel()
        let fireAt = PrayerCalculationEngine.nextRefreshDate(
            now: Date(),
            windowEnd: currentWindowEnd,
            nextPrayer: nextPrayerDate
        )
        let delay = max(Self.stateRefreshMargin, fireAt.timeIntervalSinceNow + Self.stateRefreshMargin)
        stateRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.forceRecalculation()
        }
    }

    func calculatePrayers(for location: CLLocation) {
        let now = Date()

        // Offset GMT courant : s'il diffère du dernier calcul, on a franchi un
        // changement DST → le garde-fou ne doit PAS court-circuiter le recalcul.
        let currentTZOffset = TimeZone.current.secondsFromGMT(for: now)

        // Garde-fou anti-boucle : même jour, même lieu, même fuseau et horaires
        // déjà calculés → rien à faire.
        let isSameDay = Calendar.current.isDate(now, inSameDayAs: lastCalculationDate ?? Date.distantPast)
        let isSamePlace = LocationMath.isSamePlace(lastLocation, location)
        let isSameTZ = lastCalculationTZOffset == currentTZOffset

        if isSameDay && isSamePlace && isSameTZ && !self.dailyPrayers.isEmpty {
            return
        }

        self.lastLocation = location
        self.lastCalculationDate = now
        self.lastCalculationTZOffset = currentTZOffset
        self.isLoading = true

        let coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)

        // Réglages courants, sous la forme publiée aux extensions.
        let syncSettings = PrayerSyncSettings(
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
        let snapshot = PrayerSettingsSnapshot(location: location, sync: syncSettings)

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

        let prayerTimesToday = PrayerTimes(coordinates: coordinates, date: todayComponents, calculationParameters: params)
        self.calculationFailed = (prayerTimesToday == nil)

        if let prayerTimesToday {
            updateNextPrayer(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)
            self.lastPrayerUpdate = now   // horaires réellement recalculés → fraîcheur à jour

            // Publication des horaires du jour : calculés par le code PARTAGÉ
            // (`SharedPrayerSchedule`, même fichier que widget / complication / Watch).
            // Ce que l'app publie et ce que les extensions recalculent sortent donc de la
            // même implémentation — aucune dérive possible (Jumu'ah, offsets, méthode).
            if let today = SharedPrayerSchedule.schedule(for: now, settings: snapshot) {
                // Fajr de demain — fin de la fenêtre Isha (middleOfNight) et prochaine
                // prière après Isha pour les extensions.
                let tomorrowFajr = Calendar.current.date(byAdding: .day, value: 1, to: now)
                    .flatMap { SharedPrayerSchedule.schedule(for: $0, settings: snapshot)?.fajr }

                PrayerSynchronizer.publishSchedule(
                    fajr: today.fajr,
                    sunrise: today.sunrise,
                    dhuhr: today.dhuhr,
                    asr: today.asr,
                    maghrib: today.maghrib,
                    isha: today.isha,
                    fajrTomorrow: tomorrowFajr
                )
            }
        }

        // Le chargement est terminé, que le calcul ait abouti ou non : un échec
        // (coordonnées invalides) laissait le squelette affiché indéfiniment.
        self.isLoading = false
        scheduleStateRefresh()

        // 📅 Planification des notifications d'adhan.
        schedule14DaysNotifications(coordinates: coordinates, params: params)

        // Publication de la position + du miroir des réglages (App Group + Watch +
        // widgets). Effectuée même si le calcul du jour a échoué (comportement d'origine).
        PrayerSynchronizer.publishSettings(location: location, settings: syncSettings)
    }
    
    private func updateNextPrayer(prayerTimesToday: PrayerTimes, coordinates: Coordinates, params: CalculationParameters) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let currentNext = prayerTimesToday.nextPrayer()
        determineCurrentPrayerWindow(prayerTimesToday: prayerTimesToday, coordinates: coordinates, params: params)

        self.fajrDate  = prayerTimesToday.fajr
        self.asrDate   = prayerTimesToday.asr
        self.dhuhrDate = prayerTimesToday.dhuhr

        // Jumu'ah : remplace Dhuhr le vendredi si active (helper partagé — même
        // règle que les horaires publiés aux extensions).
        self.isFridayJumuah = SharedPrayerSchedule.isFriday(Date()) && jumuahEnabled

        let dhuhrDate: Date
        let dhuhrLabel: String
        if isFridayJumuah {
            dhuhrDate = SharedPrayerSchedule.jumuahTime(on: Date(), hour: jumuahHour, minute: jumuahMinute)
                ?? prayerTimesToday.dhuhr
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
                        // (helper partagé — même règle que les horaires publiés).
                        let dhuhrTime: Date
                        let dhuhrName: String
                        if SharedPrayerSchedule.isFriday(date, calendar: calendar) && jumuahEnabled {
                            dhuhrTime = SharedPrayerSchedule.jumuahTime(on: date, hour: jumuahHour, minute: jumuahMinute, calendar: calendar)
                                ?? p.dhuhr
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
            let calendar = Calendar.current
            self.sunriseTime = prayerTimesToday.sunrise

            // Fajr de demain (fin de la nuit à venir) et horaires d'hier (nuit en cours).
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return }
            let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            let yesterdayComponents = calendar.dateComponents([.year, .month, .day], from: yesterday)

            guard let prayerTimesTomorrow = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) else { return }
            let prayerTimesYesterday = PrayerTimes(coordinates: coordinates, date: yesterdayComponents, calculationParameters: params)

            // Nuit à venir (Maghrib du jour → Fajr de demain) : borne la fenêtre Isha du jour.
            let tonight = PrayerCalculationEngine.nightMarkers(
                maghrib: prayerTimesToday.maghrib,
                fajrTomorrow: prayerTimesTomorrow.fajr
            )

            // Marqueurs affichés (milieu, dernier tiers) : avant le Fajr du jour,
            // c'est la nuit EN COURS (Maghrib d'hier → Fajr d'aujourd'hui) qui
            // compte pour le qiyam — pas celle de ce soir.
            if now < prayerTimesToday.fajr, let yesterdayTimes = prayerTimesYesterday {
                let currentNight = PrayerCalculationEngine.nightMarkers(
                    maghrib: yesterdayTimes.maghrib,
                    fajrTomorrow: prayerTimesToday.fajr
                )
                self.middleOfNight = currentNight.middleOfNight
                self.lastThirdOfNight = currentNight.lastThirdOfNight
            } else {
                self.middleOfNight = tonight.middleOfNight
                self.lastThirdOfNight = tonight.lastThirdOfNight
            }

            var win = PrayerCalculationEngine.currentWindow(
                now: now,
                fajr: prayerTimesToday.fajr,
                sunrise: prayerTimesToday.sunrise,
                dhuhr: prayerTimesToday.dhuhr,
                asr: prayerTimesToday.asr,
                maghrib: prayerTimesToday.maghrib,
                isha: prayerTimesToday.isha,
                middleOfNight: tonight.middleOfNight
            )
            // Entre minuit et le milieu de la nuit, l'Isha d'hier est encore en cours.
            if win.window == .none, let yesterdayTimes = prayerTimesYesterday {
                win = PrayerCalculationEngine.previousNightWindow(
                    now: now,
                    fajrToday: prayerTimesToday.fajr,
                    maghribYesterday: yesterdayTimes.maghrib,
                    ishaYesterday: yesterdayTimes.isha
                )
            }
            currentPrayerWindow = win.window
            currentWindowStart = win.start
            currentWindowEnd = win.end
        }
    }

