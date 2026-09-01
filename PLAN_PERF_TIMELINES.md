# Audit & plan — Consolidation des TimelineView

Synthèse de 3 analyses parallèles (inventaire exhaustif, stratégie de
consolidation, chasse aux régressions) — 1ᵉʳ septembre 2026. Base : `7ae7c93`.

## 1. Inventaire (pire cas simultané par onglet)

| Onglet | Sources de ticks | Total pire cas |
|--------|------------------|----------------|
| **Salat (0)** | Horloge 1 s · jauge OU décompte 1 s (exclusifs) · iqamah 2 s · Dhuhr 10 s · CosmicBackground 15+20+30 Hz | **~68 ticks/s** |
| **Rappel (1)** | Waveform mini-player `Timer.publish(0.15 s)` ≈ 6,7 Hz (**fuite : tourne même en pause**) + 3 `.repeatForever` (CoreAnimation, OK) | ~15 ticks/s |
| **Qibla (2)** | CosmicBackground (2ᵉ instance !) 65 Hz · overlay FPS 60 Hz (DEBUG only) | ~65 ticks/s |
| **Réglages (3)** | Rien | 0 |
| Sheets | QuranRecorder tick 10 Hz (localisé, acceptable) | — |

Bons élèves déjà en place : `Text(timerInterval:)` dans les cartes Iqamah/Dhuhr
(décompte piloté par le système, zéro redraw SwiftUI).

## 2. Découverte structurelle CLÉ (garantie de non-régression)

**Les transitions de fenêtre de prière ne dépendent PAS des TimelineView.**
Le branchement jauge/nuit/décompte est piloté par `@Published currentPrayerWindow`
(PrayerTimesViewModel), mis à jour de façon **événementielle** : retour au
foreground, notif « AdhanTriggered », changement GPS/réglages. Le `.id()` sur la
jauge reconstruit tout au changement de fenêtre.

**MAIS** les ticks restent le seul moteur pour : la couleur de jauge (seuil 85 %),
l'apparition/disparition des cartes Iqamah/Dhuhr, et l'horloge. → On ne supprime
jamais ces moteurs, on les rend plus intelligents.

## 3. Plan d'exécution (du moins risqué au plus délicat)

| # | Étape | Gain | Risque |
|---|-------|------|--------|
| 0 | **Baseline** : compteurs de ticks DEBUG + vérifier si le CosmicBackground de l'onglet non visible ticke (2 instances !) | mesure | nul |
| 1 | **Horloge** : `.periodic(1 s)` → `.everyMinute` — elle n'affiche que HH:mm, 59 ticks/60 perdus | ~1 tick/s permanent | quasi nul (`.everyMinute` rattrape au retour de background) |
| 2 | **Waveform mini-player** : `Timer.publish(0.15 s)` → `TimelineView(.animation, paused: !isPlaying)` — supprime la fuite en pause | 6,7 ticks/s dès qu'un épisode est chargé en pause | quasi nul |
| 3 | **CosmicBackground** : fusionner étoiles fixes + poussière en UN canvas à 10 Hz (contenus ≤ 0,4 Hz, 10 Hz = 12× Nyquist) ; étoiles filantes restent 30 Hz (duty cycle ~10 %, option `paused:` hors rafale) ; **Reduce Motion → fond figé** ; `paused:` sur l'instance de l'onglet non visible si la baseline le confirme | 25-50 ticks/s sur 2 onglets | faible (fonctions pures de `time`, seed déterministe → même ciel) |
| 4 | **NextPrayerCountdownCard** : texte → `Text(timerInterval:)`, barre verte → cadence adaptative (`max(1, durée/350)` ≈ 30-60 s pour la matinée, `.animation(.linear(cadence))` garde le mouvement continu) | ~1 tick/s toute la matinée | faible |
| 5 | **CurrentPrayerGaugeView** (le plus délicat) : texte → `Text(timerInterval:)` (⚠️ compromis : format `-05:03` → `5:03`, mitigeable par `Text("-") + Text(timerInterval:)`) ; couleur 85 % → `TimelineView(.explicit([switchDate, end]))` (2 ticks par fenêtre, date déterministe) ; barre → cadence adaptative 10-15 s ; ajouter `.id(end)` pour re-créer le schedule si les horaires changent en cours de fenêtre (DST/GPS) | ~0,9 tick/s pendant les fenêtres | moyen |
| 6 | **NE PAS TOUCHER** : cartes Iqamah (2 s) / Dhuhr (10 s) — déjà optimales, leur cadence EST le mécanisme d'apparition (latence max 2 s/10 s, acceptable et actuelle). **NE PAS faire d'horloge partagée 1 Hz** : après les étapes 4-5 il ne reste que 0,6 tick/s ici, un parent 1 Hz serait une RÉGRESSION | — | — |

## 4. Bilan attendu (onglet Salat, fenêtre active, podcast en pause)

| | Avant | Après |
|---|-------|-------|
| Horloge | 1,0/s | 0,017/s |
| Hero (jauge/décompte) | 1,0/s | ~0,07/s |
| Iqamah + Dhuhr | 0,6/s | 0,6/s (inchangé, volontaire) |
| Cosmic | 65/s | ~10/s (+30 Hz en rafales ~10 % du temps) |
| Waveform | 6,7/s | 0 |
| **Total** | **~74/s** | **~11-14/s** |

## 5. Protocole de non-régression (à dérouler après chaque étape)

1. **Horloge** : bascule de minute pile à :00 ; lock/unlock à cheval sur une
   minute → heure juste immédiatement.
2. **Jauge 85 %** : fenêtre courte (délais iqamah réglés bas + debugSeasonDate),
   vérifier orange → rouge ; backgrounder avant le seuil, revenir après → rouge
   immédiat (TimelineView délivre la dernière entrée passée).
3. **Changement d'horaires en cours de fenêtre** : changer la méthode de calcul
   dans Réglages → barre et décompte sautent aux nouvelles valeurs.
4. **Transition Dhuhr → Iqamah** (12:29:50 → 12:30:05 via debugSeasonDate) :
   pas de « blanc » anormal, chevauchement ≤ cadences actuelles (inchangées).
5. **Décomptes après background** : backgrounder 20 s pendant un décompte →
   valeur correcte au retour (Text(timerInterval:) est système).
6. **Ciel cosmique** : comparaison avant/après (seed déterministe → mêmes
   étoiles), pas de stroboscope, étoiles filantes fluides sur 60 Hz et ProMotion.
7. **Reduce Motion** : fond figé, pas de crash, cartes lisibles.
8. **Waveform** : lecture → animation identique ; pause → barres redescendent
   puis zéro tick ; reprise → repart.

## 6. Hors périmètre (constaté, rien à faire)

- QuranRecorder 10 Hz : localisé à la sheet d'enregistrement, légitime.
- Overlay FPS Qibla 60 Hz : `#if DEBUG` uniquement.
- Boussole : pilotée par CoreMotion (capteur), pas par timeline.
- Live Activity `Task.sleep` : background, indépendant de l'UI.
- Widgets/Watch/Complication : aucune timeline périodique (WidgetKit discret).
