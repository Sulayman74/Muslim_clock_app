# Plan — Lecteur ʿIlm au niveau du lecteur Coran

Synthèse de 2 analyses parallèles (expert SwiftUI gap-analysis, designer UX
mémorisation) — 6 septembre 2026. Contrainte transverse : **protocole
anti-wiggle de CLAUDE.md vérifié à chaque étape** (exigence permanente).

## 1. État de parité (audité)

| Feature Coran | Côté ʿIlm | Verdict |
|---------------|-----------|---------|
| Thèmes sépia/sombre | **Absent** — CosmicBackground animé + couleurs hardcodées (IlmLessonView:33, :77) | À faire |
| Toggle traduction | **Partiel** — la FR existe et s'affiche, mais sans toggle ni persistance | À faire |
| Enregistrement/réécoute | **Présent** — `QuranRecorder` déjà réutilisé, cycle complet (record/play/share/discard, IlmLessonView:157-276) | Polish seulement |
| Karaoké | **Non transposable** — indexé sur les ayahs ; une leçon = un bloc unique (médiane 1 paragraphe). Non-feature documentée | Non |
| Translittération | **Absent côté DONNÉES** (68 leçons à rédiger) — valeur discutable pour un matn | Non (contenu, pas code) |
| Pagination | **Partiel** — chevrons toolbar sans indicateur de position | À faire |

Bonne nouvelle données : les 68 leçons ont TOUTES une traduction FR complète et
un arabe entièrement vocalisé — zéro travail de contenu pour ce plan.

## 2. Décisions de design (tranchées)

1. **Thèmes : mêmes valeurs exactes que le Coran** (sépia #FAF2E3/encre,
   sombre #171A1C), extraction de l'enum `QuranReadingTheme` →
   **`ReadingTheme` dans DesignSystem.swift** — le « 2ᵉ implémenteur » de
   CLAUDE.md est arrivé, l'extraction est légitime. RawValues `"sepia"/"dark"`
   conservés.
2. **Clé de préférence PARTAGÉE `"quranReadingTheme"`** (arbitrage designer >
   expert) : le confort de lecture est global — qui lit en sépia le jour attend
   le même papier sur son matn. Zéro migration.
3. **Périmètre du thème : IlmLessonView uniquement** (exposition prolongée,
   fond statique = diacritiques nets). IlmTrackerView (dashboard) et
   IlmFlashCardView (session éclair 2 min) restent sur le cosmique — la
   distinction « bureau d'étude » vs « session éclair » est voulue.
4. **Traduction** : mode Lire → visible, toggle menu `Aa` persisté
   (`ilmShowTranslation`, défaut ON). Mode Mémoriser → **la FR suit le voile
   de l'arabe** (blur 7, révélée par le même tap) : la vérification après
   rappel porte sur les mots ET le sens, sans béquille pendant l'effort. Le
   blur (hauteur constante) est aussi le choix anti-wiggle.
5. **Pagination : TabView `.page` par leçon** (une leçon = une page = une unité
   de rappel — ancrage spatial des huffaz). Chaque page a son ScrollView ;
   chevrons toolbar conservés (accessibilité) ; capsule « 3 / 12 »
   `monospacedDigit`. **Aucun swipe dans les flashcards** (la notation Leitner
   exige un tap délibéré, jamais un geste).
6. **Recorder : capsule HUD flottante en bas** (grammaire de l'autoScrollHUD du
   Coran), mode Mémoriser seul — la boucle d'auto-correction exige de lire le
   matn PENDANT la réécoute (une sheet le masquerait, la barre inline actuelle
   part hors écran sur un matn long). Un seul `QuranRecorder` au niveau parent
   (AVAudioSession singleton + TabView pré-monte les voisines), reset au swipe.

## 3. Étapes d'implémentation (buildables une à une)

| # | Étape | Fichiers | Anti-wiggle |
|---|-------|----------|-------------|
| 1 | Extraire `ReadingTheme` dans DesignSystem (rename mécanique, zéro visuel) + grep non-régression | DesignSystem.swift, QuranChapterDetailView.swift | n/a |
| 2 | IlmLessonView : fond thème statique (retrait CosmicBackground), couleurs → tokens du thème, `preferredColorScheme(theme.colorScheme)`, menu `Aa` (toggle traduction + picker fond) | IlmLessonView.swift | Toggle traduction : Group survivant + transition explicite + animation keyée sur le toggle ; changement de thème = couleurs SEULEMENT (aucune métrique) |
| 3 | Blur traduction asservi à `isRevealed` en mode Mémoriser | IlmLessonView.swift | Blur = hauteur constante (jamais de retrait de carte) |
| 4 | TabView `.page` + capsule « X / N » + reset recorder/voile au swipe | IlmLessonView.swift | Indicateur monospacedDigit + minWidth ; jamais d'animation de hauteur inter-pages |
| 5 | Capsule recorder HUD bas (Mémoriser seul) + ShareLink enrichi (sujet + durée, parité Coran) | IlmLessonView.swift | minHeight plancher + geometryGroup sur la capsule ; timer monospacedDigit |
| 6 | Validation : build 0 warning, lecteur Coran inchangé (étape 1), sépia/sombre sur device, swipe + chevrons + VoiceOver, protocole anti-wiggle déroulé | — | Checklist complète |

## 4. Hors périmètre (documenté, pas oublié)

- Translittération des 68 leçons : travail de contenu, valeur faible — non.
- Karaoké sous-leçon : granularité inexistante dans les données — non-feature.
- Thème sur flashcards/tracker : volontairement exclu (décision 3).
