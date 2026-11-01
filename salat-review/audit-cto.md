# Audit technique (CTO) — onglet Salat (1er novembre 2026)

Constat principal : le coût des rendus. MainView observe environ 76 propriétés `@Published`, dont deux qui changent très souvent : le cap de la boussole (jusqu'à 60 fois par seconde) et la position du podcast (2 fois par seconde). À chaque changement, tout le `body` de MainView est réévalué, onglet Salat compris. Deux bugs probables : `AdhkarMomentCard` ne s'afficherait jamais, et l'état de la prière en cours ne se met plus à jour, app ouverte, si l'utilisateur a coupé les notifications.

Configuration : la cible app compile en `SWIFT_VERSION = 5.0` (`project.pbxproj:983, 1045`) avec isolation MainActor par défaut (`:980, 1042`). Elle n'est pas en mode Swift 6 strict.

## 1. Architecture

| Objet | Mode | Instances |
|---|---|---|
| `PrayerTimesViewModel` | `@StateObject` → `.environmentObject` (l.618) | 1 |
| `WeatherViewModel` | `@StateObject` | 1 |
| `CompassManager` | `@StateObject` (sert à Qibla, vit dans MainView) | 1 |
| `PodcastManager`, `DailyContentService`, `AppUpdateChecker` | `@StateObject` | 1 chacun |
| `NetworkMonitor.shared`, `SharedLocationManager.shared` | `@ObservedObject` | singletons |
| `TravelModeStore` | `@State` + `@Observable` | 1 |
| `QuranPlanViewModel` / `IlmViewModel` | aucune dans l'onglet | 0 |

Logique métier dans les vues (contraire à CLAUDE.md:79-80) :
- `MainView.swift:254-275` : `prayerContextForCards` (Dhuhr → Jumu'ah), `isCurrentlyFriday`, `currentSeason` ; les deux premiers dupliquent `NextPrayerWidget.displayName` (`WeatherMiniWidget.swift:121-127`).
- `MainView.swift:773-788` : `scheduleAdhkarReminders`, 7 déclencheurs (l.631-640).
- `MainView.swift:842-928` : routage deep-links et `checkSeasonalChanges`, seuil 120 jours en dur. Un coordinator logé dans la vue.
- `WidgetDateHeader` (l.16-37), `MoonWidgetView.hijriMonthYear` (l.121-127) : `DateFormatter` dans le `body`, `fr_FR` en dur.
- `PrayerListView.iqamahTime` (`WeatherMiniWidget.swift:191-199`) : calcul + `DateFormatter` par ligne et par rendu.
- `AdhkarQuickAccessButton.timing` (`AdhkarView.swift:600-607`) : règle matin/soir 4h-15h en dur, non testée.
- `SpiritualReminderCard` (`PostPrayerAdhkarService.swift:267-303`) : contenu reconstruit à chaque rendu.

Source unique de localisation respectée. Écart mineur : `GPSRelocationIndicator` (`PostPrayerAdhkarService.swift:576`) et `PrayerFreshnessLine` (l.542) appellent le singleton directement.

## 2. Performance

| # | Constat | Emplacement | Impact |
|---|---|---|---|
| P1 | `CompassManager` publie `heading` et `headingUpdateCount` jusqu'à 60 fois/s (`CompassManager.swift:110-123`) ; le `body` de MainView (TabView complet) est réévalué à chaque tick | `MainView.swift:192` | Élevé |
| P2 | `PodcastManager.currentTime` publié 2 fois/s pendant la lecture (`PodcastManager.swift:721-729`) ; même effet quel que soit l'onglet | `MainView.swift:194` | Élevé |
| P3 | `IslamicSeasonInfo.current()` appelé 5 fois dans le `body` (l.332, 396, 430, 483, 505) + `isRamadan()` (l.363) + une fois par ligne de `PrayerListView` : ~11 `Calendar(.islamicUmmAlQura)` par passage, lecture UserDefaults en DEBUG | `IslamicSeasonInfo.swift:28-40` | Moyen |
| P4 | `WidgetDateHeader(date: .now)` et `MoonWidgetView(date: .now)` : jamais considérés inchangés ; 3 + 1 + 5 `DateFormatter` ; la date n'avance pas à minuit sans nouveau rendu | `MainView.swift:315, 416` | Moyen |
| P5 | `CosmicBackground` : MeshGradient, Canvas 10 Hz (~160 ellipses/image), Canvas étoiles filantes 30 Hz permanent ; instancié deux fois (onglets 0 et 2, l.430 et 505) | `CosmicBackground.swift:165, 256` | Moyen |
| P6 | `DailyPrayer.id = UUID()` (`PrayerTimesViewModel.swift:12`), `MoonDayInfo.id = UUID()` (`MoonWidgetView.swift:32`) : identité des `ForEach` changeante, vues recréées, transitions cassées | | Moyen |
| P7 | TimelineViews : horloge minute, Iqamah 2 s, Dhuhr 10 s, Wudu 30 s, jauge adaptative, Ramadan 60 s ; les cartes sont bien cadencées, le fond domine | | Faible-moyen |
| P8 | `ScrollView` + `VStack` non lazy (l.441), ~20 cartes, 4 `GeometryReader` | | Faible |
| P9 | `calculatePrayers` reprogramme toutes les notifications (~70 requêtes) à chaque recalcul ; `scheduleAdhkarReminders` relancé par `.task` et `.onChange` au démarrage → deux `Task` concurrentes (`AdhkarReminderScheduler.swift:43`) | | Faible-moyen |

Sources d'invalidation observées par MainView : `PrayerTimesViewModel` 19, `PodcastManager` 21, `DailyContentService` 11, `CompassManager` 10, `WeatherViewModel` 6, `AppUpdateChecker` 4, `SharedLocationManager` 3, `NetworkMonitor` 2 → ~76, plus 11 `@AppStorage`.

## 3. Concurrence

- Combine : 3 `sink` dans `PrayerTimesViewModel.init` (l.80-113, `.debounce`/`.receive(on: DispatchQueue.main)`), `PassthroughSubject onReconnect` (`NetworkMonitor.swift:27`), `sink` dans `CompassManager` (l.81). Toléré pour l'existant, mais c'est le cœur de l'app.
- `DispatchQueue.main.asyncAfter(0.5)` dans `forceRecalculation` (`PrayerTimesViewModel.swift:149`) : contournement, pas correctif.
- `DispatchQueue.main.asyncAfter(6)` dans `refreshLocation` (`SharedLocationManager.swift:70`) : timeout non annulé.
- `Task {}` non structurées jamais annulées : `.onReceive(onReconnect)` (l.643), `onChange(manager.userLocation)` (l.656, fetchs empilables), l.612-614, retry deep-link (l.879), `NetworkStatusBanner` (l.103), `GPSRelocationIndicator` (l.574), `AdhkarReminderScheduler.schedule` (l.43), `PostPrayerAdhkarService.loadAdhkar` (l.19).
- `.task {}` bien employé : MainView l.623, RamadanDua, AdhkarMomentCard, PostPrayerAdhkarView.
- `getPendingNotificationRequests { }` en callback depuis une classe MainActor, `center.add(request)` sans gestion d'erreur (`NotificationManager.swift`) → risque d'assertion en Swift 6 strict ; passer à `await center.pendingNotificationRequests()`.
- `SharedLocationManager` : `Task { @MainActor }` redondant dans le délégué (l.92, 100).
- Double post de `AdhanTriggered` (`Muslim_ClockApp.swift:33, 62`) : overlay et `forceRecalculation` peuvent se déclencher deux fois.

## 4. Robustesse

**Fenêtre de prière figée, app ouverte.** `currentPrayerWindow`, `currentWindowEnd`, `nextPrayerDate` et `dailyPrayers.isNext` ne sont recalculés que sur changement de position, `willEnterForeground` ou `AdhanTriggered`. Aucun minuteur dans le ViewModel. Conséquences : au lever du soleil la jauge Fajr reste à 100 % avec « -0:00 » jusqu'au Dhuhr ; si les notifications sont refusées, l'état ne se met jamais à jour au premier plan ; au passage de minuit idem. Touche `CurrentPrayerGaugeView`, `NextPrayerWidget`, `PrayerListView`.

**`AdhkarMomentCard` : bug probable.** `Group { if let category = topCategory {…} }.task { load }` (`AdhkarBookletView.swift:343-356`). `categories` vide au départ → `Group` vide → le `.task` ne s'attache jamais → la carte ne s'affiche jamais. Le piège est documenté dans `RamadanDuaCardView.swift:109-113`. À confirmer sur appareil. `topCategory` utilise `Date()` sans TimelineView.

| Type | Constat |
|---|---|
| Force unwrap | `URL(string:)!` `WeatherMiniWidget.swift:20, 59` (constantes, toléré). `as! AVURLAsset` `DailyContentView.swift:~480` sans `// Why:` |
| Erreurs avalées | `RemoteJSONLoader.load … ?? []` (AdhkarMomentCard) sans log ; `didFailWithError` ignoré (`SharedLocationManager.swift:99`) ; `center.add` sans erreur |
| `print` | `MainView.swift:603, 847, 850, 859-884` (8 logs deep-link à chaque `.active`), `NotificationManager`, `PostPrayerAdhkarService:26`. Seul `WeatherViewModel` utilise `Logger` |
| États d'erreur | Météo KO : triangle + « --°C » sans action. Horaires vides : `isLoading` ne repasse jamais à `false` si `PrayerTimes(...)` renvoie nil (`PrayerTimesViewModel.swift:218-220`) → squelette infini. `lastPrayerUpdate` mis à jour avant le calcul (l.184) |
| Valeurs magiques | 30 s / 250 ms / 3 essais (l.856-880), 120 jours (l.923), 0.85 et 350 pt (jauge l.88, 247), 2/10/30 s, 0.5 s, 6 s, 300 m (l.83), « > 15km » en dur (l.590), 2.5 s |
| Dupliqué | Garde-fou dupliqué dans `calculatePrayers` (l.162-170 et 173-179) |

## 5. État et persistance

| Clé | Lue par | `StorageKeys` ? |
|---|---|---|
| `TravelKeys.active` | MainView (l.202, jamais utilisée), TravelModeBackdrop, TravelModeHeader, TravelFiqhCard, AdhkarMomentCard | namespace `TravelKeys` |
| `iqamahFajr/Dhuhr/Asr/Maghrib/IshaDelay` | MainView, PrayerListView, IqamahCountdownCard, Settings, SmartSetup, QuranKhatmaCard | ✗ littéraux, 6 fichiers |
| `adhkarReminderMorningEnabled/EveningEnabled/OffsetMinutes` | MainView | ✗ |
| `lastSmartSetupDate`, `lastDSTState`, `lastSeenAppVersion` | MainView | ✗ |
| `debugForceFriday` (hors `#if DEBUG`), `debugForceWuduWindow`, `debugRamadanWindow`, `debugSeasonDate` | MainView, Wudu, IslamicSeasonInfo | ✗ |
| `appLanguage` | RamadanDuaCardView | ✗ |
| `controlDeepLinkTarget/Timestamp` (App Group) | MainView l.844-872 | ✗ (8 occurrences) |
| 11 clés de calcul | PrayerTimesViewModel (`@AppStorage` dans un ObservableObject) | ✓ |

Divergence des défauts iqamah (bug réel tant que l'utilisateur n'a rien réglé) :

| Prière | Settings / SmartSetup / Countdown / Khatma / MainView | `PrayerListView` (`WeatherMiniWidget.swift:174-178`) |
|---|---|---|
| Fajr | 20 | 10 |
| Dhuhr | 15 | 10 |
| Asr | 15 | 10 |
| Isha | 15 | 10 |

Clés en camelCase alors que CLAUDE.md:91 prescrit le snake_case.

## 6. Testabilité

| Logique | Extraite | Testée |
|---|---|---|
| `DhuhrCountdownMath`, `IqamahMath`, `WuduWindowMath`, `RamadanDuaWindow`, `PrayerCalculationEngine`, `LocationMath`, `UpdateCheckMath`, `AdhkarSuggestion`, `SharedPrayerSchedule` | ✓ | ✓ |
| `IslamicSeasonInfo.current/isRamadan/ramadanBadge` | ✓ (DEBUG lit UserDefaults) | ✗ |
| `ProphetSunnahProvider.current` | ✓ | ✗ |
| `MoonPhaseCalculator` | ✓ | ✗ |
| `AdhkarReminderScheduler` | partiel | ✗ |
| `NotificationDeepLink` | ✓ | ✗ |
| `CurrentPrayerGaugeView.barCadence` | ✓ | ✗ |
| `TravelModeStore` | ✓ | ✗ |
| Règle Dhuhr → Jumu'ah, `isCurrentlyFriday`, matin/soir QuickAccess, `iqamahTime`, `checkSeasonalChanges` | ✗ dans les vues | ✗ |
| `PrayerTimesViewModel` (DST, `fetchTomorrowsFajr`), `WeatherViewModel` | ✗ (singletons, `Date()`) | ✗ |

## 7. Dette

- Code mort : `RawatibCardView`/`RawatibInfo` (144 lignes), `WeatherViewModel.moonSymbol`, `View.if(_:)` (`WeatherMiniWidget.swift:268-277`), `MainView.travelModeActive` (l.202, jamais lu mais provoque un rendu), branche Jumu'ah inatteignable dans `PrayerListView.iqamahDelay`, bloc DEBUG commenté `SettingsView.swift:270-285`.
- Commentaires obsolètes : `// ✨ NOUVEAU` (MainView l.215), `// 🔥 NOUVEAU` (VM l.106, 141), « Tu devras t'assurer… » (VM l.360), « recalculée à chaque apparition » (l.272, faux), « // 1. LE GARDE-FOU » sans suite ; indentation incohérente.
- `debugForceFriday` hors `#if DEBUG` (MainView l.248, Wudu).
- Duplication : barre de progression capsule ×4 (jauge l.92-103, décompte l.425-436, Iqamah l.146-157, lune l.196-211) ; Dhuhr et Iqamah quasi identiques ; ~5 variantes de pastille inline ; gradient matin/soir dupliqué (MainView l.714-720 et `AdhkarQuickAccessButton`) ; URL GitHub en dur.
- i18n : `fr_FR`, « Temps du \(…) », « Recalculer position (> 15km) ».

## 8. Top 10 des risques

| # | Risque | Gravité | Recommandation | Coût |
|---|---|---|---|---|
| 1 | Fenêtre de prière figée au premier plan | Critique | `Task` qui dort jusqu'à `min(currentWindowEnd, nextPrayerDate, minuit)` puis recalcule, relancée à chaque recalcul, annulée en arrière-plan ; remplace `asyncAfter(0.5)` | M |
| 2 | Invalidation de MainView à 60 Hz (boussole) et 2 Hz (podcast) | Élevé | `CompassManager` dans `QiblaView` ; `currentTime`/`duration` dans un `@Observable` séparé | M |
| 3 | `AdhkarMomentCard` jamais affichée | Élevé | Conteneur toujours présent + TimelineView ; vérifier sur appareil | S |
| 4 | Défauts iqamah divergents, clés littérales dans 6 fichiers | Élevé | `IqamahKeys` + `IqamahDefaults` dans `StorageKeys`, un `delay(for:)` | S |
| 5 | `IslamicSeasonInfo.current()` ×11, `date: .now`, formatters dans les `body` | Moyen | Saison une fois par passage ou dans le VM ; formatters `static let` ; dates via TimelineView | S |
| 6 | `CosmicBackground` 30 Hz permanent, deux instances | Moyen | Planning sur `triggerTime`, une instance derrière la TabView, Instruments | M |
| 7 | Identités `UUID()` | Moyen | `id` = nom / date | S |
| 8 | Coordinator dans MainView (959 lignes), `print` | Moyen | `AppRouter` `@Observable`, `os.Logger`, constantes, tests `NotificationDeepLink` | M |
| 9 | Notifications : reprogrammation complète, callbacks, `add` sans erreur, Swift 5 | Moyen | `async` + `do/catch`, diff, acteur ; `SWIFT_VERSION = 6` | M-L |
| 10 | Logique non testée + code mort | Faible-moyen | Injecter `now`/`calendar`, `SalatContext` testé ; supprimer le mort ; `ProgressCapsule` + `StatusChip` | S-M |

## 9. Ce qui est bien

1. Une seule instance de chaque ViewModel, injectée par `environmentObject` ; source unique de localisation.
2. Logique de temps extraite et testée, partagée avec widget, Watch et complication (`SharedPrayerSchedule`).
3. Cadences réfléchies et documentées (horloge minute, `Text(timerInterval:)`, jauge adaptative, Canvas fusionnés, Reduce Motion).
4. `WeatherViewModel` exemplaire : `async`/`await`, annulation, anti-spam, `os.Logger`, attribution WeatherKit.
5. Deep-links robustes au démarrage à froid ; garde-fou DST ; `.refreshable` qui demande un point GPS frais avant la météo.
