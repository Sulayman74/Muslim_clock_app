# Audit Design — onglet Salat (1er novembre 2026)

Périmètre lu : `MainView.swift` l.286-467 et tous les composants montés, `DesignSystem.swift` et `PLAN_UX_SALAT_ZONES.md`. Le plan en 2 zones est bien en place. Les tokens `ZoneSpacing`, `glassCardSecondary` et `ZoneSectionHeader` existent et sont utilisés. Les défauts restants touchent surtout la hiérarchie du héros, la sémantique des couleurs et l'hétérogénéité des surfaces. Les hauteurs sont des estimations faites à la lecture du code, confirmées ensuite par les captures simulateur (`assets/`).

## 1. Hiérarchie visuelle

L'info n°1 est la prochaine prière et son décompte. Dans les faits, l'élément dominant est l'horloge.

| Élément | Fichier:ligne | Rendu | Poids visuel |
|---|---|---|---|
| Horloge HH:mm | MainView.swift:305 | `.system(size: 65, .semibold, design: .monospaced)`, blanc | Dominant absolu |
| Heure de la prochaine prière | WeatherMiniWidget.swift:157 | `size: 24/22, weight: .light, .rounded`, cercle de 120 pt | Faible : graisse light, petit cercle |
| Nom de la prochaine prière | WeatherMiniWidget.swift:145 | 16 bold rounded | Faible |
| Décompte (`-01:23:45`) | PostPrayerAdhkarService.swift:115-116 et 448-449 | `.body` monospaced bold (≈17 pt), vert ou orange | Sous-dimensionné : c'est la vraie info n°1 |
| En-tête de la jauge « Prochaine : Dhuhr 13:45 » | PostPrayerAdhkarService.swift:407-411 | headline + title3 mono | Moyen |
| Ligne de la liste (prochaine prière) | WeatherMiniWidget.swift:207, 239 | headline + title3 rounded bold, vert | Moyen |

Hors fenêtre de prière, la même information apparaît trois fois au-dessus du fold : le cercle NextPrayer, l'en-tête de `NextPrayerCountdownCard` et le badge « Prochaine » de la liste. En fenêtre, l'heure de fin (« jusqu'à 20:30 ») est répétée dans la jauge (« 19:10 → 20:30 », l.107). Trois blocs de taille moyenne se disputent l'attention, et le seul chiffre qui change (le décompte) est le plus petit.

Tailles numériques trouvées : en-tête 65, 14, 13, 11 ; bannière localisation 14, 13, 12, 11 ; saison 16, 14, 11, 10 ; fraîcheur 10 ; météo 34 ; attribution 12, 11, 10, 9 ; NextPrayer 24, 22, 16, 10 ; Dhuhr 22, 15 ; Iqamah 24, 15 ; liste 12, 10, 8 ; badge Ramadan 10, 9 ; du'a Ramadan 22 (Amiri), 14 ; Wudu et Moment 16, 15, 12, 11 ; Adhkar compacts 18, 12 ; ProphetSunnah 17, 16, 14, 13, 12, 11, 10, 9 ; SpiritualReminder 19, 14, 11 ; Salawat 14, 12, 11 ; Lune 28, 20, 13, 12, 11, 10, 9 ; Hilal 15, 11, 10, 9, 8. **18 tailles distinctes, de 8 à 65 pt. Il n'y a pas d'échelle.**

## 2. Équilibre et densité

| Zone | Carte | Hauteur estimée | Condition |
|---|---|---|---|
| Chapeau | Horloge (+20 marge haute) | ~98 | toujours |
| | Dates | ~28 | toujours |
| | Ligne de fraîcheur | ~14 | presque toujours |
| | Bouton GPS « Recalculer » | ~32 | déplacement > 15 km |
| | Pastille ou bannière voyage | 26 / ~56 | voyage |
| | Localisation refusée | ~56 | GPS refusé |
| | Bannière de saison | ~46 | mois marqués |
| Zone 1 | Météo + NextPrayer + attribution | ~156 | toujours |
| | Jauge : décompte / en cours / qiyam | ~138 / ~210 / ~290 | selon l'état |
| | DhuhrCountdownCard | ~72 | dernière heure avant Dhuhr |
| | IqamahCountdownCard | ~112 | entre adhan et iqamah |
| | PrayerListView (5 × 70 + 4 × 12) | ~398 | toujours |
| | RamadanDuaCardView | ~230-270 | Ramadan |
| Zone 2 | ZoneSectionHeader | ~22 | toujours |
| | WuduMomentCard | ~110 | 45 min avant, 3 h avant Jumu'ah |
| | AdhkarMomentCard | ~110 | catégorie pertinente |
| | Rangée Adhkar 2 × ½ | ~50 | toujours |
| | ProphetSunnah (repliée) | ~70 | toujours |
| | SpiritualReminderCard | ~260 | toujours |
| | TravelFiqhCard | ~60 | voyage |
| | Salawat du vendredi | ~40 | vendredi |
| | Lune (repliée) | ~50 / ~80 | toujours |

Espacements : 20 dans le chapeau, 16 en zone 1, 36 entre zones, 12 en zone 2. Bannière de mise à jour (`safeAreaInset`, ~70 pt) possible.

Où commencent les 5 prières (iPhone 15/16, ~770 pt visibles avant la tab bar) :
- Jour ordinaire après le lever du soleil : liste vers y ≈ 600, 2 à 3 lignes visibles.
- En fenêtre de prière : y ≈ 680, 1 à 2 lignes (confirmé par `avant-gps-1-haut.png` : liste à y ≈ 700, 2 lignes).
- La nuit (carte qiyam) : y ≈ 760, liste entièrement sous le fold.

Longueur totale : jour ordinaire ≈ 1 700 pt (2,1 à 2,3 écrans) ; pire combinaison réaliste (Ramadan + vendredi + voyage + GPS déplacé + saison + mise à jour + fenêtre Maghrib avec iqamah + Wudu avant Isha) ≈ 2 700 pt (3,4 écrans), liste vers y ≈ 1 100. `SpiritualReminderCard` (toujours affichée, ~260 pt) est la carte la plus haute de la zone 2, alors qu'elle est la moins contextuelle.

## 3. Cohérence du système

Surfaces :

| Style | Composants |
|---|---|
| `glassCard` (`.regular` + teinte 0.12) | lignes de PrayerList, jauge (3 états), RamadanDua |
| `glassEffect` inline | Météo cercle (WMW:104), NextPrayer (WMW:165), attribution `.clear` (WMW:43), bouton de la jauge (PPAS:136), bouton Réglages de LocationDenied |
| `glassCardSecondary` | Wudu, Moment, QuickAccess, Booklet, ProphetSunnah, SpiritualReminder, Lune |
| `.ultraThinMaterial` + contour, rayon 16 | DhuhrCountdownCard (IqamahCountdownView.swift:64-69), IqamahCountdownCard (l.175-180) : en zone prioritaire, hors système |
| `cardStyle()` (`.regularMaterial` + ombre) | TravelFiqhCard (TravelFiqh.swift:160), TravelSuggestionBanner, AppUpdateBanner |
| Aplats ad hoc | SeasonBanner dégradé (IslamicSeasonInfo.swift:254-261), LocationDenied rouge 0.85, GPS capsule bleue + contour (PPAS:596-599), Salawat capsule verte 0.08 (DailyContentView.swift:465), bouton qiyam indigo 0.2 (PPAS:204-205), placeholder Ramadan `.ultraThinMaterial` |

Rayons : `CornerRadius.card` = 20 est la source de vérité. En dur : 18 (Adhkar compacts AdhkarView.swift:627, AdhkarBookletView.swift:282, placeholder Ramadan), 16 (Dhuhr, Iqamah, bouton qiyam), 14 (Saison, cellules Lune, Hilal), 12 (encart ProphetSunnah l.324), 8 (Hilal). `.continuous` manque sur Saison, bouton qiyam, Lune, Hilal.

Paddings internes : 24 (jauge), 20 (SpiritualReminder, lignes de liste), 16 (Wudu, Moment, Sunnah, Lune, Ramadan), 14 (Dhuhr, Iqamah), 16×12 (TravelFiqh), 14×10 (Salawat, LocationDenied). Cinq valeurs pour des cartes de même rang.

Espacements : `ZoneSpacing` respecté entre les cartes. Écarts : le chapeau hérite du `VStack(spacing: 20)` (MainView.swift:441) puis compense avec des paddings négatifs (`-8` l.316, `-4` l.322, `-6` l.333) → token manquant ; groupe météo `spacing: 10` (l.341) ; liste à 12 alors que la zone est à 16.

Couleurs ad hoc :
- NextPrayerWidget : `.orange` / `.green` en dur (WMW:139) au lieu de `PrayerStateTint`.
- PrayerListView : `.green`, `.orange`, `.indigo.opacity(0.6)`.
- Jauge : `.orange`, `.red` au-delà de 85 %, `.indigo` (qiyam), `.green` (décompte).
- DhuhrCountdownCard : `.yellow`, `.indigo` pour Jumu'ah (collision avec `PrayerStateTint.night`).
- IqamahCountdownCard : `.green` alors que la prière est en cours (devrait être orange).
- SpiritualReminderCard : rotation `.teal` / `.indigo` / `.purple` / `.green`.
- Attribution météo `.indigo` ; Salawat et badge « Vendredi » `.green` ; Lune `.orange` / `.indigo` ; Hilal `.yellow` ; hégirien `.orange` ; GPS `.blue`.
- Teinte de l'onglet Salat `.red` (MainView.swift:278), identique à l'alerte de la jauge, au badge hors ligne et à la localisation refusée.
- RGB littérales : `adhkarBookletAccent`, accents matin/soir (AdhkarView.swift:74-75), `ProphetSunnah.accentColor` (5 RGB), `ramadanNightTint`, badge Iftar (WMW:292), `bannerColors`.

`PrayerStateTint` n'est utilisé que dans MainView (l.290-292) et ProphetSunnahCard (l.248). `ModuleAccent` dans aucun composant de l'onglet.

## 4. Typographie

- `.system(size:)` domine (~85 % des textes). Text styles Dynamic Type seulement dans la jauge, noms/heures de PrayerList, fraîcheur, bouton GPS, voyage, TravelFiqh, ZoneSectionHeader. Tailles fixes qui cassent en AX : `frame(height: 70)` sur les lignes (WMW:256), cercles 100×100 (WMW:102, 163).
- Arabe : `ScriptureFont` seulement sur RamadanDua (l.148). Le verset coranique de SpiritualReminder est en `.system(size: 19)` (PPAS:347), contraire à DesignSystem.swift:362. Hadith Wudu (16), dhikr Moment (16), Sunnah (17), Salawat (14 bold), Hilal (15) en système.
- Chiffres : trois familles pour une heure (monospaced horloge/décomptes ; rounded light NextPrayer ; rounded bold liste). `monospacedDigit` manque sur les heures de PrayerList (WMW:238-239) et l'iqamah (l.249).
- La police monospaced de l'horloge (look « terminal ») détonne dans une app en `.rounded`.

## 5. Iconographie et libellés

- Symboles surchargés : `building.columns.fill` (Jumu'ah, Iqamah de toute prière IqamahCountdownView.swift:121, Salawat, Sunnah du vendredi) ; `moon.stars.fill` (qiyam, Isha, rappel, Lune, Suhoor) ; `book.closed.fill` (Livret, Fiqh voyage, Sunnah, rappel) ; `sunset.fill` (Maghrib, Adhkar du soir, Iftar) ; `hands.sparkles.fill` (post-prière et rappel).
- Portes d'entrée Adhkar : jusqu'à 4 à la fois en fenêtre de prière (bouton de la jauge PPAS:128-139, AdhkarMomentCard, QuickAccess, Booklet), 3 sheets différentes.
- Libellé dupliqué possible : « Mise à jour de la position… » dans PrayerFreshnessLine (PPAS:549) et GPSRelocationIndicator (PPAS:586).
- ZoneSectionHeader « Pour aller plus loin / لِلاسْتِزَادَة » bien fait.
- Icône d'onglet `timer` : métaphore chronomètre, faible pour une app de prière.
- `fr_FR` en dur : WidgetDateHeader (l.18, 26), MoonDayCell (l.329).

## 6. Mouvement

- CosmicBackground : Canvas d'étoiles (70 étoiles, 25 particules) à 10 Hz ; ShootingStarsLayer à 30 Hz en permanence (CosmicBackground.swift:256) alors que le commentaire dit « actives ~10 % du temps » ; sous 15 à 20 surfaces Liquid Glass. Reduce Motion géré (l.91, 97).
- TimelineViews actives : horloge (minute), jauge (adaptative), Dhuhr (10 s), Iqamah (2 s), Wudu (30 s), tâche 60 s RamadanDua. Deux ou trois `Text(timerInterval:)` à la seconde simultanés possibles.
- Pulsations : `.pulse.byLayer` infini sur SpiritualReminder (PPAS:319), `.pulse` sur Iqamah, suggestion voyage, mise à jour.

## 7. Top 10 (par impact)

| # | Problème | Recommandation | Coût |
|---|---|---|---|
| 1 | Info n°1 noyée : décompte 17 pt sous horloge 65 pt, prochaine prière affichée 3 fois | Héros unique « Prochaine prière » : nom, heure, décompte 40-48 pt rounded + `monospacedDigit`, teinté `PrayerStateTint`. Horloge à 34-40 pt ou intégrée. Météo en chip. Supprimer `NextPrayerWidget` | M |
| 2 | Les 5 prières sous le fold (y ≈ 600 à 1 100) | Lignes 52-56 pt via `@ScaledMetric`, chapeau compacté (chips), jauge qiyam repliable, RamadanDua après la liste | M |
| 3 | Sémantique couleur cassée (Iqamah vert, Jumu'ah indigo, rotation du rappel, orange/vert en dur) | Tout via `PrayerStateTint` ; Iqamah → `.now` ; Jumu'ah → token dédié ; rappel → `ModuleAccent.quran` | S |
| 4 | Surfaces hétérogènes (Dhuhr/Iqamah `.ultraThinMaterial` r16, TravelFiqh `cardStyle`, saison dégradé r14) | → `glassCard(tint:)` / `glassCardSecondary` ; déprécier `cardStyle` | S |
| 5 | Dynamic Type quasi absent (~85 % `.system(size:)`, hauteurs fixes) | Échelle `AppFont` ; `@ScaledMetric` sur les frames | L |
| 6 | Arabe scripturaire hors `ScriptureFont` | `ScriptureFont.arabic(.arabicCompact)` sur rappel, hadith Wudu, dhikr Moment, Sunnah AR, Hilal ; token `arabicLabel` | S |
| 7 | 4 portes d'entrée Adhkar | Supprimer le bouton de la jauge ou fusionner QuickAccess et Booklet | S |
| 8 | Délais d'iqamah incohérents (liste 10/10/10/5/10 vs carte 20/15/15/5/15) | `IqamahDefaults` unique | S |
| 9 | Chiffres en 3 familles, liste sans `monospacedDigit` | Une famille (rounded + `monospacedDigit`), horloge incluse | S |
| 10 | Charge de mouvement (30 Hz permanent, pulse infini, décomptes simultanés) | Étoiles filantes planifiées ; pulse ponctuel ; un seul décompte à la seconde | S-M |

Points mineurs : paddings négatifs du chapeau, 18 tailles de police, `fr_FR` codé en dur, `.continuous` manquant, doublon « Mise à jour de la position… ».

## 8. À conserver

1. Architecture en deux zones et tokens (`ZoneSpacing` 16/12/36, `ZoneSectionHeader` bilingue, `.isHeader`).
2. Grammaire de verre à deux niveaux avec repli opaque sous Réduire la transparence.
3. Cartes contextuelles au bon moment (Wudu, Dhuhr, Iqamah, Moment), cartes d'enrichissement repliées (Sunnah, Lune).
4. Performance des décomptes (`Text(timerInterval:)`, `barCadence`, horloge à la minute, `.id(end)`).
5. Reduce Motion sur le ciel, `layoutDirection(.rightToLeft)` sur l'arabe, label VoiceOver sur l'horloge, `sensoryFeedback` sur les replis.
