# Audit Widgets & Extensions — Muslim Clock

**Périmètre** : `SalatWidget/`, `PrayerComplication/`, `WatchExtension Watch App/`, et la couche de partage de données App Group `group.kappsi.Muslim-Clock`.
**Mode** : read-only. Aucune modification de code. Recommandations strictement **additives** — rien de breaking.
**Date** : 2026-06-02.

---

## 1. Inventaire des widgets

| Widget | TimelineProvider | Familles | Rôle | Refresh policy |
|---|---|---|---|---|
| **SalatHomeWidget** | `SalatProvider` | `systemMedium` | 5 sphères (Fajr→Isha) avec statuts (passé / prochain / imminent / futur) + hijri + grégorien | `.atEnd` après ~20 checkpoints anticipés (-30, -15, -5 min avant chaque prière + début) |
| **SalatSmallWidget** | `SalatProvider` | `systemSmall` | Prochaine prière + heure + countdown + 5 micro-sphères d'état | Idem `SalatProvider` |
| **SalatLockScreenWidget** | `SalatProvider` | `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline` | Lock screen : jauge progression / nom+countdown / emoji+nom | Idem `SalatProvider` |
| **SalatWatchCirclesWidget** | `SalatProvider` | `.accessoryRectangular` (watch) | 5 cercles + prochaine prière + décompte | Idem `SalatProvider` |
| **PrayerComplication** | `PrayerTimelineProvider` | `.accessoryCircular`, `.accessoryRectangular`, `.accessoryCorner`, `.accessoryInline` | Complication watch : sphères + arc progression + phase lunaire (corner) + date hijri | `.after(entry.nextRefresh)` — 5 min si prière en cours, sinon début prochaine prière, sinon Fajr de demain |

**Bundles** : `SalatWidgetBundle` (iOS) et `PrayerComplicationBundle` (watchOS) — déclaration via `@main`.

---

## 2. Flux de données app → widget

### 2.1 Schéma logique

```
┌──────────────────────────────────────────────────────────────────────┐
│  App iOS principale (Muslim Clock)                                   │
│  ─────────────────────────────────────                               │
│  PrayerTimesViewModel ──┬── écrit clés "prayer_*" (Double timestamps)│
│                         ├── écrit clés "w_*"      (réglages)         │
│                         └── écrit "saved_latitude/longitude"         │
│  DailyContentService  ── écrit clés "daily_*"     (verset + hadith)  │
└──────────────────────────────┬───────────────────────────────────────┘
                               │
              ┌────────────────┴─────────────────┐
              │                                  │
              ▼                                  ▼
   UserDefaults(suiteName:                WatchSessionManager.shared
   "group.kappsi.Muslim-Clock")           .sendPrayerTimes / sendSettings
   (App Group local iOS)                  → transferUserInfo (queue)
              │                                  │
              │ ◄────────────────────────────────┘
              │              (livraison garantie iOS → watchOS)
              ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │  Lecteurs                                                        │
   │  ────────                                                        │
   │  SalatProvider          (iOS widgets)                            │
   │  PrayerTimelineProvider (watchOS complication)                   │
   │  WatchPrayerViewModel   (watchOS app)                            │
   │  WatchDailyContentViewModel (watchOS app)                        │
   │                                                                  │
   │  Côté watch : WatchSessionReceiver → écrit dans App Group local  │
   │  + déclenche WidgetCenter.shared.reloadAllTimelines() ✅         │
   └──────────────────────────────────────────────────────────────────┘
```

### 2.2 Inventaire des clés (extrait)

| Clé | Écrite par | Lue par | Type |
|---|---|---|---|
| `prayer_fajr/dhuhr/asr/maghrib/isha/sunrise` | PrayerTimesViewModel | SalatProvider, PrayerComplication, WatchPrayerViewModel | Double (Unix timestamp) |
| `prayer_fajr_tomorrow` | PrayerTimesViewModel | PrayerComplication, WatchPrayerViewModel | Double |
| `w_calculationMethod` | PrayerTimesViewModel | SalatProvider | String |
| `w_fajrOffset` … `w_ishaOffset` | PrayerTimesViewModel | SalatProvider | Int |
| `w_isIshaFixed`, `w_ishaFixedDuration` | PrayerTimesViewModel | SalatProvider | Bool / Int |
| `w_jumuahEnabled` | PrayerTimesViewModel | SalatProvider, WatchPrayerViewModel, PrayerComplication | Bool |
| `w_jumuahHour`, `w_jumuahMinute` | PrayerTimesViewModel | **non relus par les widgets** ⚠️ | Int |
| `saved_latitude`, `saved_longitude` | PrayerTimesViewModel | SalatProvider | Double |
| `daily_ayah_fr/ar/source`, `daily_hadith_fr/ar/source` | DailyContentService | WatchDailyContentViewModel | String |

### 2.3 Risques de désynchro identifiés

| # | Risque | Localisation | Impact |
|---|---|---|---|
| R1 | **Clés non-préfixées** `saved_latitude` / `saved_longitude` (vs convention `w_*` ou `prayer_*`) | `PrayerTimesViewModel.swift:282-283` | Cohérence nominale fragile, risque de typo silencieuse |
| R2 | **`w_jumuahHour/Minute` jamais relus** par le widget | écrit `PrayerTimesViewModel.swift:295-296` ; non lu côté `SalatProvider` | Si l'utilisateur change l'heure Jumu'ah sur l'iPhone, le widget reste sur l'ancien horaire |
| R3 | **Pas de versioning** sur les payloads `transferUserInfo` | `WatchSessionManager` / `WatchSessionReceiver` | Risque de format incompatible si l'app évolue sans la watch (ou inverse) |
| R4 | **Aucun checksum** ni validation du payload reçu côté watch | `WatchExtensionApp.swift:51-65` | Données partielles ou corrompues silencieuses |
| R5 | **Pas de reload widget** déclenché à la modification isolée de `w_jumuahEnabled` | `PrayerTimesViewModel` | Reload existe globalement (✅ ligne 305) mais pas systématique sur chaque clé |

### 2.4 WatchConnectivity

- **iOS → watchOS** : `transferUserInfo()` (livraison garantie, mise en queue). Bon choix pour ce flux.
- **watchOS reçoit** : `WatchSessionReceiver.didReceiveUserInfo` écrit dans App Group + appelle `WidgetCenter.shared.reloadAllTimelines()` ✅.
- **Types supportés** : Double, Bool, Int, String (switch explicite, ligne 55-61).

---

## 3. Écart vs capacités modernes WidgetKit

| Capacité | Statut | Accroche |
|---|---|---|
| **Widget interactif via AppIntents** (iOS 17+) | **PARTIEL** | `ToggleSunnahIntent` défini (`AppIntent.swift:4-35`) mais aucun `Button(intent:)` / `Toggle(intent:)` dans les widget Views (SalatWidget.swift). Le `SalatWidgetControl.swift` contient un stub `StartTimerIntent` non métier. |
| **Live Activity + Dynamic Island** (ActivityKit) | **ABSENT (stub)** | `SalatWidgetLiveActivity.swift:12-57` — template Xcode "Hello emoji" non adapté. `widgetURL` pointe vers `apple.com`. Pas de `SalatWidgetAttributes` métier. |
| **Control Center Control** (iOS 18+) | **ABSENT (stub)** | `SalatWidgetControl.swift:12-77` et `PrayerComplicationControl.swift:12-54` — templates Xcode "Start Timer" inchangés. Aucun lien aux prières. |
| **Lock Screen accessories** | **PRÉSENT ✅** | `.accessoryCircular` + `.accessoryRectangular` + `.accessoryInline` couverts par `SalatLockScreenWidget`. |
| **Deep linking widget → écran** | **ABSENT** | Aucun `widgetURL(...)` ou `Link(destination:)` dans les widgets actifs. Pas de `onOpenURL` côté app iOS (grep négatif). |

---

## 4. Qualité

### Points forts ✅
- `containerBackground(for: .widget)` utilisé partout avec `LinearGradient` ou matériau adapté (Liquid Glass cohérent).
- `WatchSessionReceiver` déclenche `reloadAllTimelines()` automatiquement après réception → complication toujours fraîche.
- `PrayerTimelineProvider` recalcule fin de fenêtre intelligente (5 min en window, sinon prochain prayer).
- Cas "pas de données" géré côté watch : `NoDataView` ("Ouvrez l'app iPhone") + `vm.isDataAvailable`.
- Budget timeline raisonnable : `SalatProvider` ~20 entries, `PrayerTimelineProvider` 1 entry par refresh.

### Points faibles / à surveiller ⚠️
- **Cas "pas de données" côté widgets iOS** : `SalatProvider.buildEntry()` renvoie un entry "vide" affiché tel quel ("-- :--"). Pas de `.redacted(reason: .placeholder)` ni d'état d'erreur explicite.
- **Localisation refusée** : aucun handler distinct — l'utilisateur voit l'état "pas de données" identique au démarrage à froid.
- **Source du verset/hadith** : affichée côté Watch (`DailyContentTab:317-322`). Non concerné côté iOS car aucun widget Coran/Hadith iOS pour l'instant.
- **Stubs Xcode résiduels** : 3 fichiers générés par template, jamais adaptés métier (cf. §3 et §5).

---

## 5. Quick wins priorisés (additifs uniquement)

| # | Quick win | Valeur | Effort | Détail |
|---|---|---|---|---|
| QW1 | **Lire `w_jumuahHour/Minute` côté SalatProvider** | 🟢 Moyen | 🟢 5 min | Corrige R2 — le widget ignore l'heure custom de Jumu'ah |
| QW2 | **Préfixer `saved_lat/long` → `w_latitude/w_longitude`** | 🟡 Bas | 🟢 15 min (1 écriture + N lectures + migration UserDefaults) | DRY nominal, retire R1. **Attention rétrocompatibilité** — fallback lecture des 2 clés pendant 1 release |
| QW3 | **Ajouter `widgetURL(_:)` dans les widgets** pour deep linking | 🟢 Moyen | 🟢 15 min | Tap widget → ouvre l'app sur l'écran Salat. Nécessite `onOpenURL { … }` côté app iOS |
| QW4 | **Remplacer les 3 stubs Xcode** (`SalatWidgetControl`, `PrayerComplicationControl`, `SalatWidgetLiveActivity`) | 🟢 Élevé | 🟡 Moyen | Voir candidats §6 ci-dessous. Sinon les supprimer du Bundle pour éviter les stubs apparents |
| QW5 | **Brancher `ToggleSunnahIntent` à un `Button(intent:)`** dans le widget Sunnah | 🟢 Élevé | 🟢 30 min | L'intent existe déjà — il manque uniquement les boutons côté UI widget |
| QW6 | **Ajouter `.redacted(reason: .placeholder)`** pour l'état "snapshot avant 1er load" | 🟡 Bas | 🟢 10 min | UX plus propre au premier lancement / à la galerie de widgets |
| QW7 | **Versionner le payload WatchConnectivity** avec une clé `_payload_version: Int` | 🟡 Moyen | 🟢 20 min | Couvre R3 — futur-proof si format change. Receiver ignore les versions inconnues. |

---

## 6. Esquisse — 2 meilleurs candidats

### 6.1 Live Activity "Prochaine Salât" via ActivityKit

**Objectif** : Dynamic Island + Lock Screen Live Activity avec compte à rebours live vers la prochaine prière, démarrée automatiquement ~30 min avant chaque prière.

**Point d'intégration architectural (sans code)** :

1. **Fichier à reprendre** : `SalatWidgetLiveActivity.swift` (actuellement stub Xcode).
2. **`ActivityAttributes`** : structure `PrayerLiveActivityAttributes` avec
   - `prayerName: String` (nom prière)
   - `arabicName: String`
   - `targetTime: Date` (heure prière)
   - `ContentState` dynamique : `progress: Double` (0→1), `isImminent: Bool`.
3. **Démarrage** : depuis l'app iOS, déclencher `Activity.request(...)` quand on entre dans la fenêtre "30 min avant prochaine prière". Point d'accroche idéal : `Muslim_ClockApp.swift` ou `PrayerTimesViewModel` (méthode dédiée `startLiveActivityIfNeeded()`).
4. **Mise à jour** : `Activity.update(...)` chaque minute via `Timer` côté app ou via `staleDate`. Avantage : pas de timeline widget à gérer — ActivityKit gère le rendu live (timer auto-décompte avec `Text(.timer)`).
5. **Fin** : `Activity.end(...)` automatique à l'arrivée de la prière (ou `staleDate` pour expiration auto).
6. **Vues** :
   - **Compact leading/trailing** : icône prière + countdown.
   - **Minimal** : countdown seul.
   - **Expanded** : prière + heure + verset court ou phase lunaire.
   - **Lock Screen** : carte glass avec nom + countdown + progression.

**Risques / contraintes** :
- iOS 16.1+ requis (déjà aligné avec le projet).
- Capability "Push Notifications" + entitlement `NSSupportsLiveActivities` dans `Info.plist` (à ajouter, non breaking).
- Limite système : 1 Live Activity active simultanément par défaut — à confirmer avec UX.

**Données nécessaires** : déjà toutes dans l'App Group (`prayer_*`, `w_jumuahEnabled`). Aucune nouvelle clé.

---

### 6.2 Widget interactif "Prière accomplie" via AppIntent

**Objectif** : ajouter un bouton dans `SalatHomeWidget` (medium) pour marquer la prière courante comme accomplie, sans ouvrir l'app.

**Point d'intégration architectural (sans code)** :

1. **Nouvel AppIntent** (à créer dans `SalatWidget/`) : `MarkPrayerCompletedIntent: AppIntent` avec
   - `@Parameter prayerKey: String` (ex: "fajr", "dhuhr"…)
   - `@Parameter date: Date` (jour concerné, pour scoper la persistance)
   - `func perform()` : écrit `prayer_completed_<key>_<YYYY-MM-DD>: Bool` dans App Group + `WidgetCenter.shared.reloadAllTimelines()`.
2. **Persistance** : nouvelle convention de clés `prayer_completed_<prayer>_<date>` dans l'App Group. Reset auto si la date a changé (lecture conditionnelle dans `SalatProvider.buildEntry()`).
3. **UI Widget** : sur la sphère de la prière "en cours" / "imminente", remplacer la sphère statique par un `Button(intent: MarkPrayerCompletedIntent(...))` avec un style adapté (checkmark visible si déjà accompli).
4. **Synchronisation app** : côté iOS principal, lire ces clés au démarrage pour afficher le statut "✅ prière accomplie" — point d'accroche dans `MainView` ou `PrayerTimesViewModel`.
5. **Synchronisation watch** : envoyer le bool via `WatchSessionManager.sendSettings` pour cohérence cross-device (ou laisser la watch lire l'App Group local si on installe les complications avec App Group commun).

**Risques / contraintes** :
- iOS 17+ requis pour `Button(intent:)` côté widget (à valider avec le minimum deployment target).
- Le `perform()` AppIntent côté widget tourne dans un contexte limité (~10 secondes, RAM réduite) — ne pas y faire d'I/O lourd. KISS : juste un bool dans UserDefaults.
- Risque de désync horaire : si l'utilisateur change de timezone, la clé `<date>` peut ne plus matcher. **Mitigation** : utiliser un `dateID` calculé à partir de la fenêtre Fajr→Asr (matin) / Asr→Fajr (soir) plutôt que la date civile.

**Données nécessaires** : nouvelles clés `prayer_completed_*` — additif pur, aucun impact sur les clés existantes.

---

## Annexe — Stubs Xcode à reprendre ou retirer

| Fichier | État | Action recommandée |
|---|---|---|
| `SalatWidget/SalatWidgetControl.swift` | Stub `StartTimerIntent` | Reprendre pour un ControlWidget "Marquer prière accomplie" OU retirer du `SalatWidgetBundle` |
| `SalatWidget/SalatWidgetLiveActivity.swift` | Stub "Hello emoji" + `widgetURL → apple.com` | Reprendre selon §6.1 |
| `PrayerComplication/PrayerComplicationControl.swift` | Stub Timer non métier | Retirer du bundle (Control Center n'existe pas sur watchOS) |

Ces stubs apparaissent actuellement dans le `WidgetBundle.body` et peuvent générer des entrées vides dans la galerie de widgets.
