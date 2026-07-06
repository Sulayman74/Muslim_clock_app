# Audit — Programme d'apprentissage « ʿIlm » (v1.4.0)

**Date** : 2026-07-06
**But** : valider l'architecture du module avant code (Phase 1 → Phase 2), dans le même moule que la Khatma (cf. `AUDIT_QURAN_PLAN.md`).
**Périmètre fonctionnel** : programme d'étude/mémorisation de 3 textes classiques :
1. **Les 3 Fondements** (ثلاثة الأصول — Thalāthat al-Uṣūl)
2. **Les 4 Règles** (القواعد الأربع — Al-Qawāʿid al-Arbaʿ)
3. **Les 40 Hadiths de Nawawi** (الأربعون النووية — 42 hadiths dans les éditions courantes)

**Contrainte centrale** : strictement **additif**. Aucune régression sur horaires, notifs prière, Khatma, podcasts, widgets, watch, complication.

---

## 1. Décisions architecturales validées

| # | Décision | Justification |
|---|---|---|
| **D1** | **Unité = « leçon »** (`IlmLesson`) au sein d'un **parcours** (`IlmTrack`). Un parcours = liste ordonnée de leçons. | Équivalent de la « page Madinah » de la Khatma, mais générique : les 3 textes ont des granularités différentes (42 hadiths vs 4 règles). Une seule mécanique pour les 3. |
| **D2** | **Contenu = JSON bundlé, data-driven** (`ilm_tracks.json`). Ajouter un 4ᵉ texte plus tard = ajouter du JSON, **zéro code**. | OCP obtenu par la donnée, pas par des protocoles spéculatifs (KISS conforme CLAUDE.md). Même pattern que `adhkar.json` / `hadiths.json`. Offline-first, pas de `RemoteJSONLoader` (contenu canonique figé, et le loader n'a pas d'expiration de cache — piège connu). |
| **D3** | **Persistance : UserDefaults uniquement** (2 clés Codable : progression + plan). **Pas de SwiftData.** | ≤ ~90 leçons au total, progression < 5 KB. SwiftData ne se justifiait pour la Khatma que par les requêtes datées sur un journal ouvert (pages illimitées dans le temps). Ici le journal EST la progression (1 leçon = 1 date d'acquisition). Bénéfice non-régression majeur : **on ne touche pas au `modelContainer`** de `Muslim_ClockApp`. |
| **D4** | **Navigation** : carte `IlmProgramCard` insérée dans **Tab Rappel** (`DailyContentView`), juste sous `QuranKhatmaCard` → sheet plein écran sur tap. | Même moule D3 Khatma. Pas de 5ᵉ tab. La zone « spirituel quotidien » regroupe Khatma + ʿIlm. |
| **D5** | **Rappels : 1 notification/jour max**, heure choisie par l'utilisateur, préfixe d'ID `ilm_reminder_`, fenêtre glissante 7 jours (≤ 7 notifs pendantes). | Une leçon se mémorise en 1 session, pas en 5 fractions post-prière. Budget notification minimal (limite iOS : 64 pendantes, déjà consommées par prières + `quran_reading_`). Préfixe distinct = coexistence garantie. |
| **D6** | **ZÉRO nouvelle dépendance SPM.** | Foundation + SwiftUI + UserNotifications. |
| **D7** | **Un seul « programme actif »** (parcours en cours + rythme), mais la **progression est conservée par parcours**. Changer de parcours ne perd rien. | Miroir du singleton `QuranPlan`. Simple à raisonner, simple à afficher. |

---

## 2. Modèle de données

### 2.1 Contenu (bundlé, immuable) — `ilm_tracks.json`

```swift
/// Un texte à étudier (les 3 Fondements, les 4 Règles, les 40 Nawawi).
struct IlmTrack: Codable, Identifiable {
    let id: String            // "usul3" | "qawaid4" | "nawawi40" (stable, clé de progression)
    let title: String         // "Les 3 Fondements"
    let titleArabic: String   // "ثلاثة الأصول"
    let author: String        // "Muhammad ibn ʿAbd al-Wahhāb" / "An-Nawawī"
    let lessons: [IlmLesson]  // ordonnées
}

/// Une leçon : l'unité de progression (équivalent « page Madinah »).
struct IlmLesson: Codable, Identifiable {
    let id: String            // "nawawi40_07" — unique global, stable
    let title: String         // "Hadith 7 — La religion c'est le conseil"
    let arabic: String        // texte arabe intégral de la leçon
    let text: String          // traduction française
    let source: String?       // "Bukhari 13, Muslim 45" (hadiths) / nil (matn)
    let note: String?         // bref commentaire pédagogique optionnel
}
```

Découpage proposé (à valider avec le contenu réel) :

| Parcours | Leçons | Découpage |
|---|---|---|
| `usul3` | ~20 | Les 4 questions intro, connaissance d'Allah, de la religion (3 degrés × piliers), du Prophète ﷺ, conclusion |
| `qawaid4` | 6 | Introduction (duʿā + 4 questions) + 1 règle par leçon + conclusion |
| `nawawi40` | 42 | 1 hadith = 1 leçon |
| **Total** | **~68** | borne constante connue à la compilation |

⚠️ **Contenu** : les matns arabes sont dans le domaine public ; les **traductions françaises doivent être fournies/validées par toi** (droits + fiabilité). Le JSON existant `hadiths.json` (164 hadiths « du moment ») est un autre usage — **ne pas fusionner** (pas d'ids stables, pas d'ordre canonique).

### 2.2 Progression — UserDefaults, clé `ilm_progress`

```swift
/// Progression globale : leçon acquise → date d'acquisition.
/// Dictionnaire à clé String (id de leçon) → lookup O(1).
struct IlmProgress: Codable, Equatable {
    var completedAt: [String: Date] = [:]   // lessonID → date de validation

    func isCompleted(_ lessonID: String) -> Bool { completedAt[lessonID] != nil }  // O(1)
    mutating func complete(_ lessonID: String, on date: Date) { ... }              // O(1)
    mutating func uncomplete(_ lessonID: String) { ... }                           // O(1)
}
```

### 2.3 Plan actif — UserDefaults, clé `ilm_plan`

```swift
/// Programme en cours : quel parcours, quel rythme, quel rappel.
struct IlmPlan: Codable, Equatable {
    var trackID: String               // parcours actif
    var startDate: Date
    var lessonsPerWeek: Int           // rythme (1...14) — presets §2.5
    var reminderEnabled: Bool
    var reminderHour: Int             // 0...23 (défaut 20h — après Maghreb/Isha selon saison)
    var reminderMinute: Int           // 0...59
}
```

### 2.4 Calculs dérivés (non persistés) — `IlmMath` (fonctions pures, testables)

| Métrique | Formule | Complexité |
|---|---|---|
| Leçons totales du parcours | `track.lessons.count` | O(1) |
| Leçons acquises | comptage `completedAt` sur les ids du parcours (via `Set` des ids, construit 1×) | O(n), n ≤ 68 constant |
| % avancement | `acquises / totales` | O(1) |
| Prochaine leçon | premier index non complété (ordre canonique) | O(n) borné |
| Leçons/semaine réelles | acquises sur fenêtre glissante 7 j | O(n) borné |
| Solde avance/retard | `acquises − attendues` où `attendues = semainesÉcoulées × lessonsPerWeek` (plafonné au total) | O(1) |
| Date de fin estimée | `startDate + ceil(restantes / lessonsPerWeek)` semaines | O(1) |
| Streak (semaines consécutives objectif atteint) | regroupement des dates par semaine, parcours descendant | O(n) borné |

**Vision Big-O** : le contenu est **fini et constant** (~68 leçons, figé dans le bundle). Toute opération est O(1) strict (lookups dictionnaire) ou O(n) avec n constant borné — donc **complexité constante de bout en bout**, aucune structure ne croît avec le temps d'utilisation (contrairement aux `ReadingEntry` de la Khatma qui s'accumulent). Aucun recalcul en boucle de rendu : le snapshot `IlmProgressSummary` est recalculé uniquement sur mutation (`refresh()`), comme `QuranPlanProgress`.

### 2.5 Presets de rythme (UI helper — miroir `QuranPlanPreset`)

```swift
enum IlmPlanPreset: CaseIterable {
    case oneLessonPerDay      // 7/sem  — Nawawi en ~6 semaines
    case oneEveryTwoDays      // ~4/sem — Nawawi en ~11 semaines
    case threePerWeek         // 3/sem  — rythme scolaire (week-end + mercredi)
    case oneLessonPerWeek     // 1/sem  — mémorisation profonde
}
```

---

## 3. Architecture / fichiers à créer

Fichiers **plats** dans `Muslim Clock/` (convention réelle du repo — pas de sous-dossiers) :

```
IlmTrack.swift            Modèles Codable (IlmTrack, IlmLesson) + IlmProgress + IlmPlan + storage UserDefaults
IlmContentLoader.swift    Chargement bundle ilm_tracks.json — 1 seule lecture, cache mémoire (pattern QuranPageMapper)
IlmMath.swift             Fonctions pures : IlmProgressSummary, streak, solde (pattern QuranPlanMath)
IlmViewModel.swift        @MainActor @Observable — état plan+progression, actions (pattern QuranPlanViewModel)
IlmReminderScheduler.swift  Notifs quotidiennes préfixe ilm_reminder_ (enum statique, pattern QuranReminderScheduler)
IlmProgramCard.swift      Carte compacte Tab Rappel (pattern QuranKhatmaCard)
IlmTrackerView.swift      Sheet plein écran : ring, stats, CTA leçon du jour, liste parcours (pattern QuranTrackerView)
IlmLessonView.swift       Détail leçon : arabe/FR toggle, source, bouton « Leçon acquise » + célébration
IlmPlanSetupView.swift    Sheet Form : choix parcours, preset rythme, rappel (pattern QuranPlanSetupView)
ilm_tracks.json           Contenu des 3 parcours (FR + AR)
```

**Estimation** : ~900–1100 lignes Swift + 1 JSON. Modifs de l'existant : **2 lignes** (insertion card dans `DailyContentView` + target membership du JSON).

### Conformité principes (CLAUDE.md)

- **SRP** : contenu (loader) / calculs (math pur) / état (VM) / notifs (scheduler) / rendu (views) — cinq responsabilités, cinq fichiers, découpage identique à la Khatma.
- **OCP sans protocole** : extension par la donnée (D2). Aucun protocole tant qu'il n'y a qu'un implémenteur ; si un jour un test veut mocker le loader, on extraira l'interface **à ce moment-là**.
- **DIP** : les Views ne touchent jamais `UserDefaults` ni le loader — tout passe par `IlmViewModel`.
- **DRY inter-modules** : on **réutilise** `CosmicBackground`, `glassCard`/`CornerRadius`, `IslamicSeasonInfo`, le pattern toggle AR/FR de `DailyContentView`. On **duplique consciemment** le progress ring et les stat cells (~40 lignes privées dans `QuranTrackerView`) plutôt que de les extraire maintenant : 2 usages seulement, et « 3 lignes dupliquées valent mieux qu'une mauvaise abstraction ». → À la 3ᵉ occurrence, extraire `ProgressRing` + `StatCell` dans `DesignSystem.swift` (noté §7.3).
- **Robustesse** : décodage JSON aux frontières avec `do/catch` + `os.Logger` (jamais de swallow silencieux) ; si le JSON échoue → la card affiche un empty state neutre, l'app ne crashe jamais ; zéro `!`, zéro `try!` ; invariants du contenu (ids uniques, parcours non vides) vérifiés par `assert` en debug au chargement.
- **Localisation** : toutes les strings UI via `String(localized:)` (catalog `Localizable.xcstrings`). Le contenu (matn AR + traduction FR) vit dans le JSON — extension multilingue future = champs par locale dans le JSON, hors périmètre v1.4.

---

## 4. Points d'accroche dans l'existant

### 4.1 Navigation
1 ligne dans `DailyContentView` (sous `QuranKhatmaCard()`, ligne ~221) :
```swift
IlmProgramCard()
    .padding(.top, 10)
```

### 4.2 Notifications — coexistence
- Préfixe réservé : `ilm_reminder_` (à ajouter à l'inventaire des préfixes de `AUDIT_DEEPLINK_NOTIFS.md`).
- ≤ 7 notifs pendantes (1/jour, 7 jours glissants), re-planifiées à chaque ouverture de la card (idempotent : `removePendingNotificationRequests` ciblé sur le préfixe puis re-add).
- **Aucune modification** de `NotificationManager.scheduleBatchNotifications` ni de `QuranReminderScheduler`.
- Deep link tap-notif : même mécanique que `pendingOpenQuranTracker` → flag `@AppStorage("pendingOpenIlmTracker")` + notification `.ilmLessonTapped`. ⚠️ `Muslim_ClockApp.swift` poste `AdhanTriggered` à 2 endroits — on ne touche à rien de ce chemin, on ajoute une branche distincte sur l'identifiant `ilm_reminder_`.

### 4.3 Ce qu'on ne touche PAS
`SharedLocationManager`, `PrayerTimesViewModel`, `WatchSessionManager`, `modelContainer`, widgets, complication, watch app. Pas de synchro watch en v1.4 (hors périmètre §7.4).

---

## 5. UI / UX — même moule que la Khatma

### 5.1 Carte Tab Rappel (`IlmProgramCard`)
- **Empty state** : icône `books.vertical.fill` sur cercle dégradé, « Programme ʿIlm » / « Apprends les fondements de ta religion », chevron. Même gabarit exact que l'empty state Khatma.
- **État actif** : ligne titre + streak · barre de progression · « 12 / 42 leçons » + solde bienveillant.
- **Accent : `.purple`** (la Khatma est teal, l'orange = prière en cours, l'indigo = nuit — le violet distingue le savoir sans casser la sémantique couleur existante).

### 5.2 Sheet `IlmTrackerView`
Structure identique à `QuranTrackerView` : `NavigationStack` + `CosmicBackground` + `.preferredColorScheme(.dark)` :
1. **Ring de progression** (% du parcours actif, streak au centre).
2. **Stat row** : leçons acquises · restantes · fin estimée.
3. **Carte rythme** : « **3 leçons/semaine** — prochaine : *Hadith 13* ».
4. **CTA principal** « Étudier la leçon du jour » (fond `.purple.gradient`) → `IlmLessonView` de la prochaine leçon.
5. **Liste des 3 parcours** (mini barre de progression chacun, ✓ si terminé) → tap = détail/changement de parcours actif.
6. **Rappel doux** (cœur + citation sur le mérite du savoir — ex. « Celui qui emprunte un chemin à la recherche d'une science… », Muslim 2699).

### 5.3 `IlmLessonView` (détail leçon)
- Arabe en grand (police généreuse, `lineSpacing`, RTL), toggle FR/عربي **identique au pattern « Hadith du moment »** de `DailyContentView` (opacity crossfade + `.animation(.smooth)`).
- Source + badge d'authenticité (réutilise `HadithAuthenticityBadge` pour les hadiths).
- `ShareLink` (même format que le hadith du moment).
- Bouton **« Leçon acquise ✓ »** → haptique `.sensoryFeedback(.success)` + mini-célébration (pattern `celebrationOverlay` de `QuranPlanSetupView` : sceau + « ما شاء الله ») ; parcours terminé → célébration complète.
- Navigation ‹ précédente / suivante › pour relire librement (relire ne modifie jamais la progression — validation **explicite uniquement**).

### 5.4 `IlmPlanSetupView`
`Form` sur `CosmicBackground` (pattern exact `QuranPlanSetupView`) : section parcours (3 choix, coche animée `symbolEffect(.bounce)`) → section rythme (presets + stepper leçons/semaine) → section rappel (toggle + `DatePicker` heure) → bouton « Commencer » + célébration « بسم الله ».

### 5.5 Ton bienveillant (checklist héritée de l'audit Khatma)
- Jamais de rouge : retard = orange, phrasé positif (« il reste 2 leçons à rattraper »).
- Streak jamais culpabilisant (compté jusqu'à la semaine dernière incluse, pas la semaine en cours).
- Décocher une leçon est possible (erreur de tap) — sans message ni friction.

---

## 6. Risques & garde-fous

| Risque | Garde-fou |
|---|---|
| JSON contenu invalide/absent | `do/catch` + log, card en empty state, app fonctionnelle |
| Collision ids de leçons | `assert` debug à l'init du loader (Set des ids == count) |
| Dépassement budget notifs (64 iOS) | ≤ 7 pendantes, préfixe dédié, nettoyage ciblé avant re-add |
| Changement d'heure/DST sur le rappel quotidien | `UNCalendarNotificationTrigger` (heure locale) — pas de calcul manuel d'intervalle |
| Régression Khatma/notifs prière | zéro fichier partagé modifié hors l'insertion 1-ligne `DailyContentView` |
| Clés UserDefaults | 2 nouvelles clés `ilm_progress`, `ilm_plan` — à ajouter à l'inventaire memory (aucune collision avec l'existant) |

---

## 7. TODO / Réservations

### 7.1 Sources du contenu (validées 2026-07-06)
- **Matns arabes** : textes canoniques du domaine public — 40 Nawawi cités depuis sunnah.com (collection nawawi40) ; Thalâthat al-Uṣûl et al-Qawâʿid al-Arbaʿ depuis les éditions vérifiées courantes.
- **Traductions FR** : traductions propres (pas de reprise d'éditions publiées sous copyright). Références libres pour relecture croisée : IslamHouse (bureau de Rabwah).
- **Authenticité (40 Nawawi)** : gradings d'al-Albânî + ʿAbd al-Muḥsin al-ʿAbbâd (*Fatḥ al-Qawî al-Matîn*) — hadiths 30 et 41 signalés (chaînes discutées), 12 et 32 hasan ; le reste Bukhârî/Muslim.
- ⚠️ **Relecture religieuse humaine requise avant release** (exactitude des matns arabes + fidélité des traductions).

### 7.2 Modifs non-additives acceptées (minimes)
- 1 ligne `DailyContentView` (insertion card).
- 1 entrée What's New v1.4 (`WhatsNewView`).

### 7.3 Dette consciente (à traiter à la 3ᵉ occurrence)
- Extraction `ProgressRing` + `StatCell` vers `DesignSystem.swift` (aujourd'hui dupliqués Khatma/ʿIlm — 2 occurrences).

### 7.4 Hors périmètre v1.4 (chantiers futurs)
- **Révision espacée** (spaced repetition des leçons acquises) — v1.5 candidate, le modèle `completedAt: Date` le permet déjà sans migration.
- Audio des matns (récitation), synchro watch, widget ʿIlm, quiz/auto-évaluation, autres textes (Kitāb at-Tawhīd…) — ajout JSON seulement le jour venu.

---

## 8. Plan d'exécution Phase 2

1. **Contenu** : `ilm_tracks.json` (structure + contenu validé §7.1).
2. **Modèles + storage** : `IlmTrack.swift` (+ tests de décodage).
3. **Math** : `IlmMath.swift` (+ tests unitaires : %, solde, streak, DST).
4. **Loader** : `IlmContentLoader.swift` (+ assert invariants).
5. **ViewModel** : `IlmViewModel.swift`.
6. **Views** : `IlmLessonView` → `IlmTrackerView` → `IlmPlanSetupView` → `IlmProgramCard` (+ `RenderPreview` à chaque étape).
7. **Scheduler** : `IlmReminderScheduler.swift` + deep link.
8. **Intégration** : insertion `DailyContentView`, What's New, extraction strings l10n.
9. **Validation** : `BuildProject`, `RunSomeTests`, passe manuelle notifs (coexistence prière/Khatma/ʿIlm).

---

## Validation requise avant Phase 2
- [ ] D1–D7 approuvées (en particulier **D3 : pas de SwiftData** et **D5 : 1 rappel/jour** au lieu de post-prière)
- [ ] Découpage des leçons §2.1 approuvé
- [ ] Source des traductions FR confirmée
- [ ] Accent `.purple` + nom « ʿIlm » confirmés
