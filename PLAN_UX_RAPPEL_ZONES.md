# Plan UX — Onglet Rappel en 2 zones (prioritaire / secondaire)

Synthèse de 3 analyses parallèles (architecte UX, designer visuel, testeur adversarial)
— 1ᵉʳ septembre 2026. Base : commit `d31f168` (zoning Salat). Même logique que
PLAN_UX_SALAT_ZONES.md.

## Diagnostic (constats croisés)

1. **Un intrus en tête d'écran** : `LatecomerFiqhAccessCard` (fiche de référence
   masbûq/janâza, consultée rarement) est en position 2, AU-DESSUS du verset du
   jour — l'anti-pattern `TravelFiqhCard` corrigé sur Salat. 76 pt de fold perdus
   chaque jour.
2. **L'action n°1 des auditeurs est enterrée** : la rangée « Reprendre » du cours
   audio (DailyContentView:541-587) est à ~750-1000 pt de profondeur, dans le
   carrousel podcast. Le mini-player flottant n'existe que si une lecture est
   déjà active.
3. **Aucune grammaire de surface** : verset/hadith en `.regularMaterial`+shadow,
   Khatma/Ilm/fiqh en `.ultraThinMaterial`+stroke manuel, 3 rayons (16/18/20) —
   la variété n'est pas sémantique.
4. **Espacements ad hoc** : `.padding(.top, 10)` sur les 3 dernières cartes,
   double `padding(.top, 20)` dans MainView (~40 pt morts).
5. **Bug hérité** : `DailyContentView.swift:14-16` teste `weekday == 6` en dur —
   même bug que celui corrigé dans MainView (d31f168) ; `debugForceFriday` ne
   pilote pas la grande bannière vendredi.

## Zoning cible

### Zone 1 — « le rappel du jour » (surfaces `glassCard`, spacing 16)
1. `WidgetDateHeader` + `SeasonBannerView` (chapeau, restent dans MainView)
2. `FridaySalawatBanner` (si vendredi — identité temporelle, 1 j/7)
3. Carte **Verset** → `glassCard(tint: .indigo)`
4. Carte **Hadith** → `glassCard(tint: .teal)`
5. **`ResumeListeningRow`** (nouveau) : rangée « Reprendre » extraite du
   carrousel — l'action à plus forte valeur ; conditionnelle
   (`resumeTarget != nil && !isPlaying`) donc coût nul pour les non-auditeurs

### Frontière
`ZoneSectionHeader` (= `SalatSectionHeader` renommé, il est déjà 100 % générique) :
**« Mes programmes » / « بَرَامِجِي »**, accent **`.orange` statique** (identité du
tab — là où Salat utilise l'état vivant de la prière). InterZone 36 pt.

### Zone 2 — « mes parcours & références » (`glassCardSecondary`, spacing 12)
6. `QuranKhatmaCard` (tint teal)
7. `IlmProgramCard` (tint purple)
8. `PodcastCarouselView` **sans la rangée Reprendre** (pure exploration)
9. `LatecomerFiqhAccessCard` — descendue en dernier (tint green)

## Design system

- **Renames génériques** (cross-tabs) : `SalatSpacing` → `ZoneSpacing`,
  `SalatSectionHeader` → `ZoneSectionHeader`.
- **`GlassFallback`** : le fallback Reduce Transparency était codé en dur navy
  cosmique — paramétré : `.cosmic` (0.07/0.07/0.14) et `.warm` (0.16/0.09/0.06)
  pour le fond brun du tab Rappel.
- Migration des surfaces : `.regularMaterial`+shadow → `glassCard(tint:)` ;
  `.ultraThinMaterial`+stroke → `glassCardSecondary(tint:, fallback: .warm)`.
- Hors périmètre : cartes épisodes du carrousel (logique lu/non-lu),
  `FridaySalawatBanner` (gradient vert dédié), `MiniPlayerBar` (déjà en glass).

## Garde-fous critiques (rapport QA)

- **AUCUNE zone conditionnelle autour de Khatma/Ilm** : leurs deep links de
  notification reposent sur `onAppear` (`consumePendingDeepLink`). VStack eager
  obligatoire, cartes toujours montées. Pas de LazyVStack.
- Le `.redacted` de chargement reste limité à verset + hadith (comportement
  actuel) — ne jamais en faire une condition de montage.
- Ne pas toucher au mini-player (`tabViewBottomAccessory`) ni à la pause/reprise
  auto pendant l'adhan.
- `ResumeListeningRow` garde exactement la condition actuelle
  (`resumeTarget != nil && !isPlaying`) — déplacement pur, pas de nouvelle logique.

## Étapes d'implémentation

| # | Étape | Fichiers | Risque |
|---|-------|----------|--------|
| 1 | Renames `ZoneSpacing`/`ZoneSectionHeader` + `GlassFallback` + param `fallback` | DesignSystem.swift, MainView.swift | Nul (mécanique) |
| 2 | Fix vendredi : `DailyContentView` respecte `debugForceFriday` | DailyContentView.swift | Faible |
| 3 | Extraire `ResumeListeningRow` du carrousel (déplacement pur) | DailyContentView.swift | Faible |
| 4 | Restructurer `DailyContentView` en `rappelPriorityZone` / `rappelSecondaryZone`, fiche masbûq en dernier, suppression paddings ad hoc | DailyContentView.swift | Moyen — vérifier deep links + redacted |
| 5 | Nettoyage chapeau MainView tab 1 (double padding) | MainView.swift | Nul |
| 6 | Migration surfaces (Verset/Hadith → glassCard ; Khatma/Ilm/fiqh → glassCardSecondary warm) | DailyContentView, QuranKhatmaCard, IlmProgramCard, LatecomerFiqhView | Faible, réversible |

## Validation (extraits des 12 scénarios QA)

1. `debugForceFriday` → grande bannière en zone 1 (fonctionne après étape 2)
2. Deep link notif Quran/ʿIlm en cold start → sheets s'ouvrent (cartes toujours montées)
3. 3 états audio : lecture active → pas de rangée Reprendre ; position sauvée →
   rangée en zone 1 ; aucun historique → rien
4. Khatma/Ilm états vides vs actifs
5. Slow 3G : skeleton verset/hadith sans layout shift, zone 2 non redacted
6. Reduce Transparency : fallback `warm` cohérent sur fond brun
7. iPhone SE : verset commence au-dessus du fold ; VoiceOver atteint le header
8. Podcast en lecture pendant le scroll : mini-player stable, pas de reset du carrousel
