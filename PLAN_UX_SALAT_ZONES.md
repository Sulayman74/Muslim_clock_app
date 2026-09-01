# Plan UX — Onglet Salat en 2 zones (prioritaire / secondaire)

Synthèse de 3 analyses parallèles (architecte UX, designer visuel, testeur adversarial)
— 1ᵉʳ septembre 2026. Base : commit `9eb0d0e`.

## Objectif

Séparer clairement l'onglet Salat en :
- **Zone prioritaire** (« le glance 3 secondes ») : horloge, dates, météo,
  compte à rebours, **les 5 prières** — consultés 5×/jour.
- **Zone secondaire** (« enrichir ma prière ») : adhkar + livret, sunnah de la
  prière en cours, phases lunaires — consultation posée.

## Diagnostic (constats croisés des 3 agents)

1. **Les 5 prières sont sous le fold** : ~680 pt de contenu les précèdent un jour
   ordinaire (jusqu'à **1 464 pt** dans le pire cas mesuré : vendredi de Ramadan
   en voyage + update dispo + GPS refusé). Sur iPhone SE (~602 pt utiles),
   même les widgets météo/prochaine prière peuvent sortir du viewport.
2. **Un intrus dans le hero** : la carte « Rappel coranique » (~250 pt) est codée
   *dans* `CurrentPrayerGaugeView` (PostPrayerAdhkarService.swift:264-339) —
   c'est de l'enrichissement soudé au composant le plus prioritaire.
3. **La hiérarchie 3 niveaux existante (commit 369c66f) est structurelle mais
   invisible** : toutes les cartes partagent le même verre `glassEffect(.regular,
   tint 0.12)` ; seule différence = 28 pt vs 16 pt de spacing.
4. **3 portes d'entrée Adhkar consécutives** (MomentCard + QuickAccess + Booklet)
   diluent la frontière entre les zones.
5. **2 éléments non-glance encombrent le chapeau** : `TravelFiqhCard` (fiche de
   référence) et `FridaySalawatMiniReminder` (rappel spirituel).
6. Bug annexe trouvé : `MainView.swift:339` teste le vendredi en dur
   (`weekday == 6`) au lieu du helper `isCurrentlyFriday` → le toggle
   `debugForceFriday` ne pilote pas cette bannière.

## Cible

### Zone 1 — prioritaire (verre `.regular` actuel, spacing 16)
1. Horloge + `WidgetDateHeader` + `PrayerFreshnessLine`
2. Bannières **bloquantes uniquement** : GPS refusé, relocalisation, pastille
   voyage, bannière saison (identité temporelle)
3. `WeatherMiniWidget` + `NextPrayerWidget` + attribution
4. Décomptes : `CurrentPrayerGaugeView` **sans le rappel coranique**,
   `DhuhrCountdownCard`, `IqamahCountdownCard`
5. **`PrayerListView` (les 5 prières)** ← remonte de la position ~16 à la 5
6. `RamadanDuaCardView` (urgence temporelle pendant Ramadan, après la liste)

### Frontière
- **`SalatSectionHeader`** (nouveau composant DesignSystem) : trait-capsule
  20×2 pt **teinté par l'état de la prière** (orange en cours / vert prochaine /
  indigo nuit) + « POUR ALLER PLUS LOIN » footnote 0.55 + écho arabe
  « لِلاسْتِزَادَة » 0.35 + `.accessibilityAddTraits(.isHeader)`.
- Spacing inter-zones **36 pt** (vs 16 intra). Non-sticky (pas de LazyVStack :
  4 TimelineView dans ce scroll, risque de régression sur les cycles de vie).

### Zone 2 — secondaire (nouveau verre `.clear` tint 0.08, spacing 12)
7. `AdhkarMomentCard` (le plus contextuel → tête de zone)
8. `AdhkarQuickAccessButton` + `AdhkarBookletButton` **côte à côte** (HStack,
   ~70 pt économisés) — réversible si trop serré sur SE
9. `ProphetSunnahCardView` (repliée) + **capsule contextuelle** « Maghrib · en
   cours » reliant visuellement à la prière courante
10. `SpiritualReminderCard` (rappel coranique extrait)
11. `TravelFiqhCard` (si voyage) et `FridaySalawatMiniReminder` (si vendredi)
    déplacées ici
12. `MoonWidgetView` (repliée, badge Jours Blancs conservé)

## Design system (spécs du designer)

Tokens à ajouter dans `DesignSystem.swift` :
- `Spacing.intraZonePrimary = 16`, `.intraZoneSecondary = 12`, `.interZone = 36`
- `PrayerStateTint.now = .orange / .upcoming = .green / .night = .indigo`
  (source unique des couleurs sémantiques déjà utilisées partout)
- `glassCardSecondary(cornerRadius:tint:)` : `glassEffect(.clear.tint(0.08))`
- `SalatSectionHeader(titleFr:titleAr:accent:)`
- Fallback **Reduce Transparency** : fond plein `Color(0.07, 0.07, 0.14)` +
  liseré blanc 0.10 (modifieur `CosmicSurface`, rétrofit possible sur `glassCard`)

Principe : **aucune carte redessinée, aucune couleur nouvelle** — on réutilise la
grammaire `.regular` = contenu / `.clear` = discret qui existe déjà.

## Étapes d'implémentation (chacune compile et se teste seule)

| # | Étape | Fichiers | Risque |
|---|-------|----------|--------|
| 1 | Extraire `SpiritualReminderCard` de `CurrentPrayerGaugeView` | PostPrayerAdhkarService.swift (l.51-97, 264-339) | Faible — la sheet et le `.id()` restent sur la jauge |
| 2 | Restructurer le VStack en 2 zones + remonter `PrayerListView` ; extraire le tab 0 en sous-vue `SalatTabView` (allège aussi le type-checker) | MainView.swift l.344-395 | Moyen — vérifier les 3 états de la jauge |
| 3 | Tokens + `glassCardSecondary` + `SalatSectionHeader` + application zone 2 | DesignSystem.swift, MainView.swift | Faible |
| 4 | Déplacer `TravelFiqhCard` + `FridaySalawatMiniReminder` en zone 2 ; fix `isCurrentlyFriday` (bug debugForceFriday) | MainView.swift | Faible |
| 5 | Rangée Adhkar fusionnée (HStack 2 demi-cartes) | AdhkarView.swift:592-654, AdhkarBookletView.swift:258-298 | Faible, réversible |
| 6 | Capsule contextuelle prière sur `ProphetSunnahCard` | ProphetSunnahCard.swift:218-243, MainView (passer le contexte) | Faible |
| 7 | Durcissements a11y **limités aux composants touchés** : labels VoiceOver (horloge, widgets, liste des prières), RTL explicite sur les textes arabes déplacés, fallback Reduce Transparency | MainView, WeatherMiniWidget, RamadanDuaCardView | Faible |

Hors périmètre (déjà tracé dans AUDIT_UIUX_LAYOUT.md, à traiter séparément) :
Dynamic Type global, Reduce Motion sur toutes les animations, consolidation des
TimelineView (4×1 Hz simultanés), fusion des bannières top.

## Protocole de validation (checklist du testeur)

Devices : iPhone SE 3 (petit écran) + un grand. Leviers DEBUG existants :
`debugSeasonDate`, `debugForceFriday`, `debugRamadanWindow`, mode voyage, GPS refusé.

1. **Pire empilement** : vendredi Ramadan (debugSeasonDate j.15) + voyage +
   update simulée + GPS refusé → la zone 1 reste lisible, les 5 prières
   accessibles en ≤ 1 scroll court sur SE.
2. **Jour ordinaire hors fenêtre** : les 5 prières commencent au-dessus du fold.
3. **3 états de la jauge** (en cours / qiyam / décompte) : plus de rappel
   coranique dans le hero, pas de glitch au switch (`.id()` conservé).
4. **Fenêtre iqamah + pré-Dhuhr** : cartes visibles en zone 1, ordre correct.
5. **Vendredi (debugForceFriday)** : salawat en zone 2, Jumu'ah partout.
6. **VoiceOver** : navigation par en-têtes atteint « Pour aller plus loin » ;
   horloge, prochaine prière et chaque ligne de prière annoncées.
7. **Reduce Transparency** : cartes zone 2 lisibles (fallback opaque).
8. **Dynamic Type AX3+** : header de section et capsule ne débordent pas
   (`@ScaledMetric`), horloge conserve son `minimumScaleFactor`.
9. **Arabe (appLanguage=ar)** : header bilingue correct, RTL sur les cartes
   déplacées.
10. **Régression wiggle** : scroll + refresh → pas de réapparition des wiggles
    corrigés (QW6, e36fda7).

## Décisions d'arbitrage (issues du croisement des 3 rapports)

- **Pas de sticky header ni LazyVStack** : risque de régression sur les
  TimelineView et le pull-to-refresh calibrés sur VStack eager.
- **Pas de changement de fond de zone** : le fond cosmique est saisonnier et
  plein écran ; un 2ᵉ fond créerait une couture avec le voile voyage.
- **Pas de repli global de la zone 2** : masquerait `AdhkarMomentCard`, la carte
  contextuelle qui doit émerger au bon moment.
- **`RamadanDuaCardView` et `SeasonBanner` restent en zone 1** : ce sont des
  informations temporelles (fenêtres Iftar/Suhoor, identité du mois), pas de
  l'enrichissement.
- **A11y limitée aux composants touchés** dans ce lot ; le reste part dans le
  chantier AUDIT_UIUX_LAYOUT.
