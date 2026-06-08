I now have ample understanding of the iOS codebase (15,438 LOC across all targets, 30+ distinct features mapped). Let me produce the complete Android blueprint.

---

# Muslim Clock — Android Native Blueprint (Kotlin/Compose)

Document destiné à un développeur Android senior pour porter Muslim Clock (iOS/watchOS) vers Android natif (phone + Wear OS) à iso-fonctionnalité. Basé sur l'exploration effective du code Swift (`/Volumes/Kappsi_docs/Dev/Muslim Clock/`, ~15 438 LOC).

---

## 1. Inventaire exhaustif des features iOS

Exploration des fichiers : `MainView.swift`, `Muslim_ClockApp.swift`, `PrayerTimesViewModel.swift`, `SharedLocationManager.swift`, `CompassManager.swift`, `NotificationManager.swift`, `SalatLiveActivityManager.swift`, `DailyContentService.swift`, `PodcastManager.swift`, `AudioCacheManager.swift`, `AdhkarView.swift`, `PostPrayerAdhkarService.swift`, `QuranLibraryLoader.swift`, `QuranChapter.swift`, `QuranPlanModel.swift`, `QuranPlanMath.swift`, `QuranPageMapper.swift`, `QuranRecorder.swift`, `QuranReminderScheduler.swift`, `AdhkarReminderScheduler.swift`, `RemoteJSONLoader.swift`, `IslamicSeasonInfo.swift`, `WeatherViewModel.swift`, `WatchSessionManager.swift`, `AppUpdateChecker.swift`, `NetworkMonitor.swift`, `ReviewHelper.swift`, `SalatWidget.swift`, `SalatWidgetControl.swift`, `SalatWidgetLiveActivity.swift`, `AppIntent.swift`, `PrayerComplication.swift`, `WatchPrayerViewModel.swift`, `ContentView.swift` (watch), `DesignSystem.swift`, `CosmicBackground.swift`.

**41 features distinctes identifiées :**

### Calcul prière & temps
1. **Horaires des 5 prières quotidiennes** — Adhan SPM, méthodes UOIF/ISNA/Paris/Muslim World League (`PrayerTimesViewModel.swift:185-200`)
2. **Offsets utilisateur par prière** (`fajrOffset`, `dhuhrOffset`, etc.) via `@AppStorage` (`PrayerTimesViewModel.swift:72-79`)
3. **Isha en mode fixe ou angulaire** (durée post-maghrib configurable, défaut 90 min) (`PrayerTimesViewModel.swift:75-77,210-215`)
4. **Jumu'ah le vendredi** : remplace Dhuhr par heure manuelle (`PrayerTimesViewModel.swift:82-84,315-331`)
5. **Détection fenêtre prière courante** (Fajr→Sunrise, Dhuhr→Asr, etc.) (`PrayerTimesViewModel.swift:459-504`)
6. **Calcul milieu de nuit et dernier tiers de nuit** (Maghrib + (Fajr+1/2)) (`PrayerTimesViewModel.swift:470-475`)
7. **Recalcul automatique au changement de localisation** (debounce 1s, seuil 300m) (`PrayerTimesViewModel.swift:90-100`)
8. **Bannière "vous avez bougé"** (relocate si >15 km) (`PrayerTimesViewModel.swift:124-128`)
9. **Force-recalcul sur foreground / after adhan** (`PrayerTimesViewModel.swift:103-117`)
10. **Smart Setup saisonnier** : popup tous les 120 jours + changement DST (`MainView.swift:589-609`)

### Géolocalisation
11. **Source unique GPS** (`CLLocationManager` distance filter 500m, accuracy 3km) (`SharedLocationManager.swift:23-26`)
12. **Reverse geocoding pour ville** (MKReverseGeocodingRequest) (`CompassManager.swift:162-179`)

### Boussole Qibla
13. **Boussole Qibla avec heading magnétique + déclinaison** (formule sphérique vers Mecque) (`CompassManager.swift:115-126`)
14. **Haptic feedback progressif 4 paliers** (< 20°, 10°, 5°, 2°) (`CompassManager.swift:62-103`)

### Notifications
15. **Adhan 14 jours planifiés à l'avance** (max 56 slots iOS — limite 64) (`PrayerTimesViewModel.swift:375-418`, `NotificationManager.swift:29-67`)
16. **Notification nouvelles lunes 6 mois** (UmmAlQura calendar, slots 57-62) (`NotificationManager.swift:70-110`)
17. **Rappels Adhkar post-Fajr et post-Asr** (`AdhkarReminderScheduler.swift`)
18. **Rappels lecture Coran post-prière** (offset 10 min après adhan) (`QuranReminderScheduler.swift`)
19. **Overlay Adhan plein écran** déclenché à la réception (`AdhanOverlay.swift`, `MainView.swift:449-471`)
20. **Pause auto podcast pendant Adhan + reprise auto** (`MainView.swift:503-516`)

### Adhkar
21. **Adhkar matin/soir** (compteur par dhikr, période Fajr→Asr / Asr→Fajr+4h) (`AdhkarView.swift:62-100`)
22. **Adhkar post-prière** (filtrage par prière courante, fallback `fajr_maghrib`/`all`) (`PostPrayerAdhkarService.swift`)
23. **Rawatib card contextuelle** (Sunnah par prière courante) (`RawatibView.swift`)

### Coran
24. **Bibliothèque 114 sourates** (jsDelivr `risan/quran-json@3.1.2`) (`QuranLibraryLoader.swift`)
25. **Cache mémoire NSCache (30 sourates) + cache disque** (`QuranLibraryLoader.swift:27-32`)
26. **Mapping page Madinah ↔ (sura, ayah)** binaire O(log 604) (`QuranPageMapper.swift`)
27. **Plan de lecture (Khatma)** : par durée / pages / date cible (`QuranPlanModel.swift`)
28. **Journal SwiftData ReadingEntry** (heatmap, streak, progression) (`QuranReadingEntry.swift`, `QuranPlanMath.swift`)
29. **Enregistrement de récitation** (M4A AAC 32 kbps mono, durée max 10 min, marquage versets karaoké) (`QuranRecorder.swift`)

### Podcasts audio
30. **Lecteur podcasts curated** (RSS Apple Podcasts + playlists custom JSON S3/Firebase) (`PodcastManager.swift`)
31. **Cache audio agressif "download once"** (purge LRU à 500 MB) (`AudioCacheManager.swift`)
32. **Mini-player flottant + Full player sheet** (`MainView.swift:335-346`)
33. **Reprise lecture (bookmark) par série** (`PodcastManager.swift:108-109`)
34. **Pop-up fin de série + review StoreKit** (`MainView.swift:350-369`)

### Contenu quotidien
35. **Verset du jour aléatoire + audio Alafasy** (api.alquran.cloud — 6236 versets) (`DailyContentService.swift:91-119`)
36. **Hadith saisonnier** (ramadan, hajj, joumouha, lundi/jeudi, matin/soir) (`DailyContentService.swift:132-198`)

### Widgets, Live Activity, Wear
37. **Widgets iOS Home/Lock** : circle, small, large avec timestamps depuis App Group (`SalatWidget.swift`)
38. **Control Widgets iOS 18+** : Qibla, Adhkar, Coran (Control Center, Lock, Action Button) (`SalatWidgetControl.swift`)
39. **Live Activity "Prochaine Salât"** (fenêtre 30 min, persistance 5 min post-prière) (`SalatLiveActivityManager.swift`)
40. **Apple Watch app + complication** (synchro via WatchConnectivity + App Group) (`WatchSessionManager.swift`, `WatchPrayerViewModel.swift`, `PrayerComplication.swift`)

### Infra
41. **Bandeau saisonnier hijri** (Ramadan, Hajj, Muharram, etc. — 12 mois lunaires gérés) (`IslamicSeasonInfo.swift`), **OTA JSON depuis GitHub Pages** (hadiths, adhkar, post-prayer, audios) avec cache 3 niveaux (network → Documents → Bundle) (`RemoteJSONLoader.swift`), **météo via WeatherKit** (debounce 30 min / 5 km) (`WeatherViewModel.swift`), **NetworkMonitor** (NWPathMonitor + reconnect publisher) (`NetworkMonitor.swift`), **AppUpdateChecker** (iTunes Lookup, max 1x/jour) (`AppUpdateChecker.swift`), **ReviewHelper** (fenêtre glissante 365j, 3 demandes max), **What's New** post-update version Bundle, **localisation FR+AR** RTL (`Localizable.xcstrings`), **CosmicBackground animé** (MeshGradient + étoiles + filantes par saison) (`CosmicBackground.swift`).

---

## 2. Mapping iOS → Android (table de correspondance)

| Feature iOS | Source iOS clé | Équivalent Android |
|---|---|---|
| `PrayerTimesViewModel` + Adhan SPM | `PrayerTimesViewModel.swift` | `PrayerTimesRepository` + `com.batoulapps.adhan:adhan2:0.1.7` (Kotlin) — fallback : port maison si abandonware |
| `SharedLocationManager` singleton GPS | `SharedLocationManager.swift` | `LocationRepository` + `com.google.android.gms:play-services-location:21.3.0` (FusedLocationProvider) |
| `CompassManager` (heading) | `CompassManager.swift` | `CompassRepository` + `SensorManager` (`TYPE_ROTATION_VECTOR` + `SensorManager.getOrientation`) + `GeomagneticField` pour declinaison |
| `MKReverseGeocodingRequest` (city) | `CompassManager.swift:163` | `android.location.Geocoder.getFromLocation(...)` (API 33+ : version async) |
| `UNUserNotificationCenter` batch 56 prières | `NotificationManager.swift:29-67` | `AlarmManager.setExactAndAllowWhileIdle(...)` + `NotificationManagerCompat` ; persistance via Room `ScheduledAlarmEntity` |
| Nouvelles lunes UmmAlQura | `NotificationManager.swift:70-110` | `org.threeten.bp.chrono.HijrahDate` (java.time + UmmAlQura via `IsoChronology`) OU lib `com.github.msarhan:ummalqura-calendar:1.1.7` |
| Live Activity ActivityKit | `SalatLiveActivityManager.swift` | `NotificationCompat.Builder` ongoing + `setProgress` + `setUsesChronometer(true)` + `setStyle(...)` + **Live Updates API (Android 16+, API 36)** quand disponible (workaround: ongoing classique sous API 36) |
| WidgetKit Home/Lock | `SalatWidget.swift` | **Glance Widgets** : `androidx.glance:glance-appwidget:1.1.1` |
| Control Widgets iOS 18 | `SalatWidgetControl.swift` | **Quick Settings tiles** (`TileService`) + Glance widgets ; pas de "Action Button" universel sur Android |
| ClockKit complication | `PrayerComplication.swift` | **Wear OS Tiles** : `androidx.wear.tiles:tiles:1.4.1` + **Watch Face Complications** : `androidx.wear.watchface.complications.data:1.2.1` |
| watchOS app | `ContentView.swift` (watch) | **Wear OS module** Compose for Wear : `androidx.wear.compose:compose-material3:1.4.1` |
| WatchConnectivity | `WatchSessionManager.swift` | **Wear Data Layer API** : `com.google.android.gms:play-services-wearable:18.2.0` (`DataClient.putDataItem`) |
| UserDefaults App Group | `AppGroupID.swift` | **DataStore Preferences** partagé via `ContentProvider` custom (App Group n'existe pas) ; alternative simple : `SharedPreferences` avec MultiProcessSharedPreferences ContentProvider |
| `@AppStorage` settings | partout (`PrayerTimesViewModel.swift:72-84`) | `DataStore<Preferences>` + Flow ou `androidx.datastore:datastore-preferences:1.1.1` |
| `SwiftData` (`ReadingEntry`) | `QuranReadingEntry.swift` | **Room** : `androidx.room:room-runtime:2.6.1` + `room-ktx` |
| AVFoundation player + lock-screen now-playing | `PodcastManager.swift` | **Media3 ExoPlayer** : `androidx.media3:media3-exoplayer:1.4.1` + `media3-session` (MediaSessionService, MediaNotification auto) |
| `AVAudioRecorder` M4A AAC | `QuranRecorder.swift` | `MediaRecorder` (`OutputFormat.MPEG_4` + `AudioEncoder.AAC` + `setAudioEncodingBitRate(32_000)`) |
| `AudioCacheManager` LRU 500 MB | `AudioCacheManager.swift` | **Media3 SimpleCache** + `LeastRecentlyUsedCacheEvictor(500L * 1024 * 1024)` |
| `RemoteJSONLoader` network→cache→bundle | `RemoteJSONLoader.swift` | OkHttp + Cache (disk) + assets fallback ; service `RemoteJsonLoader` reproduit la stratégie 3 niveaux |
| `NWPathMonitor` reconnect | `NetworkMonitor.swift` | `ConnectivityManager.registerDefaultNetworkCallback` exposé en `Flow<Boolean>` |
| `WeatherKit` | `WeatherViewModel.swift` | **OpenWeatherMap API** ou **Open-Meteo (gratuit, sans clé)** : `https://api.open-meteo.com/v1/forecast` |
| `IslamicSeasonInfo` (`.islamicUmmAlQura`) | `IslamicSeasonInfo.swift` | `HijrahChronology.INSTANCE` (java.time) OU `ummalqura-calendar` |
| `MeshGradient` animé (iOS 18) | `CosmicBackground.swift` | Compose `Brush.linearGradient`/`radialGradient` + animation `infiniteRepeatable` ; pour mesh shader → **AGSL shaders Android 13+** (`RuntimeShader`) sinon fallback radial multi-stop |
| `Text(.timer)` countdown SwiftUI | `SalatWidgetLiveActivity.swift` | `Chronometer` view dans RemoteViews ou Compose `LaunchedEffect` ticker 1s |
| `String(localized:)` xcstrings FR+AR | `Localizable.xcstrings` | `res/values/strings.xml` + `res/values-ar/strings.xml` ; RTL via `android:supportsRtl="true"` |
| SF Symbols (`sun.and.horizon.fill`) | partout | Material Symbols : `androidx.compose.material.icons.extended` OU **Material Symbols font** custom (FontFamily.Resolver) |
| Police Coran Amiri | `AmiriQuran-Regular.ttf` | `res/font/amiri_quran.ttf` + `FontFamily(Font(R.font.amiri_quran))` |
| StoreKit review request | `ReviewHelper.swift` | **In-App Reviews API** : `com.google.android.play:review-ktx:2.0.2` (`ReviewManagerFactory`) |
| `Bundle.main.bundleId` iTunes lookup | `AppUpdateChecker.swift` | **In-App Updates** : `com.google.android.play:app-update-ktx:2.1.0` (`AppUpdateManager`) — bien plus officiel que parser le store |
| iOS Haptics `UIImpactFeedbackGenerator` | `CompassManager.swift:79-101` | `android.os.VibratorManager` + `VibrationEffect.createPredefined(EFFECT_CLICK)` / `EFFECT_HEAVY_CLICK` (API 29+) |
| `WidgetCenter.shared.reloadAllTimelines()` | `PrayerTimesViewModel.swift:301` | `GlanceAppWidgetManager(context).updateAll<MyWidget>()` |
| AppIntent `OpenIntent` | `AppIntent.swift` | Glance action `actionStartActivity` + deep link Intent ; QS Tile callback |
| TipKit / "what's new" | `WhatsNewView.swift` | DataStore key `last_seen_version` + Compose Bottom Sheet à la 1re ouverture post-update |

---

## 3. Stack technique recommandée

### SDK targets
- **`minSdk = 26`** (Android 8.0) — couvre 95%+ devices actifs en 2026 et débloque : `NotificationChannel` (obligatoire ≥ 26), `AlarmManager.setExactAndAllowWhileIdle`, `JobScheduler` mature.
- **`compileSdk = 35`** / **`targetSdk = 35`** (Android 15). Anticiper `targetSdk = 36` dès stabilisation (pour Live Updates Notification API).
- `kotlin = "2.0.21"`, `jvmTarget = 17`.

### Build & DI
- **Gradle KTS** + **Version Catalogs** (`libs.versions.toml`).
- **Hilt** : `com.google.dagger:hilt-android:2.52` — meilleur écosystème Android, KSP rapide, `@HiltAndroidApp`/`@HiltViewModel`/`@HiltWorker`. Koin écarté (DI runtime → cold start +50-100 ms).

### UI
- **Jetpack Compose BOM** `2024.10.01` + Material 3 (`androidx.compose.material3:material3:1.3.0`).
- **Compose Navigation type-safe** : `androidx.navigation:navigation-compose:2.8.3`.
- **Accompanist permissions** : `com.google.accompanist:accompanist-permissions:0.36.0`.
- **Coil 3** pour images : `io.coil-kt.coil3:coil-compose:3.0.4`.

### Async & state
- **Coroutines** + **Flow** uniquement (pas RxJava). `kotlinx-coroutines-android:1.9.0`.
- **kotlinx-datetime:0.6.1** pour manipulation de Dates côté multiplateforme-friendly.

### Persistance
- **Room** `2.6.1` (KSP) pour `ReadingEntry`, `Bookmark`, `ScheduledAlarm`, `AudioBookmark`.
- **DataStore Preferences** `1.1.1` pour settings utilisateur (offsets, méthode calcul, locale, plan Khatma compact).
- **DataStore Proto** pour `QuranPlan` (modèle complexe Codable → schéma `.proto`).

### Network & JSON
- **OkHttp 4.12.0** (cache disque 50 MB) + **Retrofit 2.11.0** + **kotlinx-serialization-converter** (Jake Wharton).
- **kotlinx-serialization-json:1.7.3** (pas Moshi, pas Gson).

### Audio
- **Media3** `1.4.1` (ExoPlayer + MediaSessionService + UI controller).

### Wear OS
- `androidx.wear.compose:compose-material3:1.4.1`
- `androidx.wear.tiles:tiles:1.4.1` + `tiles-material`
- `androidx.wear.watchface.complications.data-source:1.2.1`
- `com.google.android.gms:play-services-wearable:18.2.0`

### Widgets
- `androidx.glance:glance-appwidget:1.1.1` + `glance-material3`

### Background work
- `androidx.work:work-runtime-ktx:2.9.1` (rotation daily content, recalcul jours+14)
- `AlarmManager` direct (via `AlarmManagerCompat`) pour adhans à la seconde près

### Tests
- `junit:5.10.3` + `androidx.test.ext:junit-ktx`
- `io.mockk:mockk:1.13.13`
- `app.cash.turbine:turbine:1.1.0` (Flow tests)
- Compose UI : `androidx.compose.ui:ui-test-junit4`
- **Roborazzi** pour screenshot tests : `io.github.takahirom.roborazzi:roborazzi:1.31.0`

### Logging
- **Timber** `5.0.1` (DebugTree en debug, CrashlyticsTree en release).

### Crash & analytics
- **Firebase Crashlytics** (gratuit, indispensable pour app multi-cible Wear/widget).

---

## 4. Architecture globale

### Multi-module recommandé (≥ 50k LOC attendu côté Android avec Wear)

```
muslim-clock-android/
├── settings.gradle.kts
├── build.gradle.kts                 (plugin classpath only)
├── gradle/libs.versions.toml
├── app/                              (phone app — Application + Activity + Nav)
├── wear/                             (Wear OS module — Watch app + Tile + Complication)
├── widget/                           (séparé pour limiter recompilation Glance)
├── core/
│   ├── designsystem/                 (theme, colors, typography, CosmicBackground)
│   ├── ui/                           (composants réutilisés : DateHeader, PrayerCard…)
│   ├── data/                         (interfaces Repository — domain pur)
│   ├── domain/                       (UseCases, modèles métier purs Kotlin)
│   ├── network/                      (OkHttp client, Retrofit instances, RemoteJsonLoader)
│   ├── database/                     (Room AppDatabase + DAOs)
│   ├── datastore/                    (DataStore Preferences + Proto + AppGroupProvider)
│   ├── location/                     (FusedLocationRepository + Geocoder)
│   ├── notifications/                (AlarmScheduler, NotificationFactory, Channels)
│   ├── audio/                        (ExoPlayer wrapper, AudioCache)
│   └── testing/                      (Fakes partagés)
├── feature/
│   ├── prayer/                       (PrayerScreen, PrayerViewModel, PrayerRepository)
│   ├── qibla/                        (QiblaScreen + CompassSensor)
│   ├── adhkar/                       (morning/evening + post-prayer)
│   ├── quran/
│   │   ├── library/                  (114 sourates)
│   │   ├── reader/                   (lecteur sourate + page mapper)
│   │   ├── plan/                     (Khatma + journal)
│   │   └── recorder/                 (récitation M4A)
│   ├── podcasts/
│   ├── daily-content/                (verset + hadith)
│   └── settings/
└── benchmark/                        (Macrobenchmark : cold start, scroll)
```

**Justification multi-module** : compilation incrémentale 3-5x plus rapide ; règles d'architecture imposées par les dépendances Gradle (`feature` peut dépendre de `domain`, jamais l'inverse) ; partage `widget` ↔ `wear` ↔ `app` du module `core:domain`.

### Patterns
- **MVI léger** (sealed `UiState`, sealed `UiEvent`) pour les écrans complexes (Prayer, Quran Reader).
- **MVVM** suffisant pour écrans simples (Settings).
- **Repository pattern** : interfaces dans `core:data`, implémentations dans `core:network`/`core:location`.
- **UseCase** seulement si logique métier > 30 lignes et réutilisée par 2+ ViewModels (sinon : c'est du gold-plating selon KISS).
- **UDF strict** : ViewModel expose `StateFlow<UiState>` immutable, View envoie `UiEvent` via méthode publique.

### Couches
```
Compose UI (@Composable, @Stable)
        ↓ collectAsStateWithLifecycle
ViewModel (StateFlow<UiState>) ──── UiEvent (sealed)
        ↓ injecté via Hilt
UseCase (suspend fun / Flow)
        ↓
Repository<interface>  ←  domain
        ↓ implémenté par
RepositoryImpl ──── Retrofit / Room / DataStore / FusedLocation / Sensor / ExoPlayer
```

---

## 5. Fonctionnalités délicates — zoom détaillé

### (a) Horaires prière en background + écriture Glance Widget

**Analogie iOS** : `PrayerTimesViewModel.calculatePrayers()` recalcule puis appelle `WidgetCenter.shared.reloadAllTimelines()` (`PrayerTimesViewModel.swift:301`).

**Contrainte Android** : Doze mode bloque les wake-ups génériques ; il faut `AlarmManager.setExactAndAllowWhileIdle` (max 1/min sur API 31+ par app) ou planifier ≥ 9 min via `setAndAllowWhileIdle`. Pour 5 prières/jour x 14 jours = 70 alarmes, on les pose une à une **mais** on les regroupe en un seul recalcul daily via WorkManager.

**Libs** : `com.batoulapps.adhan:adhan2:0.1.7` (équivalent direct Swift Adhan, mêmes méthodes). Si abandonware vérifier sur Maven Central — fallback : port maison ~400 LOC (formules dans le repo `adhan-js`).

**Skeleton Kotlin** :
```kotlin
// core/domain/src/main/kotlin/.../PrayerTimesCalculator.kt
class PrayerTimesCalculator @Inject constructor() {
    fun compute(date: LocalDate, coords: Coordinates, settings: PrayerSettings): DailyPrayerTimes {
        val params = when (settings.method) {
            CalculationMethod.UOIF -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters.copy(
                fajrAngle = 12.0, ishaAngle = 12.0
            )
            CalculationMethod.ISNA -> CalculationMethod.NORTH_AMERICA.parameters
            CalculationMethod.PARIS -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters.copy(
                fajrAngle = 18.0, ishaAngle = 18.0
            )
            else -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
        }.copy(madhab = Madhab.SHAFI).apply {
            adjustments.fajr = settings.fajrOffset
            adjustments.dhuhr = settings.dhuhrOffset
            adjustments.asr = settings.asrOffset
            adjustments.maghrib = settings.maghribOffset
            if (settings.isIshaFixed) {
                ishaInterval = settings.ishaFixedDurationMin
            } else {
                adjustments.isha = settings.ishaOffset
            }
        }
        val components = DateComponents.from(date)
        val pt = PrayerTimes(coords, components, params)
        return DailyPrayerTimes(
            fajr = pt.fajr.toKotlinInstant(),
            dhuhr = pt.dhuhr.toKotlinInstant(),
            asr = pt.asr.toKotlinInstant(),
            maghrib = pt.maghrib.toKotlinInstant(),
            isha = pt.isha.toKotlinInstant(),
            sunrise = pt.sunrise.toKotlinInstant()
        )
    }
}

// app/src/main/kotlin/.../PrayerRecomputeWorker.kt
@HiltWorker
class PrayerRecomputeWorker @AssistedInject constructor(
    @Assisted ctx: Context,
    @Assisted params: WorkerParameters,
    private val locationRepo: LocationRepository,
    private val prayerRepo: PrayerTimesRepository,
    private val alarmScheduler: PrayerAlarmScheduler,
) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result = runCatching {
        val coords = locationRepo.lastKnown() ?: return Result.retry()
        val today = Clock.System.todayIn(TimeZone.currentSystemDefault())
        val days = (0..13).map { today.plus(it, DateTimeUnit.DAY) }
        val plan = days.map { d -> prayerRepo.compute(d, coords) }

        prayerRepo.saveToDataStore(plan)            // pour Glance widget
        alarmScheduler.replaceAdhanAlarms(plan)     // 5*14 = 70 alarmes
        GlanceAppWidgetManager(applicationContext).updateAll<PrayerCircleWidget>()
        Result.success()
    }.getOrElse { Result.retry() }
}

// Schedule daily at 02:00 local
WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(
    "prayer-daily-recompute",
    ExistingPeriodicWorkPolicy.KEEP,
    PeriodicWorkRequestBuilder<PrayerRecomputeWorker>(1, TimeUnit.DAYS)
        .setInitialDelay(durationUntil(LocalTime(2, 0)).inWholeMinutes, TimeUnit.MINUTES)
        .setConstraints(Constraints(requiresBatteryNotLow = false))
        .build()
)
```

### (b) Wear OS sync — équivalent WatchConnectivity

**Analogie iOS** : `WatchSessionManager.sendPrayerTimes` via `transferUserInfo` queue.

**Android** : `DataClient.putDataItem(...)` met les données dans une queue répliquée automatiquement. **Limite** : 100 KB par DataItem, donc on envoie un seul item compact (binaire), pas dictionnaire par dictionnaire.

```kotlin
// app/src/main/kotlin/.../WearSyncRepository.kt
class WearSyncRepository @Inject constructor(@ApplicationContext ctx: Context) {
    private val client = Wearable.getDataClient(ctx)

    suspend fun syncPrayerTimes(times: DailyPrayerTimes, settings: PrayerSettings) {
        val request = PutDataMapRequest.create("/prayer-times").apply {
            dataMap.putLong("fajr", times.fajr.toEpochMilliseconds())
            dataMap.putLong("dhuhr", times.dhuhr.toEpochMilliseconds())
            dataMap.putLong("asr", times.asr.toEpochMilliseconds())
            dataMap.putLong("maghrib", times.maghrib.toEpochMilliseconds())
            dataMap.putLong("isha", times.isha.toEpochMilliseconds())
            dataMap.putLong("tomorrow_fajr", times.tomorrowFajr.toEpochMilliseconds())
            dataMap.putBoolean("jumuah_enabled", settings.jumuahEnabled)
            dataMap.putInt("jumuah_hour", settings.jumuahHour)
            dataMap.putInt("jumuah_minute", settings.jumuahMinute)
        }.asPutDataRequest().setUrgent()
        client.putDataItem(request).await()
    }
}

// wear/src/main/kotlin/.../PrayerDataListenerService.kt
class PrayerDataListenerService : WearableListenerService() {
    @Inject lateinit var prayerStore: WearPrayerStore

    override fun onDataChanged(events: DataEventBuffer) {
        events.filter { it.dataItem.uri.path == "/prayer-times" }.forEach { ev ->
            val map = DataMapItem.fromDataItem(ev.dataItem).dataMap
            runBlocking {
                prayerStore.update(WearPrayerTimes(
                    fajr = Instant.fromEpochMilliseconds(map.getLong("fajr")),
                    /* ... */
                ))
            }
        }
    }
}
```

### (c) Live Activity → ongoing notification (sous Android 16) / Notification Live Updates API (16+)

**Analogie iOS** : Bannière compte à rebours auto-updatée 30 min avant prière, "stale date" auto-end.

**Contrainte Android** :
- Avant Android 16 (API 36) : pas de "Live Updates" natif → on utilise une **notification ongoing** avec `setUsesChronometer(true)` + `setChronometerCountDown(true)` (API 24+) ou un `Chronometer` custom dans `setCustomContentView()`.
- Android 16+ : **Notification Live Updates API** (à confirmer, doc preview en 2026) — promotion sur Lock Screen.

```kotlin
// core/notifications/src/main/kotlin/.../PrayerLiveNotification.kt
class PrayerLiveNotification @Inject constructor(@ApplicationContext private val ctx: Context) {

    companion object {
        const val CHANNEL_ID = "prayer_live"
        const val ONGOING_ID = 4242
        val ANNOUNCE_WINDOW = 30.minutes
        val POST_PRAYER_LINGER = 5.minutes
    }

    init { createChannel() }

    private fun createChannel() {
        val ch = NotificationChannel(
            CHANNEL_ID, ctx.getString(R.string.channel_prayer_live),
            NotificationManager.IMPORTANCE_LOW
        ).apply { setShowBadge(false) }
        ctx.getSystemService<NotificationManager>()!!.createNotificationChannel(ch)
    }

    fun showIfInWindow(prayer: PrayerName, targetTime: Instant) {
        val now = Clock.System.now()
        val until = targetTime - now
        if (until.isNegative() || until > ANNOUNCE_WINDOW) {
            // Hors fenêtre — cancel pour éviter notif obsolète
            NotificationManagerCompat.from(ctx).cancel(ONGOING_ID)
            return
        }

        val builder = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(prayer.iconRes)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setColor(ctx.getColor(R.color.accent_prayer))
            .setContentTitle(ctx.getString(prayer.displayRes))
            .setContentText(ctx.getString(R.string.prayer_starts_in))
            // Compte à rebours natif (API 24+)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(targetTime.toEpochMilliseconds())
            .setShowWhen(true)
            .setContentIntent(buildOpenAppPendingIntent())
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        NotificationManagerCompat.from(ctx).notify(ONGOING_ID, builder.build())

        // Auto-end après linger (Android 16 : remplacer par Live Updates API)
        WorkManager.getInstance(ctx).enqueueUniqueWork(
            "prayer-live-end",
            ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<EndPrayerLiveWorker>()
                .setInitialDelay(
                    (until + POST_PRAYER_LINGER).inWholeMilliseconds,
                    TimeUnit.MILLISECONDS
                ).build()
        )
    }
}
```

**Limite UX** : pas d'équivalent Dynamic Island sur Android. La notification ongoing fait office, mais l'utilisateur peut la swipe-away. Mitigation : la re-poster à chaque évolution via `WorkManager`.

### (d) Boussole Qibla — SensorManager + low-pass + declinaison magnétique

**Analogie iOS** : `CompassManager.didUpdateHeading` reçoit `trueHeading` direct de iOS (calibration auto + déclinaison incluse).

**Contrainte Android** : `TYPE_ROTATION_VECTOR` donne le heading via quaternion, mais `magneticHeading` brut → il faut soustraire la déclinaison magnétique via `GeomagneticField`. **Low-pass filter obligatoire** (signal bruyant à 50 Hz, jitter ±5°).

```kotlin
// feature/qibla/src/main/kotlin/.../CompassSensor.kt
class CompassSensor @Inject constructor(@ApplicationContext private val ctx: Context) {

    private val sensorManager = ctx.getSystemService<SensorManager>()!!
    private val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    /// Heading lissé en degrés (0..360) — true north (incl. déclinaison)
    private val _heading = MutableStateFlow(0.0)
    val heading: StateFlow<Double> = _heading.asStateFlow()

    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private var smoothed: Double = 0.0
    private var declination: Float = 0f

    fun setLocation(lat: Double, lon: Double, altMeters: Double = 0.0) {
        declination = GeomagneticField(
            lat.toFloat(), lon.toFloat(), altMeters.toFloat(),
            System.currentTimeMillis()
        ).declination
    }

    private val listener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) return
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            SensorManager.getOrientation(rotationMatrix, orientation)
            // azimuth en radians, -π..π — 0 = pointe vers nord magnétique
            val azimuthDeg = Math.toDegrees(orientation[0].toDouble())
            val trueNorthDeg = (azimuthDeg + declination + 360.0) % 360.0
            // Low-pass exponentiel (α=0.15 — équilibre réactivité/lissage)
            smoothed = lerpAngle(smoothed, trueNorthDeg, alpha = 0.15)
            _heading.value = smoothed
        }
        override fun onAccuracyChanged(s: Sensor?, a: Int) = Unit
    }

    fun start() = sensorManager.registerListener(
        listener, rotationSensor, SensorManager.SENSOR_DELAY_UI
    )
    fun stop() = sensorManager.unregisterListener(listener)

    private fun lerpAngle(from: Double, to: Double, alpha: Double): Double {
        val diff = ((to - from + 540.0) % 360.0) - 180.0  // shortest path -180..180
        return (from + diff * alpha + 360.0) % 360.0
    }
}

// Qibla bearing — formule sphérique identique iOS
object QiblaMath {
    private const val MECCA_LAT = 21.4225
    private const val MECCA_LON = 39.8262
    fun bearing(fromLat: Double, fromLon: Double): Double {
        val latA = Math.toRadians(fromLat)
        val lonA = Math.toRadians(fromLon)
        val latB = Math.toRadians(MECCA_LAT)
        val lonB = Math.toRadians(MECCA_LON)
        val dLon = lonB - lonA
        val y = sin(dLon) * cos(latB)
        val x = cos(latA) * sin(latB) - sin(latA) * cos(latB) * cos(dLon)
        return (Math.toDegrees(atan2(y, x)) + 360.0) % 360.0
    }
}
```

**Haptique progressif** (mapping iOS `CompassManager.swift:69-103`) :
```kotlin
fun feedback(level: Int, vibrator: Vibrator) {
    val effect = when (level) {
        1 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
        2 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
        3 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
        4 -> VibrationEffect.createWaveform(longArrayOf(0, 80, 60, 60), -1)
        else -> return
    }
    vibrator.vibrate(effect)
}
```

### (e) Audio podcast resilient — ExoPlayer + MediaSessionService + bookmarks

**Analogie iOS** : `PodcastManager` (1100 LOC) avec `AVPlayer` + `MPNowPlayingInfoCenter` + cache disque + bookmarks scopés par série.

**Android** : Media3 fait 80% du boulot (cache + MediaSession + Now Playing auto + notification controls).

```kotlin
// core/audio/src/main/kotlin/.../PodcastService.kt
@AndroidEntryPoint
class PodcastService : MediaSessionService() {

    @Inject lateinit var bookmarkRepo: PodcastBookmarkRepository
    private lateinit var player: ExoPlayer
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val cacheDir = File(cacheDir, "podcast-cache")
        val cache = SimpleCache(
            cacheDir,
            LeastRecentlyUsedCacheEvictor(500L * 1024 * 1024),     // 500 MB
            StandaloneDatabaseProvider(this)
        )
        val cacheFactory = CacheDataSource.Factory()
            .setCache(cache)
            .setUpstreamDataSourceFactory(DefaultHttpDataSource.Factory())
            .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)

        player = ExoPlayer.Builder(this)
            .setMediaSourceFactory(DefaultMediaSourceFactory(this).setDataSourceFactory(cacheFactory))
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .build()
            .apply {
                addListener(BookmarkListener(bookmarkRepo))   // sauve position toutes les 10s
            }

        mediaSession = MediaSession.Builder(this, player).build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo) = mediaSession

    override fun onDestroy() {
        mediaSession?.run { player.release(); release() }; mediaSession = null
        super.onDestroy()
    }
}

@Entity(tableName = "podcast_bookmarks")
data class PodcastBookmark(
    @PrimaryKey val seriesId: String,
    val episodeUrl: String,
    val positionMs: Long,
    val episodeTitle: String,
    val updatedAt: Long,
)
```

Au lieu de re-parser XML RSS comme iOS, on stocke le JSON normalisé côté repository. Pour les playlists custom (S3/Firebase, cf. `PodcastManager.swift:28-39`), même code path.

### (f) Daily content rotation — WorkManager scheduled minuit local

**Analogie iOS** : `DailyContentService.fetchDailyContent()` appelé à chaque `task` (problème noté dans memory : rotation à chaque cold start, pas 1x/jour).

**Android — opportunité de fix** : faire vraiment 1 rotation/jour.

```kotlin
// feature/daily-content/.../DailyContentRotator.kt
@HiltWorker
class DailyContentRotator @AssistedInject constructor(
    @Assisted ctx: Context, @Assisted params: WorkerParameters,
    private val service: DailyContentService,
) : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result {
        return runCatching {
            val today = LocalDate.now(ZoneId.systemDefault()).toString()
            val seed = today.hashCode()                    // déterministe par jour
            service.rotateForSeed(seed)                    // pick verset + hadith stables
            Result.success()
        }.getOrElse { Result.retry() }
    }

    companion object {
        fun schedule(ctx: Context) {
            val now = ZonedDateTime.now()
            val nextMidnight = now.toLocalDate().plusDays(1).atStartOfDay(now.zone)
            val delay = Duration.between(now, nextMidnight).toMillis()
            WorkManager.getInstance(ctx).enqueueUniquePeriodicWork(
                "daily-content-rotation",
                ExistingPeriodicWorkPolicy.UPDATE,
                PeriodicWorkRequestBuilder<DailyContentRotator>(1, TimeUnit.DAYS)
                    .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                    .setConstraints(Constraints(requiredNetworkType = NetworkType.CONNECTED))
                    .build()
            )
        }
    }
}
```

### (g) Calendrier Umm Al-Qura

**iOS** : `Calendar(identifier: .islamicUmmAlQura)` natif.

**Android** : `HijrahChronology` natif (java.time, API 26+) **N'EST PAS** Umm Al-Qura — c'est l'algorithme arithmétique Tabular. Différence ±1-2 jours fréquents. **Mitigation** :

- Lib **`com.github.msarhan:ummalqura-calendar:1.1.7`** (port Java officiel KSA — couverture 1300-1500 H).
- OU : pour la **détection mois hégirien grossière** (saisons Ramadan/Hajj), `HijrahChronology` suffit (différence d'1 jour acceptable au début/fin de mois).
- Pour les **dates précises affichées** (header "17 Ramadan 1447"), utiliser `ummalqura-calendar`.

```kotlin
fun hijriToday(): HijriDate {
    val ummAlQura = UmmalquraCalendar.getInstance().apply { time = Date() }
    return HijriDate(
        year = ummAlQura.get(Calendar.YEAR),
        month = ummAlQura.get(Calendar.MONTH) + 1,
        day = ummAlQura.get(Calendar.DAY_OF_MONTH),
        monthNameAr = ARABIC_MONTHS[ummAlQura.get(Calendar.MONTH)],
        monthNameFr = FRENCH_MONTHS[ummAlQura.get(Calendar.MONTH)],
    )
}
```

---

## 6. Considérations performance

### Cold start < 2 s
- **`Application.onCreate()` minimal** : Hilt + Timber + NotificationChannels. **Aucune I/O.**
- DataStore : `dataStoreScope` lazy via `dataStore` delegate, lecture en `Flow.collect` côté UI uniquement.
- Aucun fetch réseau bloquant : tout en `LaunchedEffect` ou `WorkManager`.
- **App Startup library** (`androidx.startup:startup-runtime:1.2.0`) pour initialiser explicitement Crashlytics, WorkManager.
- **Baseline Profile** : générer via Macrobenchmark, embarquer → cold start -25%.

### Recomposition Compose
- `@Stable` / `@Immutable` sur tous les UiState data classes.
- `derivedStateOf` pour valeurs dérivées (ex: `remainingMinutes` depuis `nextPrayerInstant`).
- `key(prayer.id)` dans `LazyColumn { items(prayers, key = { it.id }) { ... } }`.
- Pas de `Modifier.composed { ... }` (déprécié, perf). Préférer `Modifier.Node`.
- **Compose Compiler reports** activés en CI pour détecter restartable/skippable régressions.

### Background budget
- **AlarmManager exact** : justifier l'usage de `USE_EXACT_ALARM` permission (Play Console review obligatoire) ; sur API 31+, `SCHEDULE_EXACT_ALARM` peut être révoqué par user → fallback gracieux sur notif inexacte.
- **Doze mode** : tester avec `adb shell dumpsys deviceidle force-idle`.
- **Manufacturer killers** (Xiaomi MIUI, Huawei EMUI, OnePlus OxygenOS) : ajouter dialog "Désactiver l'optimisation batterie" via `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` au premier lancement (consentement RGPD-friendly).

### Batterie
- FusedLocation `Priority.PRIORITY_BALANCED_POWER_ACCURACY` (équivalent `kCLLocationAccuracyThreeKilometers`) ; passage à `PRIORITY_HIGH_ACCURACY` **uniquement** quand QiblaScreen est visible.
- ExoPlayer : `setHandleAudioBecomingNoisy(true)` ; libérer le player en `onStop()` si plus de session active.

### Memory
- JSON Coran : pas de chargement synchrone du fichier complet. `QuranLibraryLoader` doit charger sourate-par-sourate à la demande (déjà le cas côté iOS via `risan/quran-json` qui découpe par sourate).
- `quran-page-mapping.json` (30 KB) : charger 1x au démarrage du module Quran, garder en singleton (`@Singleton`).

### Glance Widget — 5 MB RemoteViews limit
- Pas d'images bitmap > 256 KB dans le widget.
- Préférer `GlanceModifier.background(ColorProvider)` à des Drawables custom.
- 1 `WidgetReceiver` par taille (small, medium, circle) au lieu d'1 mega-widget configurable.

---

## 7. Structure de projet concrète

```
muslim-clock-android/
├── settings.gradle.kts
├── build.gradle.kts
├── gradle/libs.versions.toml
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/com/kappsi/muslimclock/
│           ├── MuslimClockApp.kt                       # @HiltAndroidApp
│           ├── MainActivity.kt
│           ├── navigation/
│           │   ├── AppNavHost.kt
│           │   └── Destinations.kt
│           └── di/
│               ├── AppModule.kt
│               ├── NetworkModule.kt
│               └── DatabaseModule.kt
├── core/
│   ├── designsystem/src/main/kotlin/com/kappsi/muslimclock/designsystem/
│   │   ├── theme/Color.kt
│   │   ├── theme/Typography.kt
│   │   ├── theme/Theme.kt
│   │   ├── component/PrayerCard.kt
│   │   ├── component/DateHeader.kt
│   │   ├── component/CosmicBackground.kt           # AGSL shader si API 33+, sinon radial gradient
│   │   ├── component/NetworkBanner.kt
│   │   └── icons/MaterialSymbols.kt                # mapping SF Symbols → Material Symbols
│   ├── domain/src/main/kotlin/com/kappsi/muslimclock/domain/
│   │   ├── prayer/
│   │   │   ├── model/PrayerName.kt
│   │   │   ├── model/PrayerSettings.kt
│   │   │   ├── model/DailyPrayerTimes.kt
│   │   │   ├── PrayerTimesCalculator.kt
│   │   │   └── PrayerWindow.kt
│   │   ├── location/Coordinates.kt
│   │   ├── quran/
│   │   │   ├── model/QuranChapter.kt
│   │   │   ├── model/QuranPlan.kt
│   │   │   ├── QuranPageMapper.kt
│   │   │   └── QuranPlanMath.kt
│   │   ├── season/IslamicSeasonInfo.kt
│   │   └── adhkar/Dhikr.kt
│   ├── data/                                       # interfaces Repository
│   │   └── src/main/kotlin/.../data/repository/
│   │       ├── PrayerTimesRepository.kt
│   │       ├── LocationRepository.kt
│   │       ├── QuranLibraryRepository.kt
│   │       ├── AdhkarRepository.kt
│   │       ├── DailyContentRepository.kt
│   │       ├── PodcastRepository.kt
│   │       ├── WeatherRepository.kt
│   │       └── SettingsRepository.kt
│   ├── network/
│   │   ├── di/NetworkModule.kt                     # OkHttp + Retrofit
│   │   ├── RemoteJsonLoader.kt                     # 3-tier cache (net→disk→assets)
│   │   ├── AlquranCloudApi.kt
│   │   ├── QuranJsonApi.kt
│   │   ├── OpenMeteoApi.kt
│   │   └── NetworkMonitor.kt
│   ├── database/
│   │   ├── AppDatabase.kt                          # Room
│   │   ├── dao/ReadingEntryDao.kt
│   │   ├── dao/PodcastBookmarkDao.kt
│   │   ├── dao/ScheduledAlarmDao.kt
│   │   └── entity/...
│   ├── datastore/
│   │   ├── SettingsDataStore.kt                    # Preferences
│   │   ├── QuranPlanDataStore.kt                   # Proto
│   │   └── AppGroupProvider.kt                     # ContentProvider exposant DataStore multiprocess
│   ├── location/
│   │   ├── FusedLocationRepositoryImpl.kt
│   │   └── CityGeocoder.kt
│   ├── notifications/
│   │   ├── NotificationChannels.kt                 # init au boot
│   │   ├── PrayerAlarmScheduler.kt                 # AlarmManager exact
│   │   ├── PrayerLiveNotification.kt               # ongoing chronometer
│   │   ├── AdhkarReminderScheduler.kt
│   │   ├── QuranReminderScheduler.kt
│   │   ├── NewMoonScheduler.kt
│   │   └── PrayerAlarmReceiver.kt                  # BroadcastReceiver triggered by AlarmManager
│   └── audio/
│       ├── PodcastService.kt                       # MediaSessionService + ExoPlayer
│       ├── BookmarkListener.kt
│       └── AudioCacheModule.kt                     # SimpleCache 500 MB
├── feature/
│   ├── prayer/
│   │   ├── PrayerScreen.kt
│   │   ├── PrayerViewModel.kt
│   │   ├── PrayerUiState.kt
│   │   ├── PrayerEvent.kt
│   │   └── component/CurrentPrayerGauge.kt
│   ├── qibla/
│   │   ├── QiblaScreen.kt
│   │   ├── QiblaViewModel.kt
│   │   └── CompassSensor.kt
│   ├── adhkar/
│   │   ├── morning_evening/AdhkarScreen.kt
│   │   ├── morning_evening/AdhkarViewModel.kt
│   │   ├── post_prayer/PostPrayerAdhkarScreen.kt
│   │   └── data/AdhkarLocalDataSource.kt
│   ├── quran/
│   │   ├── library/QuranLibraryScreen.kt
│   │   ├── library/QuranLibraryViewModel.kt
│   │   ├── reader/ChapterDetailScreen.kt
│   │   ├── reader/ChapterDetailViewModel.kt
│   │   ├── plan/PlanSetupScreen.kt
│   │   ├── plan/PlanProgressScreen.kt
│   │   ├── plan/TrackerScreen.kt
│   │   └── recorder/RecorderScreen.kt
│   ├── podcasts/
│   │   ├── MiniPlayerBar.kt
│   │   ├── FullPlayerScreen.kt
│   │   └── PodcastsViewModel.kt
│   ├── daily-content/
│   │   ├── DailyContentScreen.kt
│   │   ├── DailyContentViewModel.kt
│   │   └── DailyContentRotator.kt                  # WorkManager
│   └── settings/
│       ├── SettingsScreen.kt
│       ├── SettingsViewModel.kt
│       ├── SmartSetupScreen.kt
│       └── DonationScreen.kt
├── widget/
│   ├── build.gradle.kts
│   └── src/main/kotlin/com/kappsi/muslimclock/widget/
│       ├── PrayerCircleWidget.kt                   # Glance
│       ├── PrayerSmallWidget.kt
│       ├── PrayerLargeWidget.kt
│       ├── DailyVerseWidget.kt
│       └── tile/QiblaQuickTile.kt                  # QS Tile
└── wear/
    ├── build.gradle.kts
    └── src/main/kotlin/com/kappsi/muslimclock/wear/
        ├── WearMuslimClockApp.kt
        ├── MainActivity.kt
        ├── screen/PrayerScreen.kt                  # Compose for Wear
        ├── screen/QiblaScreen.kt
        ├── tile/PrayerTile.kt                      # Wear Tile
        ├── complication/NextPrayerComplication.kt  # ComplicationDataSourceService
        └── sync/PrayerDataListenerService.kt
```

---

## 8. Plan de livraison en phases

Estimations en jours-homme (1 dev senior plein temps). Total : **~95-115 jours-homme** (≈ 22 semaines).

### Phase 1 — MVP Prayer (12-15 jh)
- Setup projet multi-module, Gradle KTS, Version Catalogs, Hilt.
- Theme Compose Material 3 + dark mode forcé (parité iOS).
- `LocationRepository` (FusedLocation + permission rationale).
- Adhan2 integration + `PrayerTimesCalculator` + 4 méthodes (UOIF/ISNA/MWL/Paris).
- `PrayerScreen` (horloge, date hijri+grégorien, liste 5 prières, prochaine prière, jauge fenêtre courante).
- `SettingsScreen` minimal (méthode calcul + offsets).
- DataStore Preferences.
- **Livrable** : APK installable, prière calculée pour position GPS, settings persistés.

### Phase 2 — Qibla + Adhkar + Daily content (10-12 jh)
- `CompassSensor` + Qibla bearing + haptique progressif 4 paliers.
- `AdhkarScreen` matin/soir (period detection Fajr→Asr / Asr→Fajr+4h, persistance Room).
- `PostPrayerAdhkarScreen` (filtrage par prière courante).
- `DailyContentScreen` (verset + hadith) + `DailyContentRotator` WorkManager.
- `RemoteJsonLoader` (3-tier cache : OkHttp → disk → assets).
- `IslamicSeasonInfo` (12 mois lunaires) + bandeau saisonnier.
- **Livrable** : 4 onglets de l'app fonctionnels (sans podcast et sans Coran).

### Phase 3 — Notifications + Glance Widgets (10-12 jh)
- `PrayerAlarmScheduler` (70 alarmes via AlarmManager exact + persistance Room).
- 4 NotificationChannels (adhan, adhkar_reminder, quran_reading, new_moon).
- `PrayerAlarmReceiver` + overlay activity transparent pour reproduire l'Adhan plein écran.
- `AdhkarReminderScheduler` + `QuranReminderScheduler` + `NewMoonScheduler`.
- `PrayerLiveNotification` (ongoing chronometer 30 min avant prière).
- Glance widgets : Circle, Small, Large (lecture DataStore via AppGroupProvider).
- QS Tiles : Qibla, Adhkar (équivalent Control Widgets).
- **Livrable** : app autonome, fonctionne sans avoir besoin d'être ouverte.

### Phase 4 — Audio (Podcasts + Coran recorder) (12-15 jh)
- `PodcastService` (MediaSessionService + ExoPlayer + SimpleCache 500 MB).
- `MiniPlayerBar` + `FullPlayerScreen` + bookmarks Room.
- Pop-up fin de série + Google Play In-App Review.
- `QuranRecorder` (MediaRecorder M4A AAC 32 kbps, max 10 min, markers versets).
- Pause auto podcast pendant Adhan + reprise auto.
- **Livrable** : lecteur audio + recorder pleinement opérationnels.

### Phase 5 — Coran complet (15-18 jh)
- `QuranLibraryRepository` (jsDelivr `risan/quran-json@3.1.2` + cache mémoire LruCache 30 sourates + cache disque).
- `QuranLibraryScreen` (114 sourates, search, filtre Meccan/Medinan).
- `ChapterDetailScreen` (lecture Amiri font, traduction, translittération, basmala manuelle pour 2-114 sauf 9, audio Alafasy).
- `QuranPageMapper` (binaire O(log 604), assets `quran-page-mapping.json`).
- `QuranPlan` proto DataStore + setup wizard 3 modes (durée/pages/date).
- `ReadingEntry` Room + heatmap + streak + balance (avance/retard).
- **Livrable** : module Coran iso-iOS.

### Phase 6 — Wear OS (15-18 jh)
- Module `wear` Compose for Wear Material 3.
- `PrayerDataListenerService` (Data Layer API sync).
- Wear `PrayerScreen` + `QiblaScreen` minimaux.
- `PrayerTile` (Wear Tile) — équivalent complication ClockKit modular.
- `NextPrayerComplication` (ComplicationDataSourceService — pour watchfaces tiers).
- **Livrable** : compagnon Wear OS (Galaxy Watch 5+, Pixel Watch).

### Phase 7 — Polish + Donation IAP + Release (8-10 jh)
- `AppUpdateManager` Play In-App Updates.
- `DonationScreen` Google Play Billing (StoreKit consumable IAP iOS → équivalent Android : `com.android.billingclient:billing-ktx:7.1.1` produits consumables).
- WhatsNewScreen post-update.
- Localisation FR + AR (`values-ar/strings.xml`).
- Macrobenchmark + Baseline Profile (cold start, scroll Quran).
- Crashlytics + Play Store assets (screenshots, captions, video preview).
- Testing : 70+ tests unit + 15+ Compose UI tests.
- **Livrable** : release-candidate Google Play.

### Optionnel Phase 8 — Live Updates API Android 16+ (3-5 jh)
- Migration `PrayerLiveNotification` vers `NotificationCompat.Builder.setLiveUpdate(...)` quand l'API se stabilise (preview en 2026, GA attendu).
- Tests A/B vs ongoing classique.

---

## 9. Pièges spécifiques à anticiper

### Calendrier Umm Al-Qura
- `HijrahChronology` natif Java ≠ Umm Al-Qura officiel KSA. Différences ±1 jour fréquentes en début/fin de mois.
- **Mitigation** : `com.github.msarhan:ummalqura-calendar:1.1.7` (couverture 1300H-1500H, suffit jusqu'à 2079).
- Le calendrier Umm Al-Qura est fixé par décret saoudien — il *peut* être révisé. Anticiper une mise à jour de lib annuelle.

### Pas d'App Group
- iOS partage des données via `UserDefaults(suiteName:)`. Android n'a pas ça.
- **Solution propre** : créer un `ContentProvider` exposant un DataStore. Cible : app principale + widget + wear (Wear sync via Data Layer, pas ContentProvider).
- **Solution rapide (KISS)** : `SharedPreferences` avec `MODE_MULTI_PROCESS` (déprécié mais fonctionnel pour widgets). À éviter en 2026.

### Wear OS vs watchOS
- Wear OS pas d'app standalone par défaut : Bluetooth/WiFi requis tant que `installType="standalone"` n'est pas déclaré.
- Pour standalone : ajouter dans `wear/AndroidManifest.xml`: `<meta-data android:name="com.google.android.wearable.standalone" android:value="true" />` + permissions location/internet côté wear.
- Connectivité Wear : Galaxy Watch 4+/Pixel Watch ont Wear OS 3+/4+ ; Wear OS 2 (legacy) ignoré (part de marché < 5%).
- Pas de complication "modular" à l'identique ; ComplicationDataSourceService est moins riche que ClockKit (4 templates max : `SHORT_TEXT`, `LONG_TEXT`, `RANGED_VALUE`, `MONOCHROMATIC_IMAGE`).

### Glance Widgets — limitations
- **Pas de SwiftUI-like animations** ; recompositions limitées (Glance compile en RemoteViews → DSL restreint).
- **Pas de Live Activity équivalent natif avant Android 16** (Notification Live Updates API en preview).
- **5 MB RemoteViews limit** : pas d'image bitmap lourde, pas de `Spacer(modifier = GlanceModifier.size(Dp.Unspecified))` qui font allouer du temp.
- Le widget circle iOS Qibla → impossible en Glance (pas de canvas custom). Alternative : SVG-like via `androidx.glance.appwidget.cornerRadius` + plusieurs Box rotated. Pour Qibla on bascule sur un widget "Prochaine prière" textuel.

### Notifications obligatoires
- `NotificationChannel` obligatoires API 26+. Bien créer **4 channels** distincts (adhan IMPORTANCE_HIGH, adhkar LOW, quran DEFAULT, new_moon LOW) pour permettre à l'utilisateur de couper chacun individuellement (UX Android attendue).
- **API 33+** : permission `POST_NOTIFICATIONS` runtime à demander.
- **API 31+** : permission `SCHEDULE_EXACT_ALARM` ou `USE_EXACT_ALARM`. La première est révocable par user ; la seconde requiert review Play Console (justification "alarm clock or scheduling app" — la prière entre dans cette catégorie).

### RTL Arabic
- `android:supportsRtl="true"` dans manifest.
- Compose : `LocalLayoutDirection` ; pour forcer un texte en RTL : `CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl)`.
- Police Amiri pour arabe Coran : `R.font.amiri_quran` + `FontFamily(Font(R.font.amiri_quran))`. Vérifier le rendu des diacritiques Uthmani (certains devices Samsung tronquent le tashkeel).

### Battery optimizations agressives (manufacturer-specific)
- Xiaomi MIUI, Huawei EMUI, OnePlus, Oppo — tuent l'app après quelques heures même avec exact alarms.
- **Mitigation obligatoire** : dialog au 1er lancement → `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- Documenter dans `WhatsNewScreen` ou onboarding ("Si vous utilisez Xiaomi/Huawei, suivez ces étapes…").

### Adhan-Kotlin maturité
- `com.batoulapps.adhan:adhan2:0.1.7` (port Kotlin). Vérifier dispo Maven Central avant phase 1.
- **Si abandonware** : port maison depuis `adhan-js` (~400 LOC, formules astronomiques publiques). Pas critique — Adhan est une lib pure Date/maths.
- Méthodes nommées différemment côté Kotlin : `CalculationMethod.MUSLIM_WORLD_LEAGUE`, pas `.muslimWorldLeague`.

### Hijri date formatting localisé
- `DateTimeFormatter.ofPattern("d MMMM yyyy", Locale("ar"))` avec `HijrahChronology.INSTANCE.localizedBy(Locale("ar-SA"))` : fonctionnel mais l'ordre RTL peut surprendre.
- **Tester** sur device arabe : "١٧ رجب ١٤٤٧" vs notre rendu.

### MediaSession + Adhan interruption
- iOS gère via `AVAudioSession.setCategory(.ambient)` automatique.
- Android : si podcast joue et alarme adhan se déclenche, le `MediaSessionService` continue. Solution : `AudioFocusRequest` ou écoute du `BroadcastReceiver` de l'alarm et pause manuelle du player. À tester soigneusement.

### Adhan audio recording
- M4A AAC OK sur tous Android. **Mais** : sur Samsung One UI, `MediaRecorder` capture parfois en 16 kHz au lieu de 44.1 kHz si on ne set pas explicitement `setAudioSamplingRate(44100)`. À vérifier.

---

## 10. Risques & mitigations (résumé)

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| Adhan-Kotlin abandonware | Moyen | Élevé | Port maison ~400 LOC, formules publiques |
| Umm Al-Qura différe natif | Élevé | Moyen | Lib `ummalqura-calendar` |
| Battery killers Xiaomi/Huawei | Élevé | Élevé | Dialog ignore-battery-opt au onboarding |
| `USE_EXACT_ALARM` Play Console refusé | Faible | Élevé | Justification claire ("prayer alarm clock") + fallback inexact alarm |
| Glance Widget < 5 MB RemoteViews | Moyen | Moyen | Audit visuel + Macrobenchmark assets |
| Live Updates API non finalisée API 36 | Élevé | Faible | Garder ongoing notification chronometer comme baseline |
| Wear OS API differences (Tile vs Complication) | Moyen | Moyen | Implémenter Tile en priorité (UX plus riche), Complication en V2 |
| Diacritiques Amiri rendus tronqués sur Samsung | Moyen | Moyen | Tester sur Galaxy S22+ ; fallback Noto Naskh Arabic |
| iTunes Lookup → équivalent Android ? | Faible | Faible | Play In-App Updates API (officielle) |
| Sync iOS↔Android settings | Faible | Faible | Hors scope ; Firebase Auth en V3 si demandé |

---

## Annexes — coordonnées Gradle (extrait `libs.versions.toml`)

```toml
[versions]
agp = "8.7.1"
kotlin = "2.0.21"
ksp = "2.0.21-1.0.27"
composeBom = "2024.10.01"
hilt = "2.52"
work = "2.9.1"
room = "2.6.1"
datastore = "1.1.1"
media3 = "1.4.1"
glance = "1.1.1"
wearCompose = "1.4.1"
wearTiles = "1.4.1"
playLocation = "21.3.0"
playWearable = "18.2.0"
playReview = "2.0.2"
playUpdate = "2.1.0"
playBilling = "7.1.1"
adhan = "0.1.7"
ummalqura = "1.1.7"
coil = "3.0.4"
okhttp = "4.12.0"
retrofit = "2.11.0"
serialization = "1.7.3"
timber = "5.0.1"
junit5 = "5.10.3"
mockk = "1.13.13"
turbine = "1.1.0"

[libraries]
adhan = { module = "com.batoulapps.adhan:adhan2", version.ref = "adhan" }
ummalqura-calendar = { module = "com.github.msarhan:ummalqura-calendar", version.ref = "ummalqura" }
hilt-android = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-work = { module = "androidx.hilt:hilt-work", version = "1.2.0" }
glance-appwidget = { module = "androidx.glance:glance-appwidget", version.ref = "glance" }
glance-material3 = { module = "androidx.glance:glance-material3", version.ref = "glance" }
wear-compose-material3 = { module = "androidx.wear.compose:compose-material3", version.ref = "wearCompose" }
wear-tiles = { module = "androidx.wear.tiles:tiles", version.ref = "wearTiles" }
wear-watchface-complications-datasource-ktx = { module = "androidx.wear.watchface:watchface-complications-data-source-ktx", version = "1.2.1" }
play-location = { module = "com.google.android.gms:play-services-location", version.ref = "playLocation" }
play-wearable = { module = "com.google.android.gms:play-services-wearable", version.ref = "playWearable" }
play-review-ktx = { module = "com.google.android.play:review-ktx", version.ref = "playReview" }
play-update-ktx = { module = "com.google.android.play:app-update-ktx", version.ref = "playUpdate" }
play-billing-ktx = { module = "com.android.billingclient:billing-ktx", version.ref = "playBilling" }
media3-exoplayer = { module = "androidx.media3:media3-exoplayer", version.ref = "media3" }
media3-session = { module = "androidx.media3:media3-session", version.ref = "media3" }
media3-datasource-okhttp = { module = "androidx.media3:media3-datasource-okhttp", version.ref = "media3" }
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
room-ktx = { module = "androidx.room:room-ktx", version.ref = "room" }
datastore-preferences = { module = "androidx.datastore:datastore-preferences", version.ref = "datastore" }
datastore-proto = { module = "androidx.datastore:datastore", version.ref = "datastore" }
okhttp = { module = "com.squareup.okhttp3:okhttp", version.ref = "okhttp" }
retrofit = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
retrofit-kotlinx-serialization = { module = "com.jakewharton.retrofit:retrofit2-kotlinx-serialization-converter", version = "1.0.0" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "serialization" }
work-runtime-ktx = { module = "androidx.work:work-runtime-ktx", version.ref = "work" }
timber = { module = "com.jakewharton.timber:timber", version.ref = "timber" }
coil-compose = { module = "io.coil-kt.coil3:coil-compose", version.ref = "coil" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
```

---

**TL;DR pour démarrer demain matin :**

1. Créer le projet multi-module avec la structure section 7.
2. Ajouter `libs.versions.toml` ci-dessus.
3. Coder phase 1 (Prayer MVP) en 12-15 jours.
4. Recruter un beta-tester Wear OS (Pixel Watch / Galaxy Watch) dès phase 1 — la sync iOS↔Watch n'a pas d'équivalent Android, faut valider tôt.
5. Valider le choix `adhan-kotlin` la première semaine (sinon prévoir port maison +3 jh dans phase 1).
6. Soumettre la demande `USE_EXACT_ALARM` au Play Console dès phase 3 (review prend 1-2 semaines).