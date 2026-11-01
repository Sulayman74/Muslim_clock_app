# Revue de l'onglet Salat — réunion Design / UX / CTO

Date : 1er novembre 2026 · Version revue : 1.7.0 (build 13) · Périmètre : onglet « Salat » (tab 0) de `MainView.swift` et les 23 composants qu'il monte, `DesignSystem.swift`, `PLAN_UX_SALAT_ZONES.md`.

Trois audits indépendants ont été menés sur le code réel (lecture seule, aucune modification), puis confrontés aux captures du simulateur iPhone 17 (dossier `assets/`). La présentation visuelle avant/après est dans `index.html` (ouvrir dans Safari, mode plein écran pour projeter).

---

## 1. Résumé pour décision (à lire en 2 minutes)

**Verdict global : la structure est bonne, l'exécution est inégale.** Le plan en deux zones (glance puis « Pour aller plus loin ») est en place, les décomptes sont économes et le fiqh contextuel (Jumu'ah, Iftar, voyage, iqamah) est une vraie force. Mais l'écran ne tient pas sa promesse n°1 : **dire en 3 secondes quelle est la prochaine prière et combien de temps il reste.**

Les trois chefs convergent sur quatre constats :

| # | Constat partagé | Qui le remonte | Gravité |
|---|---|---|---|
| A | **L'information n°1 (décompte) est la plus petite de l'écran** (17 pt) sous une horloge de 65 pt, et la prochaine prière est affichée 3 fois | Design, UX | Haute |
| B | **L'état de prière se fige app ouverte** : pas de minuteur dans le ViewModel, la jauge reste à « Fajr -0:00 » après le lever du soleil, ou indéfiniment si les notifications sont refusées | UX, CTO | Critique |
| C | **Deux heures d'iqamah différentes à l'écran** par défaut : la liste dit +10 min, la carte de décompte +20/15 min | Design, UX, CTO | Haute |
| D | **Sans GPS, l'écran est vide** : squelettes perpétuels, trou de 100 pt, aucune action proposée (confirmé par la capture simulateur) | UX, CTO | Haute |

À cela s'ajoutent une dette de performance (MainView réévaluée jusqu'à 60 fois par seconde quand la boussole tourne), un Dynamic Type quasi absent (environ 150 tailles fixes) et un VoiceOver limité à 3 libellés sur tout l'écran.

**Recommandation de la réunion :** un sprint « Salat v2 » en trois lots, détaillé en section 5. Le lot 1 (une semaine) corrige les bugs visibles par l'utilisateur. Le lot 2 refond le héros et la hiérarchie. Le lot 3 traite accessibilité et performance.

---

## 2. Ce que montre le simulateur (captures `assets/`)

Captures prises le 1er novembre à 06:59, iPhone 17, iOS 27.0.

**Sans position GPS** (`avant-1-haut.png`, `avant-2-milieu.png`) :
- Horloge 06:59 dominante, dates FR + hégirien orange.
- Deux cercles en verre contenant des **squelettes gris**, pastille « Recherche… · Weather ».
- **Zone vide d'environ 100 pt** entre la pastille et « POUR ALLER PLUS LOIN » : la liste des prières et la jauge sont absentes sans laisser de place explicite.
- Badge « avant … » **tronqué** sur la carte Sunnah (la prière de contexte n'est pas connue).
- Aucune bannière, aucune invitation à autoriser ou saisir une ville. L'utilisateur n'a rien à faire et rien ne lui dit pourquoi.
- La page entière ne mesure que 927 pt : 200 pt de défilement.

**Avec position GPS, Paris, Fajr en cours** (`avant-gps-1-haut.png`, `avant-gps-2-milieu.png`) :
- Ordre vertical : horloge 07:02 (78 pt) → dates → « Horaires mis à jour à 7:01 » → cercle météo « 6°C » + cercle « Fajr jusqu'à 7:37 » → capsule « Paris · Météo » → carte « Temps du Fajr » de 218 pt (barre, « 6:27 → 7:37 », décompte « -34:34 », bouton « Invocations après la prière » de 58 pt) → trou de 50 pt → liste.
- **La première ligne de prière commence à y ≈ 700. Deux lignes visibles sur cinq**, et Dhuhr passe sous la tab bar.
- La prière en cours est représentée **trois fois** au-dessus du fold (cercle, carte, badge « En cours ») ; le décompte, seule valeur vivante, est le plus petit texte du groupe.
- L'iqamah de Fajr affichée dans la liste est 06:37 (+10 min), alors que la carte iqamah et les réglages comptent +20 min : la divergence est visible à l'écran.
- Page de 1 579 pt : un seul swipe mène en butée basse. Les lignes Asr/Maghrib/Isha font 76 pt chacune pour deux valeurs.
- Une étoile filante du fond traverse le texte « Horaires mis à jour » : le ciel animé concurrence la lecture.

---

## 3. Bilan par discipline

### 3.1 Head of Design — hiérarchie et système

**Hiérarchie visuelle.** L'élément dominant est l'horloge (`MainView.swift:305`, 65 pt monospaced). La prochaine prière apparaît dans un cercle de 120 pt en graisse *light* (`WeatherMiniWidget.swift:157`), l'en-tête du décompte en `headline`, et le décompte lui-même en `.body` (`PostPrayerAdhkarService.swift:115`). Le seul chiffre qui bouge est le plus petit.

**Échelle typographique.** 18 tailles distinctes de 8 à 65 pt, environ 85 % en `.system(size:)`. Trois familles pour afficher une heure : monospaced (horloge, décomptes), rounded light (NextPrayer), rounded bold (liste). `ScriptureFont` n'est utilisé que par la du'a de Ramadan ; le verset du rappel est en `.system(size: 19)` en contradiction avec `DesignSystem.swift:362`.

**Surfaces.** Six styles coexistent : `glassCard`, `glassCardSecondary`, `glassEffect` inline, `.ultraThinMaterial` + contour (Dhuhr, Iqamah, rayon 16), `cardStyle()` en `.regularMaterial` + ombre (TravelFiqh), aplats ad hoc (saison en dégradé, GPS en capsule bleue, salawat vert 0.08). Rayons en dur : 18, 16, 14, 12, 8 alors que `CornerRadius.card` vaut 20. Cinq valeurs de padding pour des cartes de même rang.

**Couleur.** `PrayerStateTint` n'est utilisé que dans MainView et ProphetSunnahCard ; `ModuleAccent` nulle part dans l'onglet. Collisions sémantiques : Iqamah en vert pendant une prière en cours (devrait être « now », orange), Jumu'ah en indigo (= nuit), rotation teal/indigo/purple/green du rappel qui recouvre tout. La teinte de l'onglet est `.red`, même couleur que l'alerte de la jauge et la localisation refusée.

**Densité.** Jour ordinaire : 2,1 à 2,3 écrans ; pire combinaison réaliste (vendredi de Ramadan en voyage, mise à jour disponible) : 3,4 écrans et 22 blocs. La liste des 5 prières commence vers y ≈ 600 un jour ordinaire, y ≈ 760 la nuit (carte Qiyam) : le test « 5 prières au-dessus du fold » du plan n'est tenu que partiellement. `SpiritualReminderCard` (260 pt, toujours affichée) est la carte la plus haute de la zone 2 alors qu'elle est la moins contextuelle.

**Mouvement.** `ShootingStarsLayer` tique à 30 Hz en permanence (`CosmicBackground.swift:256`), Canvas d'étoiles à 10 Hz, pulse infini sur le rappel, 2 à 3 décomptes à la seconde simultanés. Reduce Motion est bien géré pour le fond.

**Iconographie.** `building.columns.fill` sert à Jumu'ah, Iqamah de n'importe quelle prière, Salawat et Sunnah du vendredi. Jusqu'à **4 portes d'entrée Adhkar** en fenêtre de prière (bouton de la jauge, MomentCard, QuickAccess, Livret) vers 3 sheets différentes.

### 3.2 Head of UX — besoins, états, accessibilité

**Jobs-to-be-done.** Neuf besoins identifiés ; huit sont servis. **« Ai-je fait mes adhkar ? » n'a aucune réponse à l'écran** alors que la progression est persistée (`AdhkarView.swift:216-226`).

**Glance 3 secondes.** Hors fenêtre : horloge + dates + widgets + décompte occupent 525 pt, 2 à 3 prières visibles. **Juste après l'adhan**, moment critique : jauge 210 pt + carte iqamah 110 pt, la liste passe sous le fold (y ≈ 720). Chourouq (fin du Fajr) n'apparaît pas dans la liste.

**États.** `LocationDeniedBanner` existe mais aucun repli (ville manuelle, dernière position) ; `isLoading` ne repasse jamais à `false` si le calcul échoue (`PrayerTimesViewModel.swift:218`), d'où le squelette infini. `AdhkarMomentCard` calcule `topCategory` avec `Date()` sans TimelineView : suggestion périmée. `WuduMomentCard` et la catégorie « wudu » de l'AdhkarMoment peuvent s'empiler (2 cartes wudû').

**Cibles tactiles sous 44 pt** : partage du rappel (17 pt), ✕ voyage (24 pt), bouton FR/AR (20 pt), « Réglages » (28 pt), « Arrivé en retard ? » (16 pt), en-tête Lune (18 pt). Affordance trompeuse : les cercles en verre et les 5 lignes de prière ont la grammaire « bouton » d'iOS 26 mais ne font rien.

**Formats de temps.** `-1:23:45` (jauge), `59:12` (Dhuhr, Iqamah), « jusqu'à 19:42 » (widget), « à HH:mm » (Dhuhr). Aucune formulation naturelle (« dans 12 min »). `Text(timerInterval:)` se fige à 0:00 si le ViewModel ne bascule pas.

**Anti-wiggle (CLAUDE.md).** Les `.transition` des cartes conditionnelles sont posées sans `.animation` keyée → snap (`IqamahCountdownView.swift:27, 103`, `WuduFiqhView.swift:333`). Aucune transition sur AdhkarMoment, LocationDenied, TravelFiqh, Saison, Salawat. Pas de `geometryGroup` sur Sunnah et Lune (dépliables). FR/AR en `Group` qui swappe au lieu du `LanguageToggleChip` du design system. Hauteur **fixe** de 70 pt sur les lignes de prière au lieu d'un `minHeight`.

**Accessibilité.** 3 `accessibilityLabel` sur tout l'écran (horloge, attribution, badge Ramadan). Les widgets, la liste, les décomptes et la météo sont lus en fragments. Aucun texte arabe n'a d'attribut de langue ; l'arabe décoratif (« لِلاسْتِزَادَة », « حرام ») est lu avec la voix française. Dynamic Type : cercles de 100 pt et lignes de 70 pt fixes avec des textes qui, eux, grossissent → débordement en tailles AX. Contraste : blanc 0.35 (≈ 3:1) et 0.45 en 10-11 pt sous le seuil ; indigo système sur fond nuit ≈ 3.5:1. Mode clair : ni l'onglet ni la racine n'imposent `.preferredColorScheme(.dark)` alors que les textes sont `.white` (à vérifier en priorité).

**Localisation.** Dates forcées en `fr_FR` (`MainView.swift:18, 26`, `MoonWidgetView.swift:124, 329`), `°C` en dur, traductions du rappel et `labelFr` des saisons non localisés. RTL : chevrons et « → » codés en dur.

**Navigation.** 9 sheets, aucun push, aucun lien vers Qibla/Rappel/Apprendre. Doublons : Salawat du vendredi (Salat + Rappel), rappel coranique (Salat) vs verset du jour (Rappel), décompte Dhuhr vs décompte générique pendant 60 min, deux moteurs de suggestion parallèles (`AdhkarMomentCard` ici, `LearnSuggestionCard` ailleurs). Bug : en timing automatique le dégradé du soir est appliqué même le matin (`MainView.swift:715` teste `== .morning`).

### 3.3 CTO — architecture, performance, robustesse

**Architecture.** Une seule instance de chaque ViewModel, injectée par `environmentObject` ; `SharedLocationManager` reste la source unique. Mais MainView (959 lignes) est aussi un coordinator : deep-links, saisons, « quoi de neuf », planification adhkar, avec 8 `print` à chaque passage `.active`. Logique métier dans les `body` : règle Dhuhr → Jumu'ah (`MainView.swift:254-275`, dupliquée dans `NextPrayerWidget.displayName`), `DateFormatter` créés à chaque rendu (en-tête, lune, une par ligne de prière).

**Performance — le point le plus lourd.** MainView observe **environ 76 sources d'invalidation** (`PrayerTimesViewModel` 19 `@Published`, `PodcastManager` 21, `CompassManager` 10…). Deux changent très vite : le cap de la boussole jusqu'à **60 fois par seconde** (`CompassManager.swift:110-123`) et la position du podcast **2 fois par seconde**. À chaque tick, tout le `body` de MainView, TabView compris, est réévalué. Dans ce `body`, `IslamicSeasonInfo.current()` est appelé environ 11 fois (nouveau `Calendar(.islamicUmmAlQura)` à chaque appel), `WidgetDateHeader(date: .now)` et `MoonWidgetView(date: .now)` ne peuvent jamais être considérés inchangés. `DailyPrayer.id = UUID()` et `MoonDayInfo.id = UUID()` cassent l'identité des `ForEach`. `CosmicBackground` est instancié deux fois (onglets 0 et 2).

**Robustesse.** Aucun minuteur dans `PrayerTimesViewModel` : la fenêtre n'est recalculée que sur changement de position, `willEnterForeground` ou `AdhanTriggered` (`PrayerTimesViewModel.swift:135-153`). `forceRecalculation` s'appuie sur un `asyncAfter(0.5)` « pour que la bibliothèque Adhan voie que la prière est passée ». `AdhkarMomentCard` : `.task` attaché à un `Group` vide au départ → **la carte ne s'afficherait jamais** (`AdhkarBookletView.swift:343-356` ; le piège est documenté dans `RamadanDuaCardView.swift:109-113`, à confirmer sur appareil). `lastPrayerUpdate` est mis à jour avant le calcul, même s'il échoue. `center.add(request)` sans gestion d'erreur, `getPendingNotificationRequests` en callback. La cible app compile en **`SWIFT_VERSION = 5.0`** : les vérifications de concurrence Swift 6 ne sont pas actives.

**Persistance.** Clés iqamah littérales dans 6 fichiers avec des défauts divergents (tableau ci-dessous), `debugForceFriday` déclaré hors `#if DEBUG`, 11 `@AppStorage` hors `StorageKeys`, `travelModeActive` lu par MainView sans jamais servir (mais provoque un rendu).

| Prière | Settings / SmartSetup / IqamahCountdown / MainView | `PrayerListView` |
|---|---|---|
| Fajr | 20 | **10** |
| Dhuhr | 15 | **10** |
| Asr | 15 | **10** |
| Maghrib | 5 | 5 |
| Isha | 15 | **10** |

**Testabilité.** Bien extrait et testé : `DhuhrCountdownMath`, `IqamahMath`, `WuduWindowMath`, `RamadanDuaWindow`, `PrayerCalculationEngine`, `SharedPrayerSchedule`. Non testé : `IslamicSeasonInfo`, `ProphetSunnahProvider`, `MoonPhaseCalculator`, `NotificationDeepLink`, règles matin/soir et Jumu'ah des vues, garde-fou DST.

**Dette.** `RawatibCardView`/`RawatibInfo` (144 lignes mortes), `WeatherViewModel.moonSymbol` jamais lu, `View.if(_:)` sans appel, garde-fou dupliqué dans `calculatePrayers` (l.162-179), barre de progression en capsule recopiée 4 fois, 5 variantes de pastille « En cours / Prochaine / Vendredi ».

---

## 4. Ce qui est bien et à conserver

1. **Architecture en deux zones** avec ses tokens (`ZoneSpacing` 16/12/36, `ZoneSectionHeader` bilingue, `.isHeader`, `@ScaledMetric`) et le liseré `salatStateTint` qui relie les zones.
2. **Grammaire de verre à deux niveaux** : `glassCard` `.regular` pour le contenu, `glassCardSecondary` `.clear` pour le discret, avec repli opaque sous Réduire la transparence.
3. **Décomptes économes** : `Text(timerInterval:)` piloté par le système, cadence adaptative `barCadence`, horloge `.everyMinute`, `.id(end)` pour recréer le schedule après DST ou GPS.
4. **Contextualisation respectueuse du fiqh** : bascule Jumu'ah, badges Iftar/Sohoor, ghusl 3 h avant Jumu'ah, lien « retardataire » pile pendant l'iqamah, mode voyage qui suggère sans s'activer seul (niyyah).
5. **Logique de temps extraite et partagée** (`SharedPrayerSchedule` compilé dans les 4 cibles, maths pures testées) ; `WeatherViewModel` exemplaire (async, annulation, anti-spam, `os.Logger`, attribution WeatherKit) ; deep-links robustes au démarrage à froid.

---

## 5. Plan d'action proposé

### Lot 1 — Corrections visibles (≈ 1 semaine, coût S)

| Action | Fichiers | Pourquoi |
|---|---|---|
| Minuteur de recalcul dans le ViewModel : `Task` qui dort jusqu'à `min(currentWindowEnd, nextPrayerDate, minuit)` puis recalcule ; supprimer `asyncAfter(0.5)` ; inclure la fenêtre Isha de la veille | `PrayerTimesViewModel.swift` | Constat B |
| `IqamahDefaults` + `IqamahKeys` centralisés dans `StorageKeys`, un seul `delay(for:)` | 6 fichiers | Constat C |
| Conteneur toujours présent (`ZStack`) + TimelineView pour `AdhkarMomentCard` | `AdhkarBookletView.swift` | Carte probablement jamais affichée |
| État vide explicite sans GPS : message + bouton « Autoriser » / « Choisir une ville », `isLoading = false` sur échec, masquer la capsule « avant … » si inconnue | `MainView.swift`, `PrayerTimesViewModel.swift`, `ProphetSunnahCard.swift` | Constat D |
| Iqamah → `PrayerStateTint.now`, Jumu'ah → token dédié, rappel → `ModuleAccent.quran` fixe | 3 cartes | Sémantique couleur |
| Dhuhr et Iqamah → `glassCard(tint:)`, TravelFiqh → `glassCardSecondary`, Saison → `glassCard(tint:)` | 3 cartes | Surfaces |
| Transitions animées sur les cartes conditionnelles, `geometryGroup` sur Sunnah et Lune, `LanguageToggleChip` réutilisé | 6 cartes | Anti-wiggle |
| Cibles tactiles ≥ 44 pt (`frame(minWidth:minHeight:)` + `contentShape`) | 6 boutons | Apple HIG |
| Supprimer le bouton Adhkar de la jauge ou fusionner QuickAccess et Livret | `PostPrayerAdhkarService.swift`, `MainView.swift` | 4 portes → 2 |
| Dégradé matin/soir en timing automatique, dates et lune sans `fr_FR`, `°C` localisé | `MainView.swift`, `WidgetDateHeader`, `MoonWidgetView` | Bugs mineurs |

### Lot 2 — Héros et hiérarchie (≈ 2 semaines, coût M)

- **Un héros unique « Prochaine prière »** : nom + heure + décompte en 40-48 pt rounded `monospacedDigit`, teinté `PrayerStateTint`, formulation naturelle (« dans 1 h 23 » puis « dans 12 min », « Temps du Dhuhr, reste 2 h 10 »). L'horloge descend à 34-40 pt ou s'intègre au héros. `NextPrayerWidget` et `NextPrayerCountdownCard` disparaissent ; la météo devient une chip à côté de la ville.
- **Liste des 5 prières au-dessus du fold** : lignes 52-56 pt via `@ScaledMetric`, chapeau compacté (fraîcheur + GPS + voyage en une rangée de chips), Chourouq ajouté, hadith Qiyam déplacé en zone 2 repliable.
- **Fusion** Dhuhr → carte de décompte ; Wudu + catégorie wudu de l'AdhkarMoment → une carte ; `RamadanDua` après la liste et repliée hors Iftar/Suhoor.
- **Zone 2 plafonnée à 3 cartes contextuelles** (priorité : moment > sunnah > voyage) ; `SpiritualReminderCard` repliée par défaut ou déplacée vers Rappel ; Salawat du vendredi retiré de Salat (déjà dans Rappel).
- **Progression Adhkar visible** : anneau ou coche sur le bouton Adhkar (lecture de `adhkar_counts_*`).
- **Un seul moteur de suggestion** : `LearnSuggestionEngine` étendu au slot « adhkar du moment », `AdhkarMomentCard` devient un rendu de ce moteur.

### Lot 3 — Accessibilité et performance (≈ 2 semaines, coût M-L)

- `CompassManager` sort de MainView vers `QiblaView` ; `currentTime`/`duration` du podcast isolés dans un `@Observable` observé seulement par les players.
- Saison calculée une fois par passage (ou dans le ViewModel, rafraîchie à minuit) ; formatters `static let` ; dates issues d'une TimelineView ; identités stables pour `DailyPrayer` et `MoonDayInfo` ; `CosmicBackground` en une instance derrière la TabView, étoiles filantes planifiées sur `triggerTime` ; mesure Instruments avant/après.
- Échelle `AppFont` (text styles + `.rounded`), remplacement des `.system(size:)` composant par composant, `minHeight` à la place des hauteurs fixes, `@ScaledMetric` sur les cercles.
- VoiceOver : `.accessibilityElement(children: .combine)` + label sur héros, lignes, décomptes, météo ; `accessibilityHidden` sur l'arabe décoratif ; attribut de langue `ar` sur l'arabe lu ; contraste minimum 0.5 d'opacité sur fond cosmique ; Reduce Motion sur les `symbolEffect(.pulse)` ; `.preferredColorScheme(.dark)` vérifié à la racine.
- Coordinator extrait de MainView (`AppRouter` `@Observable`, `os.Logger`, constantes nommées), notifications en `async` avec `do/catch`, `SWIFT_VERSION = 6` sur la cible app, suppression du code mort (Rawatib, `moonSymbol`, `.if`, garde dupliqué), composants `ProgressCapsule` et `StatusChip` dans DesignSystem.
- Tests : `IslamicSeasonInfo`, `ProphetSunnahProvider`, `MoonPhaseCalculator`, `NotificationDeepLink`, `SalatContext` (prière de contexte, vendredi, saison) avec `now`/`calendar` injectés.

### Critères d'acceptation « Salat v2 »

1. Sur iPhone 16 et SE, sans scroller : héros + 5 prières visibles dans tous les états (hors fenêtre, en fenêtre, nuit, Ramadan).
2. Un seul affichage de la prochaine prière, un seul format de décompte.
3. Sans GPS : état vide explicite avec action, zéro squelette au-delà de 5 s.
4. Avec les réglages par défaut : une seule heure d'iqamah par prière, identique partout (liste, carte, widget, Watch).
5. App ouverte au lever du soleil : la jauge bascule seule sur « Prochaine : Dhuhr ».
6. VoiceOver lit le héros en une phrase ; Dynamic Type AX3 sans débordement ; Réduire les animations stoppe tous les effets.
7. Instruments : zéro réévaluation du `body` de MainView pendant la lecture d'un podcast ou la rotation de la boussole.
8. Zéro surface hors `glassCard`/`glassCardSecondary`, zéro rayon en dur, zéro couleur d'état hors `PrayerStateTint`/`ModuleAccent`.

---

## 6. Lot 1 — livré le 1er novembre 2026

Captures de vérification : `assets/final-gps-*.png` (Paris, après le lever du soleil) et `assets/final-sansgps-*.png` (position effacée).

| Action du lot 1 | Statut | Où |
|---|---|---|
| Minuteur d'état (fin de fenêtre / prochaine prière / minuit), `asyncAfter(0.5)` supprimé, garde-fou dédoublonné | Fait | `PrayerTimesViewModel.swift`, `PrayerCalculationEngine.nextRefreshDate` |
| Fenêtre Isha de la veille détectée après minuit ; marqueurs de la nuit en cours (pas de ce soir) avant le Fajr | Fait | `PrayerCalculationEngine.previousNightWindow`, `determineCurrentPrayerWindow` |
| Identités stables des lignes de prière (`id = name` au lieu de `UUID()`) | Fait | `DailyPrayer` |
| Iqamah : clés dans `StorageKeys`, défauts uniques `IqamahDefaults` (20/15/15/5/15), 6 fichiers alignés | Fait | `StorageKeys.swift` + PrayerListView, IqamahCountdownCard, Settings, SmartSetup, QuranKhatmaCard, MainView |
| `AdhkarMomentCard` : conteneur qui survit (la tâche de chargement s'attache), `now` vivant à la minute, transition animée | Fait | `AdhkarBookletView.swift` |
| État vide nommé avec action (refusée / non demandée / introuvable après 8 s / calcul échoué) ; liste en « --:-- » atténué ; `isLoading` ne démarre plus à `true` ; capsule « avant … » masquée sans horaires | Fait | `PrayerEmptyStateCard.swift`, `PrayerListView`, `PrayerTimesViewModel.calculationFailed` |
| Trous supprimés : zones en `spacing: 0`, chaque carte conditionnelle porte son espacement dans sa condition (mesuré : 16 pt en zone 1, 12 pt en zone 2) | Fait | `MainView.swift` + cartes |
| Couleurs d'état : Iqamah → `PrayerStateTint.now`, Jumu'ah → `PrayerStateTint.jumuah`, Dhuhr → `upcoming`, rappel → `ModuleAccent.quran` fixe, liste/widget via tokens, onglet Salat teinté par l'état | Fait | DesignSystem, IqamahCountdownView, PostPrayerAdhkarService, WeatherMiniWidget, MainView |
| Surfaces : Dhuhr/Iqamah → `glassCard(tint:)`, TravelFiqh → `glassCardSecondary`, suggestion voyage → `glassCard`, saison → `glassCard(tint:)` ; rayons 18 → `CornerRadius.card` | Fait | 5 cartes |
| Anti-wiggle : transitions animées (Dhuhr, Iqamah, Wudu, AdhkarMoment, TravelFiqh, état vide), `geometryGroup` Sunnah et Lune, FR/AR en ZStack + `LanguageToggleChip`, `minHeight` sur les lignes | Fait | 7 cartes |
| Cibles tactiles ≥ 44 pt : partage, ✕ et Activer voyage, FR/AR, en-têtes Sunnah et Lune, chevron hilal, « Arrivé en retard ? », GPS, boutons Adhkar | Fait | 8 composants |
| Portes Adhkar 4 → 2 : boutons retirés de la jauge, bouton d'accès rapide contextuel (après la prière / nuit / matin-soir) | Fait | `AdhkarQuickAccessButton`, `CurrentPrayerGaugeView` |
| Dégradé matin/soir de la sheet Adhkar en timing automatique ; `fr_FR` → locale courante ; `°C` → unité de la locale ; haptique à l'ouverture seulement | Fait | MainView, WidgetDateHeader, MoonWidgetView, WeatherViewModel |
| Verset du rappel en `ScriptureFont`, pulsation infinie retirée, Reduce Motion sur les pulses restants | Fait | SpiritualReminderCard, Iqamah, voyage |
| VoiceOver : lignes de prière, widget prochaine prière et météo lus en une phrase | Fait (début du lot 3) | WeatherMiniWidget |
| 19 nouvelles chaînes traduites en anglais et en arabe | Fait | `Localizable.xcstrings` |
| Tests : `PrayerStateRefreshTests` (7), `IqamahDefaultsTests` (2) ; 39 tests du périmètre verts ; build 0 warning | Fait | `Muslim ClockTests/` |

**Non fait, reporté :** saisie manuelle d'une ville (lot 2), mode clair à vérifier à la racine, Chourouq dans la liste (lot 2), attribution météo « Weather » en anglais quand l'image Apple n'est pas chargée (repli pré-existant).

**Écarts constatés après vérification, acceptés :** en mode arabe, la carte Sunnah garde la hauteur du texte français (choix anti-wiggle n°3, environ 55 pt de vide sous un hadith d'une ligne).

## 7. Lot 2 — livré le 1er novembre 2026

Captures de vérification : `assets/lot2-gps-*.png` (Paris, 08:12, prochaine Dhuhr) et `assets/lot2-rappel-deplie.png`.

**Mesuré sur iPhone 17 :** héros, puis Fajr, Chourouq, Dhuhr, Asr, Maghrib et Isha entièrement visibles sans scroller. Bas de la ligne Isha à 759 pt, haut de la tab bar à 791 pt. Critère d'acceptation n°1 tenu pour l'état « hors fenêtre » ; les états « en fenêtre » et « nuit » utilisent le même héros (hauteur identique, le hadith du qiyam a quitté la zone 1).

| Action du lot 2 | Statut | Où |
|---|---|---|
| Héros unique `PrayerHeroCard` : trois états (en cours / prochaine / nuit), Jumu'ah avec teinte dédiée, décompte naturel à la minute (« dans 4 h 23 », « reste 12 min »), barre à cadence adaptative, pied « start → end » | Fait | `PrayerHeroCard.swift`, `PrayerCountdownMath.swift` (7 tests) |
| Retrait des redondances : cercle « prochaine prière », cercle météo, carte « Prochaine : X », rappel « Dhuhr bientôt » (et son module de calcul + tests) | Fait | `WeatherMiniWidget.swift`, `PostPrayerAdhkarService.swift`, `IqamahCountdownView.swift` |
| Chapeau compact : horloge 34 pt rounded + dates sur une rangée, dates qui basculent à minuit ; chips ville · météo · fraîcheur (largeur plancher), bouton « Recalculer » en dessous si déplacement | Fait | `SalatClockHeader`, `SalatStatusChips` |
| Liste : lignes 54 pt via `@ScaledMetric`, espacement 8, ligne fine Chourouq après Fajr (aussi en état vide) | Fait | `PrayerListView` |
| Zone 2 : `NightPrayerCard` repliable (dernier tiers en en-tête, hadith et moitié de nuit au dépli), `SpiritualReminderCard` repliée par défaut, salawat du vendredi retiré (déjà dans Rappel), `RamadanDuaCardView` repliée hors Iftar/Suhoor | Fait | `PostPrayerAdhkarService.swift`, `RamadanDuaCardView.swift`, `MainView.swift` |
| Fusion wudû' : quand « Se préparer à la prière » est visible, « À réciter maintenant » passe à la suggestion suivante | Fait | `AdhkarMomentCard` |
| Progression Adhkar : anneau fait/total sur le bouton d'accès rapide (mode matin/soir), relu à la fermeture de la sheet ; clés et période de `AdhkarService` rendues statiques (plus de `!`) | Fait | `AdhkarQuickAccessButton`, `AdhkarService.savedProgress` |
| Formatters de date partagés et statiques (`WidgetDateHeader.gregorian/hijriFr/hijriAr`) | Fait | `MainView.swift` |
| 21 chaînes traduites en anglais et en arabe | Fait | `Localizable.xcstrings` |

**Non fait, reporté avec raison :**
- *Un seul moteur de suggestion* (fusionner `AdhkarMomentCard` dans `LearnSuggestionEngine`) : les deux moteurs n'ont ni les mêmes données (catégories du livret vs programmes d'apprentissage) ni la même règle d'effacement ; les fusionner couple le module Adhkar au module Apprendre. À traiter comme un chantier à part, pas dans un lot visuel.
- *Plafond générique de 3 cartes contextuelles en zone 2* : après la fusion wudû' et les retraits, les cartes contextuelles possibles sont Wudû', Nuit, À réciter maintenant et Voyage ; elles se chevauchent rarement. Un mécanisme de plafond n'a pas été ajouté (KISS).
- *Saisie manuelle d'une ville* : toujours à décider (demande une recherche de lieu et une persistance).

**Écart constaté, accepté :** pendant l'animation de dépli d'une carte repliable (0,25 s), la carte du dessous peut chevaucher le contenu qui apparaît ; à l'état stable tout est en place. Même comportement que la carte Sunnah du lot 1.

## 8. Complément lot 2 et début du lot 3 — livré le 1er novembre 2026

Décision de l'éditeur : coder le garde-fou de la zone 2 même pour les cas rares, corriger le chevauchement au dépli, sortir la boussole de MainView. Swift 6 attendra un audit dédié. Captures : `assets/lot2b-*.png`.

| Action | Statut | Où |
|---|---|---|
| Garde-fou zone 2 : planificateur pur `ZoneTwoPlanner` (plafond 3, priorité préparation > adhkar du moment > nuit > voyage), 4 tests | Fait | `ZoneTwoPlanner.swift`, `ZoneTwoPlannerTests.swift` |
| La zone décide, les cartes affichent : `SalatSecondaryZone` calcule les candidates (une horloge à 30 s, catégories du livret chargées une fois) et passe leurs données à `WuduMomentCard(variant:)`, `NightPrayerCard(times:)`, `AdhkarMomentCard(category:)`, `TravelFiqhCard`. Plus aucune logique de visibilité dans les cartes | Fait | `SalatSecondaryZone.swift` + 4 cartes |
| Emplacement conditionnel partagé `ZoneCardSlot` : conteneur qui survit, transition animée, espacement porté dans la condition | Fait | `DesignSystem.swift` |
| Dépli sans chevauchement : `collapsibleCard` (verre + contenu clippé à la forme + bloc géométrique) et contenu déplié en fondu, sur Sunnah, Rappel, Nuit, Lune, Ramadan | Fait, vérifié : aucun débordement hors du verre pendant ni après l'animation | `DesignSystem.swift` + 5 cartes |
| Boussole hors de MainView : `QiblaView` possède son `CompassManager` (démarré/arrêté avec l'écran) ; la ville est géocodée par `SharedLocationManager` (re-géocodage au-delà de 5 km, plus de ville figée au premier fix) ; MainView n'observe plus la boussole | Fait, vérifié : « Paris » dans le chapeau Salat et sous le titre Qiblah | `MainView.swift`, `QiblahView.swift`, `CompassManager.swift`, `SharedLocationManager.swift` |

**Observé pendant la vérification, hors périmètre :** sur l'onglet Qiblah, avant la première mesure de cap, l'écart affiché vaut 180° par défaut avec un cap à 0° (valeur initiale de `angularOffset`, pré-existante). Le scroll de l'onglet Salat revient en haut après un aller-retour vers Qiblah ; à confirmer sur la version précédente avant d'y toucher.

**Reste du lot 3 :** position de lecture du podcast isolée dans un objet observé seulement par les lecteurs, saison calculée une fois par rendu, fond cosmique en une instance, Dynamic Type et VoiceOver systématiques, extraction du coordinateur de MainView, Swift 6 après audit.

## 9. Annexes

- Rapports complets des trois audits : `audit-design.md`, `audit-ux.md`, `audit-cto.md` (ce dossier).
- Captures : `assets/avant-*.png`.
- Présentation : `index.html`.
