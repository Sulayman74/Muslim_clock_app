# Audit — Suivi d'activité « Prochaine Salât » (écran verrouillé, Dynamic Island)

Date : 13 octobre 2026. Périmètre : `Muslim Clock/SalatLiveActivityManager.swift` (293 l.),
`SalatWidget/SalatWidgetLiveActivity.swift` (184 l.), `SalatWidget/SalatLiveActivityAttributes.swift`,
les appels depuis `PrayerTimesViewModel` et `Muslim_ClockApp`, le SDK iOS 27 / cible iOS 26.2.
Statut : **constat, rien n'est corrigé** dans ce document.

## Synthèse

| # | Constat | Gravité | Effort |
|---|---|---|---|
| 1 | L'activité ne démarre que si l'app tourne dans les 30 min avant la prière | Élevée | M |
| 2 | Après l'heure, si l'app est suspendue, le compte à rebours repart à la hausse sous « restant » et l'activité peut rester des heures | Élevée | S |
| 3 | « Chourouq » (lever du soleil) est traité comme une prière : « C'est l'heure de la prière » au lever du soleil | Élevée (contenu religieux) | S |
| 4 | Conformité `ActivityAttributes` isolée au MainActor : 8 avertissements, erreurs en Swift 6 | Moyenne | XS |
| 5 | Aucune présentation dédiée Apple Watch / CarPlay (`supplementalActivityFamilies`) | Moyenne | S |
| 6 | Le tap sur l'activité n'ouvre pas l'onglet Salat (pas de `widgetURL`, pas de schéma d'URL) | Moyenne | S |
| 7 | Accessibilité de la Dynamic Island compacte : icône seule, sans libellé | Moyenne | XS |
| 8 | Pas de repère Ramadan (Iftar / fin du Sohoor) alors que l'app et les widgets en ont un | Faible | S |
| 9 | Libellés mineurs (« heure », nom arabe vide), `print` au lieu de `Logger` | Faible | XS |

## Détail

### 1. Démarrage limité au premier plan (élevée)

`SalatLiveActivityManager.refresh` (l. 43-77) ne démarre une activité que si la prochaine prière
est dans les 30 min, et il n'est appelé qu'après un recalcul (`PrayerTimesViewModel.swift:299, 387`)
ou au passage `scenePhase == .active` (`MainView`, `Muslim_ClockApp`). Une app iOS ne s'exécute pas
en arrière-plan : si l'utilisateur n'ouvre pas Muslim Clock dans la demi-heure qui précède une
prière, aucune activité n'apparaît. En pratique, la fonctionnalité est invisible la plupart du temps.

**Recommandation.** La cible iOS 26.2 donne accès au démarrage programmé :
`Activity.request(attributes:content:pushType:style:alertConfiguration:start:)` (SDK ActivityKit,
`@available(iOS 26.0, *)`). À chaque recalcul et au passage en arrière-plan, programmer l'activité
de la prochaine prière (et éventuellement de la suivante) avec `start = heure − 30 min`, en annulant
les programmations obsolètes. À valider sur appareil : nombre d'activités programmées autorisées,
comportement de l'`alertConfiguration` (choisir une alerte discrète pour ne pas doubler l'adhan).
Sans cela, la seule autre voie est le push ActivityKit, qui exige un serveur.

### 2. Après l'heure de la prière (élevée)

Les transitions « C'est l'heure » puis fin à T + 5 min reposent sur des `Task.sleep` dans le
processus de l'app (`scheduleAutoTransitions`, l. 201-235). Une app suspendue n'exécute pas ces
tâches ; seul le retour au premier plan rattrape l'état (`syncActiveActivitiesState`).
Entre-temps :
- `Text(targetTime, style: .timer)` (vue l. 60, 79, 140) **compte le temps écoulé** une fois l'heure
  passée : l'écran verrouillé affiche un chronomètre qui remonte, sous le libellé « restant » ;
- `staleDate = targetTime + 5 min`, mais la vue n'utilise jamais `context.isStale` ;
- le système garde une activité jusqu'à 8 h (puis jusqu'à 4 h sur l'écran verrouillé).

**Recommandation.** Rendre la vue autonome : `Text(timerInterval: début...targetTime, countsDown: true)`
(s'arrête à 0:00), `staleDate = targetTime`, et afficher l'état « C'est l'heure de Asr — 15:32 »
dès que `context.isStale || state.isPrayerTime`. La fin explicite reste faite au prochain passage
au premier plan ou au démarrage de l'activité suivante.

### 3. « Chourouq » traité comme une prière (élevée, contenu religieux)

Entre Fajr et le lever du soleil, la prochaine « prière » renvoyée par la lib Adhan est `.sunrise`,
nommée « Chourouq » (`PrayerTimesViewModel.swift:394`), et transmise à `refresh` comme les autres
(l. 296-299). Conséquences : clé `chourouq`, nom arabe vide et icône lune par défaut
(`SalatLiveActivityManager.swift:254-292`), puis « C'est l'heure de la prière » au lever du soleil,
moment où, justement, la prière est déconseillée.

**Recommandation.** Ne jamais démarrer d'activité pour le lever du soleil (passer directement à
Dhuhr), ou en faire un état distinct « Fin du temps de Fajr » si ce rappel est souhaité. Cohérent
avec les notifications d'adhan, qui excluent déjà le lever du soleil.

### 4. Isolation de `SalatLiveActivityAttributes` (moyenne)

L'app compile avec `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` : la conformité à `ActivityAttributes`
devient isolée au MainActor puis est utilisée dans un contexte `@concurrent` par ActivityKit.
Le build affiche 8 avertissements `#IsolatedConformances` (`SalatLiveActivityManager.swift:160-248`),
qui deviennent des erreurs en mode Swift 6. **Recommandation :** `nonisolated struct
SalatLiveActivityAttributes` (le fichier est partagé avec l'extension widget, sans effet de bord).

### 5. Apple Watch et CarPlay (moyenne)

Depuis iOS 18, une Live Activity apparaît aussi dans le Smart Stack de l'Apple Watch et sur CarPlay.
Sans `.supplementalActivityFamilies([.small])`, le système dérive une présentation des vues compactes
(icône + minuteur), sans le nom de la prière. **Recommandation :** déclarer la famille `.small` et une
mise en page dédiée via `@Environment(\.activityFamily)` (nom, heure, décompte).

### 6. Tap sur l'activité (moyenne)

Ni `widgetURL` ni schéma d'URL (`CFBundleURLTypes` absent de `Muslim-Clock-Info.plist`) : un tap
ouvre l'app sur le dernier onglet utilisé, pas sur Salat. **Recommandation :** schéma
`muslimclock://salat`, `.widgetURL` sur la vue écran verrouillé et la Dynamic Island, routage dans
`MainView` (même mécanique que les autres deep links).

### 7. Accessibilité (moyenne)

`compactLeading` et `minimal` ne contiennent qu'une icône, sans `accessibilityLabel` ; VoiceOver
n'annonce ni la prière ni le délai. **Recommandation :** `.accessibilityLabel` du type « Prochaine
prière : Asr, dans 12 minutes » sur les régions compactes et sur la vue écran verrouillé.

### 8. Ramadan (faible)

Le libellé « Fajr → Suhoor » a été retiré volontairement (commit `b8277ff`, « badge contextuel au
lieu de relabel »). L'app affiche désormais un badge « Iftar / Fin du Sohoor », absent de la Live
Activity. Optionnel : ajouter ce badge dans la vue écran verrouillé. Note : `AUDIT_NOUVEAUTES_2026-09.md`
mentionne encore la Live Activity « Fajr → Suhoor », ce qui n'est plus vrai.

### 9. Détails (faible)

- Région étendue droite : libellé « heure » sous l'heure cible, peu clair → « à » ou rien.
- Nom arabe vide pour toute clé inconnue (voir n° 3).
- `print` dans `start` au lieu de `os.Logger` (règle du projet).
- Pas d'écoute de `ActivityAuthorizationInfo().activityEnablementUpdates` : si l'utilisateur
  réactive les Live Activities, rien ne démarre avant le prochain recalcul (acceptable).

## Ce qui est bien fait

- Une seule activité à la fois, remplacée proprement au changement de prière.
- Rattrapage au premier plan (`syncActiveActivitiesState`) avec fin immédiate des activités périmées.
- Dynamic Island complète (compacte, étendue, minimale), chiffres à chasse fixe, `keylineTint`.
- Respect du réglage système (`areActivitiesEnabled`), pas de push, pas de serveur.
- Jumu'ah géré (clé, icône, heure de la mosquée).

## Observation au simulateur (iPhone 17 Pro, iOS 26.5)

Test `Muslim ClockUITests/LiveActivityAuditUITests` : bouton DEBUG « Tester Live Activity (5 min) »,
app envoyée en arrière-plan, captures à T − 4 min 54 et T + 30 s.

- **Départ** : Dynamic Island compacte correcte (icône soleil d'Asr à gauche, « 4:54 » orange à droite).
- **Après l'heure** : la Dynamic Island affiche la cloche orange (état « C'est l'heure »).
- **Limite de l'observation** : pendant un test UI, le simulateur garde le processus de l'app en vie ;
  les `Task.sleep` ont donc pu s'exécuter. Le défaut n° 2 concerne une app **suspendue**, cas normal
  sur un iPhone verrouillé : à vérifier sur appareil (verrouiller l'iPhone pendant le décompte de
  test, attendre 6 min, regarder l'écran verrouillé).
- Les défauts n° 1, 3, 4, 6 et 7 sont établis par lecture du code et du build, sans dépendre du simulateur.

## Plan de correction proposé (ordre)

1. n° 3 (Chourouq) et n° 4 (isolation) : petits, sans risque — à faire en premier.
2. n° 2 (vue autonome : décompte borné, `isStale`) : rend l'activité juste même app suspendue.
3. n° 1 (démarrage programmé iOS 26) : apporte la visibilité réelle ; à valider sur appareil.
4. n° 6, 7, 5 puis 8, 9.
