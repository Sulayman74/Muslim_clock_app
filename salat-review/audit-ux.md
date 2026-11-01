# Audit UX — onglet Salat (1er novembre 2026)

Périmètre : l'onglet Salat de `MainView.swift` et les 23 composants qu'il monte, `PLAN_UX_SALAT_ZONES.md` et le protocole anti-wiggle de `CLAUDE.md`. Chemins relatifs à `Muslim Clock/`. Les hauteurs ont été confirmées par les captures simulateur (`assets/`).

## 1. Jobs-to-be-done et « glance 3 secondes »

| # | Besoin | Ce qui le sert | Position |
|---|---|---|---|
| J1 | Quelle heure, quel jour (grégorien, hégirien) | Horloge `MainView.swift:303-312`, `WidgetDateHeader` | 1 |
| J2 | Prochaine prière / en cours | `NextPrayerWidget` `WeatherMiniWidget.swift:110-169` | 2 |
| J3 | Combien de temps reste-t-il | `CurrentPrayerGaugeView` `PostPrayerAdhkarService.swift:47-242`, `DhuhrCountdownCard`, `IqamahCountdownCard` | 3 |
| J4 | Les 5 horaires et l'iqamah | `PrayerListView` `WeatherMiniWidget.swift:172-264` | 4 |
| J5 | Les horaires sont-ils fiables | `PrayerFreshnessLine`, `GPSRelocationIndicator`, `LocationDeniedBanner` | chapeau |
| J6 | Me préparer (wudû', ghusl, sunnah) | `WuduMomentCard`, `ProphetSunnahCardView` | zone 2 |
| J7 | Réciter (adhkar) | Bouton jauge, `AdhkarMomentCard`, QuickAccess, Booklet | 3 et zone 2 |
| J8 | Ai-je fait mes adhkar ? | **Aucun composant** (progression persistée `AdhkarView.swift:87, 140-226`, jamais affichée) | absent |
| J9 | Contexte du moment (Ramadan, voyage, vendredi, lune) | `SeasonBanner`, `RamadanDua`, `TravelMode*`, `FridaySalawat`, `MoonWidget` | dispersé |

Sans scroller (~710 pt utiles iPhone 16, ~600 SE) :
- Hors fenêtre : horloge + dates + fraîcheur (~180), widgets + attribution (~156), décompte (~140) ; la liste commence vers ~525 pt, 2 à 3 prières visibles.
- Juste après l'adhan : jauge « Temps du X » ~210 pt + iqamah ~110 ; la liste passe à ~720 pt, sous le fold. Confirmé par `avant-gps-1-haut.png` (Fajr en cours : 2 lignes visibles, Dhuhr sous la tab bar).
- La nuit : carte Qiyam ~290 pt.
- Redondance : prochaine prière affichée 3 à 4 fois. Chourouq absent de la liste.

## 2. États

| Composant | États gérés | Manques |
|---|---|---|
| Horloge, dates | toujours | Dates forcées `fr_FR` (`MainView.swift:18, 26`) |
| `PrayerFreshnessLine` `:540-561` | GPS en cours, « mis à jour à » | Rien avant le premier calcul ; pas d'état échec GPS / horaires anciens |
| `GPSRelocationIndicator` `:565-604` | > 15 km, spinner | `.transition(.scale)` sans `withAnimation` |
| `TravelModeHeader` `TravelModeUI.swift:33-52` | pastille, suggestion, ignorée | OK |
| `LocationDeniedBanner` `MainView.swift:148-187` | refusé/restreint | Aucun repli (ville manuelle, dernière position) ; squelette indéfini car `isLoading` jamais levé |
| `SeasonBannerView` | mois marqués, badge « حرام » | Pas de transition |
| `WeatherMiniWidget` `:87-107` | redacted, erreur | `°C` en dur (`WeatherViewModel.swift:102`) ; squelette perpétuel sans position |
| `NextPrayerWidget` | prochaine, en cours, chargement | « ... » / « --:-- » |
| `CurrentPrayerGaugeView` | en cours, Qiyam, décompte, vide | État non recalculé en direct (problème n°1) |
| `DhuhrCountdownCard` | 60 min avant Dhuhr/Jumu'ah | Doublon de `NextPrayerCountdownCard` |
| `IqamahCountdownCard` | adhan → iqamah | Pas d'iqamah le vendredi, non signalé |
| `PrayerListView` | en cours, prochaine, passée, badges Ramadan | Liste vide = trou ; défauts iqamah divergents |
| `RamadanDuaCardView` | Iftar, Suhoor, général, chargement | Placeholder → contenu sans animation |
| `WuduMomentCard` WuduFiqhView.swift:310 | 45 min avant ; ghusl 3 h avant Jumu'ah | Peut doubler la catégorie « wudu » de l'AdhkarMoment |
| `AdhkarMomentCard` `AdhkarBookletView.swift:324-401` | suggestion / absente | `topCategory` avec `Date()` sans TimelineView ; sans transition |
| `ProphetSunnahCardView` | replié/déplié, FR/AR | Sans position : « avant ... » (confirmé `avant-1-haut.png`) |
| `SpiritualReminderCard` `:256-377` | rotation horaire | Toujours visible ; FR non localisé |
| `TravelFiqhCard`, `FridaySalawatMiniReminder`, `MoonWidgetView` | voyage, vendredi, jours blancs, hilal | Salawat doublé dans Rappel (`DailyContentView.swift:46`) |

Scénario le plus chargé (vendredi de Ramadan ≥ 20, voyage, > 15 km, 40 min avant Jumu'ah, mise à jour, hors ligne) : ~22 blocs, > 2 400 pt, 6 surfaces visuelles différentes.

Scénario le plus vide (GPS refusé / premier lancement) : horloge, bannière rouge (ou rien), deux squelettes, trou, « Pour aller plus loin », sunnah « avant ... ». Confirmé sur simulateur : trou d'environ 100 pt, aucune action proposée.

## 3. Actions

| Cible | Fichier:ligne | Taille | ≥ 44 | Destination | Haptique |
|---|---|---|---|---|---|
| « Réglages » (localisation refusée) | MainView.swift:167-177 | ~28 | ✗ | URL Réglages | ✗ |
| Recalculer la position | PostPrayerAdhkarService.swift:571-600 | ~32 | ✗ | action | ✗ |
| Activer / ✕ (voyage) | TravelModeUI.swift:98-115 | ~28 / ~24 | ✗ | action | ✗ |
| Logo attribution météo | WeatherMiniWidget.swift:59-72 | 12 | ✗ (légal) | Safari | ✗ |
| Invocations après la prière / nuit | PostPrayerAdhkarService.swift:128-139, 196-207 | ~52 | ✓ | sheet | ✗ |
| « Arrivé en retard ? » | IqamahCountdownView.swift:160-172 | ~16 | ✗ | sheet | ✗ |
| Carte wudû', carte adhkar du moment | WuduFiqhView.swift:403, AdhkarBookletView.swift:395 | carte | ✓ | sheet | ✓ (aussi à la fermeture) |
| QuickAccess / Livret | AdhkarView.swift:656, AdhkarBookletView.swift:309 | ~46 | ✓ juste | sheet | ✓ idem |
| En-tête Sunnah, bouton FR/AR | ProphetSunnahCard.swift:221-266, 273-283 | 38 / ~20 | ✗ | dépli | ✓ |
| Partager le rappel | PostPrayerAdhkarService.swift:335-339 | ~17 | ✗ | ShareLink | ✗ |
| En-tête lune, chevron hilal | MoonWidgetView.swift:133-156, 255-260 | ~18 / ~12 | ✗ | dépli | ✓ / ✗ |
| Fiche voyage | TravelFiqh.swift:139-162 | ~50 | ✓ | sheet | ✗ |
| Pull-to-refresh | MainView.swift:452-461 | — | — | GPS + météo | système |

Affordance trompeuse : les deux cercles en verre et les 5 lignes de prière (grammaire bouton iOS 26) ne font rien ; la bannière de saison, la capsule salawat, la carte Dhuhr non plus. Inversement le rappel n'a qu'un bouton de partage minuscule.

## 4. Feedback et temps

- Fraîcheur : « Horaires mis à jour à 08:12 » ne dit pas pour quelle ville (ville 200 pt plus bas).
- Formats de décompte : `-1:23:45` (jauge, décompte `:115, :448`), `59:12` (Dhuhr, iqamah `IqamahCountdownView.swift:58, 139`), « jusqu'à » + heure (`NextPrayerWidget:151`), « à HH:mm » (Dhuhr `:51`). Aucune formulation naturelle.
- Fin de décompte : `Text(timerInterval:)` se fige à 0:00 ; si la VM ne bascule pas, « -0:00 » indéfiniment.
- `monospacedDigit` absent sur les heures de la liste (`WeatherMiniWidget.swift:238-250`) et « 07:12 → 08:40 ».
- `PrayerListView.swift:196` crée un `DateFormatter` par ligne et par rendu.

Protocole anti-wiggle :

| Règle | Statut | Fichier:ligne |
|---|---|---|
| 4 transition + animation sur conteneur | ✗ partiel : `.transition` sans `.animation` keyée → snap | IqamahCountdownView.swift:27, 103 ; WuduFiqhView.swift:333 |
| 4 | ✗ aucune transition | AdhkarMomentCard :343, LocationDeniedBanner MainView:327, TravelFiqhCard :139, SeasonBanner, Friday MainView:412 |
| 1 contenu asynchrone | ✗ | RamadanDuaCardView.swift:114-120, AdhkarMomentCard |
| 3 FR/AR en ZStack, `minWidth` | ✗ `Group` qui swappe ; `LanguageToggleChip` non réutilisé | ProphetSunnahCard.swift:273-310 |
| 5 `minHeight` | ✗ hauteur fixe 70 pt | WeatherMiniWidget.swift:256 |
| 6 `geometryGroup` | ✗ Sunnah, Lune | ProphetSunnahCard.swift:342, MoonWidgetView.swift:222 |
| `.id()` sur la jauge | ✓ explicite | PostPrayerAdhkarService.swift:125, 235, 457 |

## 5. Accessibilité

- VoiceOver : 3 labels sur l'écran (horloge `MainView.swift:311`, attribution, badge Ramadan). `NextPrayerWidget` lu en 3 fragments ; ligne de prière sans `.combine` ; météo lit un nom de symbole et « --°C » ; décomptes sans label. Étape 7 du plan non faite.
- En-têtes : `ZoneSectionHeader` `.isHeader` ✓ mais lit l'arabe décoratif avec la voix FR. Aucun titre de carte en en-tête.
- Arabe : aucun attribut de langue ; échos décoratifs (« لِلاسْتِزَادَة », « حرام », hégirien arabe) devraient être `accessibilityHidden`.
- Dynamic Type : ~150 `.font(.system(size:))` fixes sur 15 fichiers, un seul `@ScaledMetric` (en-tête de zone). Cercles 100 pt fixes (`WeatherMiniWidget.swift:102, 163`), lignes 70 pt fixes avec `.headline`/`.title3` qui grossissent → débordement AX.
- Contraste (fond ≈ #0A0A1F) : blanc 0.5 ≈ 5:1 OK ; 0.45 ≈ 4.3:1 sous le seuil en 10-11 pt ; 0.35 ≈ 3:1 ✗ ; indigo système sur fond nuit ≈ 3.5-4:1 ✗ en caption ; chevrons 0.3 limite.
- Mode clair : ni l'onglet ni la racine n'imposent `.preferredColorScheme(.dark)` (LearnHub, Settings, Wudu le font) ; `PrayerListView` en `.primary`. À vérifier en priorité.
- Reduce Motion : ✓ CosmicBackground. Non gérés : `symbolEffect(.pulse)` en boucle (`PostPrayerAdhkarService.swift:319`, `IqamahCountdownView.swift:124`, `TravelModeUI.swift:84`), ressorts des bannières.
- Reduce Transparency : ✓ `glassCardSecondary` seulement ; `glassCard` et `.ultraThinMaterial` sans repli explicite.

## 6. Localisation

- Bonne couverture dans `Localizable.xcstrings` (fr, en, ar).
- Non localisé : dates `fr_FR` (MainView.swift:18, 26 ; MoonWidgetView.swift:124, 329 ; « Auj. » :327), traductions du rappel (`PostPrayerAdhkarService.swift:269-296`), `labelFr` des saisons (`IslamicSeasonInfo.swift:48+`), `°C`.
- RTL : `.layoutDirection(.rightToLeft)` local sur chaque texte arabe ✓ ; mais chevrons `chevron.right`, « → », « - » en dur. À tester en `appLanguage=ar`.

## 7. Navigation

- 9 sheets, aucun push dans le `NavigationStack` (`MainView.swift:428`), aucun lien vers Qibla, Rappel, Apprendre.
- Deep-links : Control Widget et notifications Adhkar → `AdhkarView` (`:712-726`) ; en timing automatique le dégradé du soir est appliqué même le matin (`:715` teste `== .morning`). Commentaire `:933` « onglet Rappel » obsolète.
- Redondances : 4 portes Adhkar ; Wudû' ×2-3 ; rappel coranique (Salat) vs verset du jour (Rappel) ; Salawat vendredi (Salat + Rappel) ; Dhuhr vs décompte générique ; `AdhkarMomentCard` vs `LearnSuggestionCard` (deux moteurs de suggestion). Sunnah ⊃ Rawatib ✓ déjà fusionné.

## 8. Top 10 (par impact utilisateur)

| # | Problème | Fichier:ligne | Recommandation | Coût |
|---|---|---|---|---|
| 1 | État de prière non recalculé app ouverte (lever du soleil, minuit, notifications coupées ; fenêtre Isha de la veille non détectée) | PrayerTimesViewModel.swift:135-153, 422-433 ; PrayerCalculationEngine.swift:137-153 | Réveil planifié sur la prochaine borne → `forceRecalculation()` | M |
| 2 | Iqamah incohérente (liste +10 vs carte/réglages 20/15/15/15) | WeatherMiniWidget.swift:174-178 vs IqamahCountdownView.swift:77-81, SettingsView.swift:30-34 | `IqamahDefaults` unique | S |
| 3 | Pas de repli sans GPS (squelette perpétuel, trou, « avant ... ») | MainView.swift:327 ; WeatherMiniWidget.swift:166, 262 ; MainView.swift:254 | Ville manuelle + dernière position ; état vide explicite ; masquer la capsule | M |
| 4 | 5 prières sous le fold au moment critique et sur SE | MainView.swift:340-366 ; PostPrayerAdhkarService.swift:60-142, 151-210 | Jauge compacte ; fusionner Dhuhr ; lignes 56 pt | M |
| 5 | Dynamic Type cassé | WeatherMiniWidget.swift:102, 163, 256 et tous | `minHeight` + text styles ; `@ScaledMetric` | L |
| 6 | VoiceOver quasi absent ; arabe lu en FR | WeatherMiniWidget.swift:142-169, 201-260 ; IqamahCountdownView.swift:37-62 | `.combine` + labels ; `accessibilityHidden` ; langue `ar` | M |
| 7 | Cibles < 44 pt | §3 | `frame(minWidth: 44, minHeight: 44)` + `contentShape` | S |
| 8 | Mur de cartes, 6 surfaces, 4 portes Adhkar, 2 cartes wudû' | MainView.swift:372-418 ; IqamahCountdownView.swift:64-69, 175-180 ; TravelFiqh.swift:160 ; DailyContentView.swift:466 | Zone 2 plafonnée à 3 cartes ; `glassCard*` partout ; dédupliquer | M |
| 9 | Anti-wiggle non respecté | IqamahCountdownView.swift:27, 103 ; WuduFiqhView.swift:333 ; AdhkarBookletView.swift:343 ; ProphetSunnahCard.swift:273-310, 342 ; MoonWidgetView.swift:222 | Règles 1, 3, 4, 6 | S |
| 10 | « Ai-je fait mes adhkar ? » sans réponse ; formats de décompte mélangés | AdhkarView.swift:216-226 ; PostPrayerAdhkarService.swift:115, 448 ; IqamahCountdownView.swift:58, 139 | Anneau de progression ; un seul format « dans 12 min » | S/M |

Hors top 10 : dégradé du matin ignoré (`MainView.swift:715`) ; mode clair à vérifier ; pilule hors ligne `top + 12` qui peut couvrir l'horloge (`MainView.swift:585-588`) ; `fr_FR` ; `°C` ; haptique à la fermeture des sheets ; Chourouq absent.

## 9. Ce qui est bien

1. Architecture en 2 zones assumée et documentée, liseré `salatStateTint` qui relie les zones.
2. Décomptes économes et robustes (`Text(timerInterval:)`, `barCadence`, `.id(end)`), maths pures testables.
3. Contextualisation fine et respectueuse du fiqh (Jumu'ah, Iftar/Sohoor, ghusl, retardataire, voyage par niyyah).
4. Accessibilité système là où elle existe (Reduce Motion, Reduce Transparency zone 2, `.isHeader`, horloge parlée).
5. Fiabilité perçue : fraîcheur, relocalisation, pull-to-refresh, hors ligne / reconnecté, DST, deep-links robustes.
