# Audit — Programme de Lecture du Quran

**Date** : 2026-06-02
**But** : valider l'architecture du module avant code (Phase 1 → Phase 2).
**Contrainte centrale** : strictement **additif**. Aucune feature existante (horaires, notifs prière, podcast, widgets, watch, complication) ne doit régresser.

---

## 1. Décisions architecturales validées

| # | Décision | Justification |
|---|---|---|
| **D1** | **Unité = Page Madinah 604** | Standard universel du Mushaf imprimé ; permet un découpage net (ex: 5 pages × 5 prières = 25/j ≈ 1 juz/j). Pas de dépendance à un dataset Quran complet (sourate/verset). |
| **D2** | **Persistance hybride** : SwiftData pour `ReadingEntry` (journal daté). `UserDefaults`/`Codable` pour `QuranPlan` courant (singleton, ≤ 1KB). | KISS : SwiftData uniquement là où il a un vrai bénéfice (requêtes datées, Charts). Le plan courant n'a pas besoin d'une base. |
| **D3** | **Navigation** : carte "Khatma" insérée dans **Tab Rappel** (`DailyContentView`) → sheet plein écran sur tap. | Évite d'ajouter une 5ᵉ tab à la TabView. Tab Rappel est déjà la zone "spirituelle quotidienne". |
| **D4** | **Notifications** : nouvelle méthode `NotificationManager.scheduleQuranReminders(...)` avec préfixe d'ID `quran_reading_`. Méthode **distincte** de `scheduleBatchNotifications`. | Respecte la contrainte "ne JAMAIS écraser les notifs prière". Préfixe ≠ permet `removePending` ciblé. |
| **D5** | **ZÉRO nouvelle dépendance SPM** | SwiftData, Swift Charts, UserNotifications, ActivityKit : tout Apple natif. |

---

## 2. Modèle de données

### 2.1 `QuranPlan` — paramètres du plan courant (UserDefaults)

```swift
enum PlanGoalType: String, Codable {
    case byDuration   // Nombre de jours
    case byPages      // Nombre total de pages à lire
    case byDate       // Date cible précise
}

struct QuranPlan: Codable, Equatable {
    var id: UUID
    var goalType: PlanGoalType
    var goalValue: Double          // jours / pages / timestamp selon goalType
    var startDate: Date
    var startPage: Int             // page de départ (1...604)
    var endPage: Int               // page d'arrivée (1...604)
    var prayersToUse: Set<String>  // {"Fajr","Dhuhr","Asr","Maghrib","Isha"} ⊆
    var notificationsEnabled: Bool
}
```

Stocké via `@AppStorage("quranPlan") + Data` ou clé dédiée. Pas de migration nécessaire.

### 2.2 `ReadingEntry` — journal SwiftData

```swift
@Model
final class ReadingEntry {
    @Attribute(.unique) var id: UUID
    var date: Date                 // jour calendaire (normalisé minuit)
    var pagesRead: Int             // pages lues ce jour-là
    var lastPageReached: Int       // dernière page atteinte (curseur)
    var note: String?              // optionnel
}
```

Requêtes typiques :
- `@Query(sort: \.date, order: .reverse)` pour l'historique
- Filtre par range de dates pour la heatmap

### 2.3 Calculs dérivés (non persistés)

| Métrique | Formule |
|---|---|
| **Pages totales du plan** | `endPage - startPage + 1` |
| **Jours totaux du plan** | selon `goalType` (durée directe, ou `(targetDate - startDate) / 1j`) |
| **Pages/jour requis** | `totalPages / totalDays` (arrondi up) |
| **Pages/prière** | `pagesPerDay / prayersToUse.count` (arrondi up) |
| **Pages lues réelles** | `sum(entries.pagesRead) where date ∈ [startDate ; today]` |
| **Pages lues théoriques à date** | `daysElapsed × pagesPerDay` |
| **Solde retard/avance** | `pagesLuesReel - pagesLuesTheoriques` (négatif = retard) |
| **Streak** | jours consécutifs jusqu'à hier avec `pagesRead ≥ pagesPerDay` |

### 2.4 Presets indicatifs (UI helper)

```swift
enum QuranPlanPreset {
    case oneJuzPerDay        // ~ 30 jours, 20 pages/jour
    case halfJuzPerDay       // ~ 60 jours, 10 pages/jour
    case oneQuarterJuzPerDay // ~ 120 jours, 5 pages/jour
    case ramadanKhatma       // ~ 29 jours, ~ 21 pages/jour
}
```

---

## 3. Architecture / fichiers à créer

```
Muslim Clock/QuranPlan/
├── Models/
│   ├── QuranPlan.swift                (struct Codable + presets)
│   └── ReadingEntry.swift             (@Model SwiftData)
├── ViewModels/
│   └── QuranPlanViewModel.swift       (@MainActor @Observable)
├── Services/
│   ├── QuranReminderScheduler.swift   (notif batch — préfixe quran_reading_)
│   └── QuranPlanMath.swift            (fonctions pures : calculs dérivés)
└── Views/
    ├── QuranKhatmaCard.swift          (carte compact insérée dans DailyContentView)
    ├── QuranPlanSetupView.swift       (sheet — créer/modifier un plan)
    ├── QuranTrackerView.swift         (sheet plein écran — vue principale)
    ├── QuranStatsView.swift           (Swift Charts : heatmap + courbe)
    └── ReadingEntryRow.swift          (cellule journal)
```

**Estimation** : ~ 800-1000 lignes Swift + 0 lignes existantes modifiées (sauf 1 ligne d'insertion + 1 modif notif — cf. §5).

---

## 4. Points d'accroche dans l'existant

### 4.1 Lecture des horaires de prière
**Source unique** : `PrayerTimesViewModel.dailyPrayers: [DailyPrayer]` (déjà publié, observable).
- Chaque `DailyPrayer` a `.name: String` et `.date: Date`.
- `QuranReminderScheduler` consomme cette liste pour planifier les rappels après chaque prière sélectionnée.
- **Aucun recalcul** d'horaires côté module Quran — délégation totale.

### 4.2 Navigation
- **Insertion** : 1 ligne dans `DailyContentView.swift` (carte `QuranKhatmaCard()` ajoutée au VStack, par exemple après la carte Hadith).
- **Sheet** : `.sheet(isPresented: $showQuranTracker) { QuranTrackerView() }` géré localement dans `QuranKhatmaCard` (état privé).

### 4.3 SwiftData container
- À déclarer dans `Muslim_ClockApp.swift` :
  ```swift
  .modelContainer(for: ReadingEntry.self)
  ```
- C'est la seule modif `Muslim_ClockApp` requise.

### 4.4 Environnement injection
- `QuranPlanViewModel` injecté via `@StateObject` ou `@State + @Observable` au niveau `MainView` ou `QuranKhatmaCard` (préférable : local au module pour isolation).

---

## 5. Notifications — Protocole de coexistence

### 5.1 État actuel
`NotificationManager.scheduleBatchNotifications` (ligne 25-60) :
- Appelle `removeAllPendingNotificationRequests()` ligne 29 ⚠️
- Programme 56 prières (IDs `prayer_0` à `prayer_55`)
- + 6 nouvelles lunes (IDs `newmoon_YYYY-M`)
- Total 62 / 64 limite iOS → **il reste 2 slots libres**.

### 5.2 Problème
`removeAllPendingNotificationRequests()` efface **toutes** les notifs, y compris les futures notifs Quran si on les ajoutait séparément.

### 5.3 Solution proposée — modif minimale du `NotificationManager`

Remplacer le `removeAll` global par un removal sélectif :

```swift
// Avant
center.removeAllPendingNotificationRequests()
center.removeAllDeliveredNotifications()

// Après — ne touche QUE les prefixes du scheduler prière
center.getPendingNotificationRequests { requests in
    let idsToRemove = requests
        .filter { $0.identifier.hasPrefix("prayer_") || $0.identifier.hasPrefix("newmoon_") }
        .map { $0.identifier }
    center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
}
```

**C'est la SEULE modification non-additive** de l'existant. Justifiée par la contrainte explicite "ne JAMAIS écraser les notifs de prière" (du brief utilisateur) → on inverse : ne pas écraser les notifs **autres modules** quand on (re)programme les prières.

### 5.4 Nouvelle méthode `scheduleQuranReminders`

```swift
func scheduleQuranReminders(
    pagesPerPrayer: Int,
    prayerDates: [(name: String, date: Date)]
) {
    let center = UNUserNotificationCenter.current()
    // Nettoyage SÉLECTIF : seulement les notifs Quran
    center.getPendingNotificationRequests { requests in
        let ids = requests
            .filter { $0.identifier.hasPrefix("quran_reading_") }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        // … puis programmer les nouvelles
    }
}
```

**Slots utilisés** : prière sélectionnées × jours planifiés, plafonné à 2 (slots restants iOS) → **réalité** : on programme uniquement pour les **prochaines 24h** (5 prières max → 5 slots). Le scheduler est relancé chaque jour (via observation `prayerVM.dailyPrayers`).

### 5.5 Identifiants réservés (TODO §7)

| Préfixe ID | Module | Conservé par |
|---|---|---|
| `prayer_N` (N=0..55) | Notifs prière | `scheduleBatchNotifications` |
| `newmoon_YYYY-M` | Hilal | `scheduleNewMoonNotifications` |
| `test_adhan` | Debug | `scheduleAdhan` |
| `quran_reading_<prayer>_<date>` | **Nouveau** Quran | `scheduleQuranReminders` |

---

## 6. UI — Composants visuels réutilisés

| Composant existant | Réutilisé pour |
|---|---|
| `RoundedRectangle(cornerRadius: 20, style: .continuous)` | Cartes du module (Khatma, stats) |
| `.background(.ultraThinMaterial)` / `.regularMaterial` | Fond cartes |
| `LinearGradient` sombre `[0.05/0.08/0.18 → 0.08/0.1/0.25]` | Fond sheet (cohérence avec AdhkarView) |
| Pattern `progressBar` (AdhkarView) — Capsule + arc | Barre de progression du plan |
| `.font(.caption.bold())` + `.foregroundColor(.teal/.orange)` | Headers des cartes (cohérence DailyContent) |

### 6.1 Charts (Swift Charts natif)
- **Heatmap régularité** : grille `Chart { ForEach(entries) { RectangleMark(...) } }` 7 colonnes × N semaines, couleur dégradée selon `pagesRead`
- **Courbe progression** : `Chart { LineMark(...) ; AreaMark(...) }` — pages cumulées vs théorique

### 6.2 Ton bienveillant — checklist UI
- ❌ Jamais de couleur **rouge** sur les états retard. Plutôt teal/indigo (cohérent palette app)
- ❌ Pas de texte "tu es en retard de N pages" → "il te reste N pages pour rester sur ton rythme"
- ✅ Streak mis en avant (icône flamme dorée)
- ✅ Phrase rappel **toujours visible** au bas de la sheet : *"La qualité prime sur la quantité — Bukhari"* (ou similaire à valider)

---

## 7. TODO / Réservations

### 7.1 Slots de notifications réservés
- Préfixe `quran_reading_*` réservé pour ce module.
- Pas de collision avec `prayer_*`, `newmoon_*`, `test_adhan`.

### 7.2 Modifs **non-additives** acceptées (minimes, justifiées)
- `NotificationManager.scheduleBatchNotifications` lignes 29-30 : remplacement `removeAll` → `removeByPrefix`. **Pourquoi** : sans ça, les notifs Quran sont effacées à chaque recalcul prière (toutes les 14 jours via `schedule14DaysNotifications`).
- `Muslim_ClockApp.swift` : ajout `.modelContainer(for: ReadingEntry.self)` au `WindowGroup`. **Pourquoi** : sans ça, SwiftData ne fonctionne pas.
- `DailyContentView.swift` : 1 ligne (ajout `QuranKhatmaCard()`) dans le VStack. **Pourquoi** : c'est le point d'entrée navigation.

### 7.3 Hors périmètre (chantiers futurs)
- Widget Khatma (Live Activity de session de lecture) → décrit dans `AUDIT_WIDGETS.md` §QW potentiels
- AppIntent "Marquer X pages lues" pour Siri / Control Center → après audit Phase 2
- Sync iCloud / Watch → non
- Récitation audio / tafsir intégré → non

### 7.4 Hors périmètre **fonctionnel** (rappel mission)
- Khatma de groupe / sync / backend / comptes
- Récitation jugée / IA / classement compétitif

---

## 8. Plan d'exécution Phase 2

1. **Models** : `QuranPlan.swift`, `ReadingEntry.swift` (SwiftData) — 10 min
2. **Math** : `QuranPlanMath.swift` (fonctions pures, testables) — 15 min
3. **ViewModel** : `QuranPlanViewModel.swift` (`@Observable`, charge plan + entries) — 20 min
4. **Services** : `QuranReminderScheduler.swift` — 15 min
5. **Modif NotificationManager** : removeByPrefix (§5.3) — 5 min
6. **Views** :
   - `QuranKhatmaCard` (entrée carte) — 20 min
   - `QuranPlanSetupView` (sheet création) — 30 min
   - `QuranTrackerView` (sheet tracker + bouton "marquer N pages") — 30 min
   - `QuranStatsView` (Swift Charts) — 30 min
7. **Branchement** : 1 ligne dans `DailyContentView`, 1 ligne dans `Muslim_ClockApp` — 5 min
8. **Diagnostics + tests preview** — 15 min

**Total estimé** : ~3h.

---

## Validation requise avant Phase 2

Si tu confirmes les D1-D5 et le périmètre §3, je code la Phase 2 dans cet ordre.

Si tu veux ajuster un point (ex: passer SwiftData → pure UserDefaults, ou changer le point d'insertion nav), dis-le maintenant — j'adapte avant d'écrire la première ligne de code.
