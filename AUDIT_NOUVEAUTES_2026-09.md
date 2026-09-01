# Audit des nouveautés — synchronisation du 1ᵉʳ septembre 2026

Périmètre : les 111 commits `dbc2355..e78219f` récupérés depuis GitHub
(141 fichiers, +23 925 / −3 452 lignes). Build vérifié : ✅ compile sans erreur.

---

## 1. Nouveaux modules

### 📖 Coran (16 fichiers, ~3 800 lignes) — complet, production-ready
- **Plan Khatma** : plan de lecture persisté (UserDefaults + journal SwiftData),
  progression, streak, 4 presets + mode expert. Math pur dans `QuranPlanMath.swift`.
- **Lecteur** : 114 sourates via CDN jsDelivr (`risan/quran-json@3.1.2`), cache
  NSCache + disque, thèmes sépia/sombre, translittération/traduction FR,
  auto-scroll, marque-pages, pages Madinah démarquées (`QuranPageMapper`, dichotomie).
- **Enregistreur de récitation** : AAC mono 32 kbps, cap 10 min, karaoké verset
  par verset au playback (`QuranRecorder.swift`).
- **Rappels post-prière** + **stats Charts** (heatmap 35 j, courbe cumulative).
- Crédit automatique des pages lues pendant la lecture (`f3107c0`).

### 🎓 ʿIlm — programme des mutūn (10 fichiers) — complet
- 3 parcours : Trois Fondements, Quatre Règles, 40 Nawawi — 68 leçons,
  tachkīl complet + traduction FR (`ilm_tracks.json`).
- Révision espacée **Leitner 5 boîtes** (1j→3j→7j→14j→30j), flashcards,
  mode mémorisation (texte voilé), réutilise `QuranRecorder` pour réciter.
- 1 rappel quotidien (trigger calendaire répétitif, DST-safe).

### 📿 Refonte Adhkar — complet
- **Livret Hisn** (`hisn_adhkar.json`, 516 lignes) : catégories situationnelles
  authentifiées avec badge sahih/hasan.
- **Suggestion contextuelle** (`AdhkarSuggestion.swift`) : fenêtres temporelles
  pures basées sur les horaires de prière (adhan ±5 min, réveil post-Fajr,
  dernier tiers de nuit, etc.).
- **Recherche** insensible aux accents FR et harakât arabes + filtre authenticité.
- Rappels post-Fajr / post-Asr (2 notifs/jour max).

### ✈️ Mode voyage (Safar) — complet
- Détection Haversine pure, seuil 83 km, règle d'ancre glissante/gelée
  (`TravelDistance.swift`). L'intention utilisateur prime toujours sur le GPS.
- Fiche facilités qasr/jamʿ/jeûne avec dalils (`TravelFiqh.swift`).

### 🕌 Iqamah / Jumu'ah / retardataire — complet
- Décompte **Adhan → Iqamah** avec délai par prière, Jumu'ah hérite de Dhuhr
  (`IqamahMath.swift`, fenêtres half-open testées).
- Carte d'anticipation Dhuhr/Jumu'ah dans la dernière heure.
- Fiche fiqh **masbûq** (« arrivé en retard ») : règles, exemples par prière,
  janâza, positions Ibn Bâz / Ibn ʿUthaymîn (`LatecomerFiqh.swift`).
- Jumu'ah affiché au lieu de Dhuhr le vendredi sur les 5 cibles (app, home,
  lock screen, watch, complication) — `5beda4c`.

### 🌙 Ramadan — complet
- Carte du'a contextuelle Iftar / Suhoor / général (10 dernières nuits),
  pool OTA (`ramadan_duas.json`), palettes dédiées.
- Live Activity Fajr → Suhoor, widgets variante ambre lanterne,
  relabel Maghrib → Iftar.

### 💰 Donations (tip jar) — **DEBUG-only**
- StoreKit 2, 4 tiers consumables (1,99 € → 19,99 €), `Configuration.storekit`.
- UI masquée derrière `#if DEBUG` (`8a218a8`) en attendant la finalisation
  App Store Connect (Agreements/Tax/Banking). À réactiver dans `SettingsView`.

---

## 2. Refactorings & infra

| Sujet | Détail |
|-------|--------|
| **PrayerCalculationEngine** | Extraction pure du moteur Adhan (méthodes, madhab, marqueurs nuit, fenêtres) — testable |
| **PrayerSynchronizer** | I/O App Group isolé (widgets/watch/complication) |
| **StorageKeys** | Clés UserDefaults centralisées, préfixe `w_` pour la Watch |
| **AppGroupID.swift** | `AppGroup.identifier` unique, `nonisolated` (Swift 6), partagé par les 4 cibles |
| **NotificationDeepLink** | Deep links robustes au cold start : route persistée UserDefaults, fenêtre 30 s, garde anti-replay adhan |
| **Budget notifs iOS 64** | Adhan 14 j → 7 j (~35 notifs), plafond 40, `threadIdentifier` de groupement |
| **Live Activity** | `SalatLiveActivityManager` : démarrage T-30 min, bascule à l'heure, fin T+5 min, rattrapage au foreground |
| **Control Widgets iOS 18** | Qibla / Adhkar / Coran via `OpenInMuslimClockIntent` |
| **PrivacyInfo.xcprivacy** | Manifeste requis App Store : 0 tracking, 0 collecte, raisons CA92.1 + B728.1 |
| **AppUpdateChecker** | Cache-buster + no-cache sur iTunes Lookup, comparaison numérique (1.10 > 1.9), throttle 24 h |
| **Sécurité** | `ToggleSunnahIntent` retiré (écriture UserDefaults arbitraire) — `0301050` |
| **Swift 6** | 0 warning (conformances Equatable nonisolated) — `a84c e78` |
| **Qibla** | Sensor fusion CoreMotion 60 Hz, cap vrai nord, états calibration |
| **Versions** | 1.2.0 → **1.5.0 (build 9)**, écran « Quoi de neuf » cumulatif |

## 3. Tests

15 nouveaux fichiers de tests, **~140 tests** au total, tous sur des fonctions pures :
Iqamah (9), Dhuhr (7), SmartSetup (28), PrayerEngine (8), Synchronizer (6),
Location (8), Travel (15), QuranPlan (10), Ilm (11), Adhkar (15), Podcast, Qibla,
UpdateCheck, etc.

---

## 4. Problèmes détectés

### ✅ Bug corrigé (01/09/2026) — deep link ʿIlm mort
- `IlmReminderScheduler.swift:47` émettait `userInfo = ["module": "ilm_program"]`
  mais le switch de `Muslim_ClockApp.didReceive` n'avait aucun case correspondant
  et `NotificationDeepLink` n'avait pas de route ʿIlm → tap = app ouverte sans navigation.
- **Fix appliqué** (miroir exact du pattern `quran_reading`) :
  - route `.ilmTracker` dans `NotificationDeepLink.swift`
  - case `"ilm_program"` dans `Muslim_ClockApp.didReceive` + nom `.ilmReminderTapped`
    + flag `pendingOpenIlmTracker`
  - routage MainView : handler live `.onReceive(.ilmReminderTapped)` + case cold start
    `.ilmTracker` → tab Rappel
  - `IlmProgramCard` : consommation du flag au mount + ouverture immédiate si montée
- Au passage : le `body` de MainView dépassait la capacité du type-checker —
  coupé en deux instructions (`let content` + `return`) et `onDismiss` du
  Quoi de neuf extrait dans `markWhatsNewSeen()`.

### 🟠 À durcir
| Fichier | Problème | État |
|---------|----------|------|
| `QuranPlanViewModel.swift` | `try? context.save()` — échec SwiftData silencieux | ✅ Corrigé (01/09) : do/catch + flag `saveFailed` + alert dans `QuranTrackerView` |
| `SmartSetupMath.swift:48` | `precondition(!items.isEmpty)` | ✅ Vérifié (01/09) : call site unique gardé par `guard !candidates.isEmpty` (SmartSetupView.swift:243) — sûr |
| `QuranRecorder.swift` | Fallback de durée pouvait produire un M4A de durée 0 (race rare au stop) | ✅ Corrigé (01/09) : `currentTime` lu AVANT `recorder.stop()` (après l'arrêt il renvoie 0), fallback horloge conservé en ceinture-bretelles |

### 🟡 Couverture de tests manquante
- ✅ `RamadanDuaService.currentWindow()` : couvert (01/09) — `RamadanDuaWindowTests.swift`,
  10 tests (bornes Iftar, Suhoor wrap minuit, borne Fajr exclue, priorité Iftar, nils).
  `currentWindow` passé `nonisolated` (fonction pure) pour être testable hors MainActor.
- ⏳ `LatecomerFiqh` : 183 lignes de contenu religieux de référence sans validation —
  relecture manuelle recommandée (Coran 4:101, ordre des rakʿas).
- ⏳ Aucun test d'intégration SwiftData / schedulers de notifications.

### ℹ️ Points d'attention avant release
1. Réactiver les donations (retirer les 2 `#if DEBUG` dans `SettingsView`) quand
   App Store Connect est prêt.
2. Vérifier l'alignement des `.entitlements` App Group des 3 extensions.
3. Complication watchOS : approximation `now + 8h` si `prayer_fajr_tomorrow` stale
   (app non ouverte plusieurs jours) — garde anti-stale présente mais grossière.

---

## 5. Verdict

Base de code en très bon état : séparation logique pure / I/O systématique,
Swift 6 sans warning, budget notifications maîtrisé, deep links cold start résolus
(sauf ʿIlm), contenu religieux sourcé. **1 bug à corriger** (deep link ʿIlm),
2-3 durcissements souhaitables, donations en stand-by volontaire.
