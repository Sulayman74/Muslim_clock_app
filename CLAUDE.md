# Muslim Clock — Guide pour Claude

App SwiftUI iOS/watchOS de prières musulmanes (horaires Adhan, Qiblah, Adhkar, podcasts, widgets, complications).

## Principes obligatoires

### KISS — Simple par défaut
- Préférer une fonction directe à une abstraction prématurée. Pas de protocole tant qu'il n'y a qu'une implémentation.
- 3 lignes dupliquées valent mieux qu'une mauvaise abstraction.
- Pas de feature flag, pas de couche de compat si on peut juste changer le code.

### SOLID (appliqué pragmatiquement)
- **SRP** : une `struct`/`class` = une responsabilité claire. `PrayerTimesViewModel` calcule les horaires, pas la météo.
- **OCP/LSP/ISP** : ne pas créer de protocoles spéculatifs. Extraire un protocole **uniquement** quand un second implémenteur existe ou pour mocker un test.
- **DIP** : les Views dépendent de ViewModels (`@Observable` ou `ObservableObject`), pas de services concrets directement.

### DRY — mais pas WET-paranoïaque
- Toute logique répétée 3+ fois → extraire dans `DesignSystem.swift`, helper, ou ViewModel.
- Constantes (clés UserDefaults, durées, seuils) → constantes nommées, jamais magiques inline.

### Non-régression (CRITIQUE)
Avant **toute** modification d'un symbole public (fonction, type, propriété) :
1. `Grep` du nom dans tout le repo → identifier **tous** les callers.
2. Vérifier que la modif est compatible avec chaque caller, ou les mettre à jour.
3. Builder avec `BuildProject` avant d'annoncer la tâche faite.
4. Si tests existent : les lancer (`RunSomeTests`).

Cibles fréquentes de régression dans ce projet :
- `SharedLocationManager.shared` (singleton — consommé par PrayerTimesViewModel, WeatherViewModel, CompassManager).
- `PrayerTimesViewModel` (utilisé par MainView, widgets, complication, WatchSession).
- `WatchSessionManager` (synchro iOS ↔ watchOS — casser ça casse les deux côtés).
- Clés `UserDefaults` partagées (cf. inventaire dans memory).

### Robustesse
- **Jamais** de `!` (force unwrap) sauf `@IBOutlet` ou littéraux compile-time prouvés (`URL(string: "https://...")!` toléré pour constantes).
- **Jamais** `try!` ni `as!` sauf justifié par un commentaire `// Why: ...`.
- Erreurs aux frontières uniquement : appels réseau (`RemoteJSONLoader`), décodage JSON, services système (CoreLocation, AVFoundation). Le code interne fait confiance à ses propres invariants.
- `do/catch` qui swallow l'erreur silencieusement = interdit. Logger au minimum (`print` toléré, idéalement `os.Logger`).
- Async/await partout. **Pas de nouveau code Combine.** Le code Combine existant (ex: `SharedLocationManager` publisher) reste pour compat — ne pas l'étendre.

### Documentation — DocC (`///`)
Format DocC officiel Apple (pas JSDoc — c'est du JavaScript).

Documenter **uniquement** :
- API publiques (`public`, `internal` exposé hors fichier).
- Logique non-évidente (algos Adhan, gestion DST, fenêtre adhkar matin/soir).

Format :
```swift
/// Calcule les horaires de prière pour la date et la position fournies.
///
/// Utilise la méthode `MuslimWorldLeague` par défaut. Les offsets utilisateur
/// stockés dans `UserDefaults` sont appliqués après calcul.
///
/// - Parameters:
///   - date: Date locale (timezone du device).
///   - coordinates: Latitude/longitude WGS84.
/// - Returns: `PrayerTimes` ou `nil` si lat/lon invalides.
/// - Throws: `AdhanError.invalidCoordinates` si hors plage.
func computePrayers(for date: Date, at coordinates: Coordinates) throws -> PrayerTimes?
```

**Ne jamais** documenter ce que le code dit déjà (`/// Returns the name` au-dessus de `func getName() -> String` = bruit).

## Architecture du projet

### Location (source unique)
- `SharedLocationManager.shared` est **la seule** source de coordonnées GPS.
- Tout consumer s'abonne via le publisher Combine `userLocation` OU lit `manager.currentLocation`.
- **Ne jamais** créer un `CLLocationManager` ailleurs, sauf pour `startUpdatingHeading()` (boussole — cas isolé dans `CompassManager`).

### State management SwiftUI
- `@State private var` pour état local à une View.
- `@Binding` pour propager un state enfant → parent.
- `@StateObject` / `@ObservedObject` pour ObservableObject (legacy).
- `@Observable` (macro Swift 5.9+) pour nouveaux ViewModels — préféré.
- `@EnvironmentObject` pour services partagés (NetworkMonitor, etc.).

### Pas de logique métier dans les Views
Une `View.body` contient **uniquement** du layout + bindings. Calculs, formats, side-effects → ViewModel ou helper.

### Async/await
- API I/O (réseau, fichiers, CoreLocation moderne) → `async throws`.
- Pas de `DispatchQueue.main.async` dans du nouveau code → utiliser `@MainActor` ou `await MainActor.run`.
- Tâches longues dans `.task { }` (auto-cancel) plutôt que `.onAppear { Task { } }`.

### Conventions nommage
- Types : `PascalCase` (`PrayerTimesViewModel`).
- Propriétés/fonctions : `camelCase` (`fajrTime`, `computePrayers()`).
- Constantes globales : `camelCase` typées (`static let defaultOffset: TimeInterval = 0`).
- Clés UserDefaults : `snake_case_string` constantes (`"saved_latitude"`).

### Formatage
- Indentation : 4 espaces.
- Imports : groupés en haut (SwiftUI, Foundation, puis frameworks Apple, puis SPM).
- Séparation logique : marquer les sections avec `// MARK: -`.

## Workflow

### Avant modification
1. `Read` le fichier complet, pas seulement la zone visée.
2. `Grep` les usages du symbole modifié.
3. Identifier les widgets/complication/watch app qui partagent le code.

### Après modification
1. `XcodeRefreshCodeIssuesInFile` sur les fichiers touchés (rapide, valide les types).
2. `BuildProject` si modif non triviale ou multi-fichiers.
3. Tester en preview (`RenderPreview`) pour les Views modifiées.

### Limiter le scope
Si l'utilisateur demande X, ne pas refactorer Y au passage — même si Y est sale. Mentionner Y dans la réponse, mais ne pas le toucher sans accord explicite.

## Pièges connus (du memory audit)

- `CompassManager` : son `CLLocationManager` privé sert uniquement au heading (boussole). La position vient de `SharedLocationManager`.
- `ReviewHelper` : utilise `reviewRequestDates` (fenêtre glissante 365j), pas `totalReviewRequestsCount` legacy.
- `RemoteJSONLoader` : pas d'expiration de cache — vérifier avant d'ajouter du contenu remote dynamique.
- `Muslim_ClockApp.swift` : `AdhanTriggered` posté à 2 endroits — attention si on touche aux notifications.

## Stack technique
- iOS 17+ / watchOS 10+ (vérifier les `@available` avant API récente).
- SwiftUI principal, UIKit absent.
- SPM : `Adhan` (calcul horaires).
- Widgets (`SalatWidget`), complication watchOS (`PrayerComplication`), watch app (`WatchExtension Watch App`).
- Localisation : `Localizable.xcstrings` (catalog) — toute string user-facing passe par `String(localized:)` ou `NSLocalizedString`.
