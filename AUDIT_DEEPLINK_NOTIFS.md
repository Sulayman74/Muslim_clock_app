# Plan d'implémentation — Deep links des notifications locales

> Document à destination de l'assistant Xcode. Suivre les étapes dans l'ordre.
> Périmètre STRICT : ne toucher que les fichiers listés. Pas de refactor opportuniste.

## 1. Contexte

L'app n'utilise que des **notifications locales** (pas d'APNs). Le routing au tap repose sur
`AppDelegate.didReceive` (`Muslim_ClockApp.swift`) qui émet des posts `NotificationCenter`
consommés par des `.onReceive` dans `MainView`.

**Bug systémique** : un post `NotificationCenter` est synchrone et non rejoué. Si l'app est
**tuée** et que l'utilisateur tape une notification, `didReceive` est appelé au cold start
alors que les `.onReceive` de `MainView` ne sont pas encore montés → le deep link est perdu.

État actuel par famille de notification :

| Notif (préfixe ID) | Payload `userInfo` | Destination attendue | App en mémoire | App tuée (cold start) |
|---|---|---|---|---|
| `prayer_*` | `prayerName`, `prayerTime` | Overlay `AdhanOverlayView` | ✅ | ❌ perdu |
| `quran_reading_*` | `module=quran_reading`, `prayerName`, `pagesTarget` | Tab 1 Rappel + sheet `QuranTrackerView` | ✅ | ⚠️ tab pas switché, sheet différée (flag `pendingOpenQuranTracker` seul) |
| `adhkar_reminder_*` | `module=adhkar_reminder`, `timing`, `deepLinkTarget` | Sheet `AdhkarView` timing forcé | ✅ | ❌ perdu |
| `newmoon_*` | *(aucun)* | *(aucune — voulu)* | n/a | n/a |

Bugs secondaires :
- **Replay périmé** : taper une notif de prière restée des heures dans le centre de
  notifications rejoue l'overlay Adhan plein écran avec une heure passée (aucune garde de fraîcheur).
- **Garde fragile** : le branch "prière" de `didReceive` exclut seulement
  `module != "quran_reading"` — tout futur module avec `prayerName`+`prayerTime` déclencherait l'overlay.
- **Code mort** : la clé `deepLinkTarget` du payload Adhkar (`AdhkarReminderScheduler`) n'est lue nulle part.

**Solution** : persister la route dans `UserDefaults` au tap, consommée par `MainView` à
l'activation — même pattern que `handleControlDeepLink()` (Control Widgets) qui gère déjà
correctement ce problème (clé + timestamp + garde 30 s + cleanup).

---

## 2. Étape 1 — Nouveau fichier `Muslim Clock/NotificationDeepLink.swift`

Créer ce fichier (target iOS uniquement, pas watch/widget) :

```swift
//
//  NotificationDeepLink.swift
//  Muslim Clock — route persistante posée au tap d'une notification locale.
//
//  Pourquoi : le post NotificationCenter émis dans AppDelegate.didReceive est
//  perdu si l'app démarre à froid (les .onReceive de MainView ne sont pas
//  encore montés). On persiste donc la route dans UserDefaults, consommée par
//  MainView à l'activation — même pattern que `controlDeepLinkTarget`.
//

import Foundation

/// Route de deep link posée par `AppDelegate.didReceive` et consommée par `MainView`.
enum NotificationDeepLink: String {
    case adhan
    case quranTracker = "quran_tracker"
    case adhkarMorning = "adhkar_morning"
    case adhkarEvening = "adhkar_evening"

    // MARK: - Clés UserDefaults (standard — tout est in-app, pas besoin d'App Group)

    static let routeKey = "pending_notification_route"
    static let timestampKey = "pending_notification_timestamp"
    static let adhanNameKey = "pending_adhan_prayer_name"
    static let adhanTimeKey = "pending_adhan_prayer_time"

    /// Fenêtre de validité d'une route pendante (ne pas rejouer un vieux tap).
    static let maxAgeSeconds: TimeInterval = 30
    /// Fenêtre pendant laquelle un tap sur une notif de prière affiche encore
    /// l'overlay Adhan (au-delà, la prière est passée depuis trop longtemps).
    static let adhanReplayWindow: TimeInterval = 30 * 60

    // MARK: - Écriture (AppDelegate)

    static func store(_ route: NotificationDeepLink) {
        let defaults = UserDefaults.standard
        defaults.set(route.rawValue, forKey: routeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: timestampKey)
    }

    static func storeAdhan(prayerName: String, prayerTime: Date) {
        let defaults = UserDefaults.standard
        defaults.set(prayerName, forKey: adhanNameKey)
        defaults.set(prayerTime.timeIntervalSince1970, forKey: adhanTimeKey)
        store(.adhan)
    }

    // MARK: - Lecture (MainView)

    /// Lit puis efface la route pendante. `nil` si absente ou périmée (> 30 s).
    static func consume() -> NotificationDeepLink? {
        let defaults = UserDefaults.standard
        defer { clear() }
        guard let raw = defaults.string(forKey: routeKey),
              let route = NotificationDeepLink(rawValue: raw) else { return nil }
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: timestampKey)
        return age <= maxAgeSeconds ? route : nil
    }

    /// Efface la route pendante sans la lire (appelé par les handlers live de
    /// MainView pour éviter un double déclenchement au prochain passage à .active).
    static func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: routeKey)
        defaults.removeObject(forKey: timestampKey)
    }
}
```

---

## 3. Étape 2 — Réécrire `didReceive` dans `Muslim Clock/Muslim_ClockApp.swift`

Remplacer intégralement la méthode `userNotificationCenter(_:didReceive:withCompletionHandler:)`
(lignes ~43–81) par :

```swift
    // Appelée quand l'utilisateur CLIQUE sur la notification.
    // Double mécanisme : post NotificationCenter (app en mémoire, réaction
    // immédiate) + route persistée NotificationDeepLink (cold start — le post
    // serait perdu car les .onReceive de MainView ne sont pas encore montés).
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        switch userInfo["module"] as? String {

        // Notif prière (aucune clé "module") → AdhanOverlay
        case nil:
            if let prayerName = userInfo["prayerName"] as? String,
               let timestamp = userInfo["prayerTime"] as? TimeInterval {
                let prayerTime = Date(timeIntervalSince1970: timestamp)
                // Garde anti-replay : ignorer un tap sur une vieille notif
                // restée dans le centre de notifications.
                if abs(prayerTime.timeIntervalSinceNow) <= NotificationDeepLink.adhanReplayWindow {
                    NotificationDeepLink.storeAdhan(prayerName: prayerName, prayerTime: prayerTime)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AdhanTriggered"),
                        object: nil,
                        userInfo: ["prayerName": prayerName, "prayerTime": prayerTime]
                    )
                }
            }

        // Notif rappel Quran → tab Rappel + sheet QuranTrackerView
        case "quran_reading":
            NotificationDeepLink.store(.quranTracker)
            // Flag dédié consommé par QuranKhatmaCard à son mount (la card vit
            // dans le tab 1, monté paresseusement par TabView).
            UserDefaults.standard.set(true, forKey: "pendingOpenQuranTracker")
            NotificationCenter.default.post(name: .quranReadingTapped, object: nil)

        // Notif rappel Adhkar (matin/soir) → sheet AdhkarView au bon timing
        case "adhkar_reminder":
            if let timing = userInfo["timing"] as? String {
                NotificationDeepLink.store(timing == "morning" ? .adhkarMorning : .adhkarEvening)
                NotificationCenter.default.post(
                    name: .adhkarReminderTapped,
                    object: nil,
                    userInfo: ["timing": timing]
                )
            }

        default:
            break
        }

        completionHandler()
    }
```

Points d'attention :
- Le `switch` sur `module` remplace la garde fragile `module != "quran_reading"` :
  un futur module ne pourra plus déclencher l'overlay Adhan par accident.
- Ne PAS toucher à `willPresent` (affichage foreground) ni au reste du fichier.

---

## 4. Étape 3 — Consommer la route dans `Muslim Clock/MainView.swift`

### 4.a Appel à l'activation

Dans le modifier existant (~ligne 443) :

```swift
        .onChange(of: scenePhase, initial: true) {
            print("📱 [ScenePhase] phase=\(scenePhase)")
            if scenePhase == .active {
                handleNotificationDeepLink()   // ← AJOUT (avant handleControlDeepLink)
                handleControlDeepLink()
                prayerVM.refreshLiveActivity()
            }
        }
```

### 4.b Nouvelle méthode privée

À ajouter à côté de `handleControlDeepLink(retryCount:)` (~ligne 617) :

```swift
    /// Consomme la route posée par `AppDelegate.didReceive` au tap d'une notification.
    ///
    /// Couvre le cold start : le post NotificationCenter du delegate est perdu si
    /// les `.onReceive` ne sont pas encore montés — la route persistée prend le
    /// relais. Si l'app était en mémoire, le handler live a déjà routé ET effacé
    /// la route (`NotificationDeepLink.clear()`), donc pas de double déclenchement.
    private func handleNotificationDeepLink() {
        guard let route = NotificationDeepLink.consume() else { return }
        switch route {
        case .adhan:
            let defaults = UserDefaults.standard
            guard let name = defaults.string(forKey: NotificationDeepLink.adhanNameKey) else { return }
            let time = Date(timeIntervalSince1970: defaults.double(forKey: NotificationDeepLink.adhanTimeKey))
            withAnimation(.easeIn(duration: 0.4)) {
                adhanPrayerName = name
                adhanPrayerTime = time
                showAdhanOverlay = true
            }
        case .quranTracker:
            // Le switch de tab monte DailyContentView → QuranKhatmaCard, qui
            // consomme `pendingOpenQuranTracker` à son onAppear et ouvre la sheet.
            selectedTab = 1
        case .adhkarMorning:
            adhkarSheetForcedTiming = .morning
            showAdhkarFromControl = true
        case .adhkarEvening:
            adhkarSheetForcedTiming = .evening
            showAdhkarFromControl = true
        }
    }
```

### 4.c Effacer la route dans les handlers live (anti double-déclenchement)

Modifier les trois `.onReceive` existants pour ajouter `NotificationDeepLink.clear()` :

```swift
                // Notif Quran tapée → switch automatique vers tab Rappel (où la card vit).
                .onReceive(NotificationCenter.default.publisher(for: .quranReadingTapped)) { _ in
                    NotificationDeepLink.clear()   // ← AJOUT
                    selectedTab = 1
                }
                // Notif Adhkar tapée → ouvre la sheet Adhkar avec le timing forcé.
                .onReceive(NotificationCenter.default.publisher(for: .adhkarReminderTapped)) { notif in
                    NotificationDeepLink.clear()   // ← AJOUT
                    if let raw = notif.userInfo?["timing"] as? String,
                       let timing = AdhkarTiming(rawValue: raw) {
                        adhkarSheetForcedTiming = timing
                        showAdhkarFromControl = true
                    }
                }
```

Et dans le `.onReceive` de `"AdhanTriggered"` (~ligne 570), ajouter en tête de closure
(après le `guard`) :

```swift
                    NotificationDeepLink.clear()   // ← AJOUT (no-op si posté par willPresent)
```

---

## 5. Étape 4 — Nettoyage code mort dans `Muslim Clock/AdhkarReminderScheduler.swift`

La clé `deepLinkTarget` du payload n'est lue nulle part (le routing passe par `timing`).
Supprimer :

1. La ligne `"deepLinkTarget": internalTiming.deepLinkTarget,` dans `scheduleTestNotification` (~ligne 106).
2. La ligne `"deepLinkTarget": timing.deepLinkTarget,` dans `schedule(prayer:timing:offsetSeconds:center:)` (~ligne 185).
3. La computed property `var deepLinkTarget: String { ... }` de l'enum privé `Timing` (~lignes 157–163).
4. Mettre à jour le doc comment de `scheduleTestNotification` (~ligne 93) : remplacer
   « (détermine titre, deepLinkTarget, gradient sheet) » par « (détermine titre et gradient sheet) ».

---

## 6. Contraintes (CLAUDE.md du projet)

- Indentation 4 espaces, sections `// MARK: -`.
- **Jamais** de `!`, `try!`, `as!`.
- Pas de nouveau code Combine ; pas de `DispatchQueue.main.async`.
- Clés UserDefaults = constantes nommées (fait dans `NotificationDeepLink`).
- Ne PAS toucher : `willPresent`, `handleControlDeepLink`, `QuranKhatmaCard`,
  `NotificationManager`, `QuranReminderScheduler`, le côté watchOS.
- Avant d'annoncer terminé : build complet du target iOS.

---

## 7. Plan de vérification

### Build
1. Compiler le target « Muslim Clock » (le nouveau fichier doit être ajouté au target iOS uniquement).

### Tests manuels — matrice 3 notifs × 3 états de l'app

Outils existants :
- **Adhkar** : bouton de test DEBUG dans `SettingsView` → `AdhkarReminderScheduler.scheduleTestNotification(timing:seconds:)` (fire à 10 s).
- **Adhan** : `NotificationManager.shared.scheduleAdhan(for: "Test", at: Date().addingTimeInterval(10))`.
- **Quran** : programmer via le plan actif ou ajouter temporairement un bouton DEBUG appelant
  `QuranReminderScheduler` avec une prière à `now + 10 s` (à retirer après test).

| Cas | État app au fire | Action | Attendu |
|---|---|---|---|
| Adhan | foreground | rien (bannière) | overlay Adhan s'affiche (comportement existant conservé) |
| Adhan | background | tap notif | overlay Adhan à l'ouverture |
| Adhan | **tuée** | tap notif | **overlay Adhan au cold start** (nouveau) |
| Adhan | tuée | tap une notif vieille de > 30 min | app s'ouvre normalement, PAS d'overlay (nouveau) |
| Quran | background | tap notif | switch tab Rappel + sheet Tracker |
| Quran | **tuée** | tap notif | **switch tab Rappel + sheet Tracker au cold start** (nouveau) |
| Adhkar | background | tap notif matin/soir | sheet Adhkar au bon timing |
| Adhkar | **tuée** | tap notif matin/soir | **sheet Adhkar au bon timing au cold start** (nouveau) |
| Tous | foreground | tap bannière puis background/retour < 30 s | pas de double ouverture (route effacée par le handler live) |

### Non-régression
- Control Widgets (Qibla / Adhkar / Quran) : vérifier que `handleControlDeepLink` route toujours
  (l'appel ajouté est AVANT lui dans le même `onChange`, les deux doivent coexister).
- Notif nouvelle lune : tap → app s'ouvre normalement, aucune route (payload vide → `case nil`
  sans `prayerName` → no-op). ✔ par design.
