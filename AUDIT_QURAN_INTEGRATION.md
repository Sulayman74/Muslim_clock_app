# Audit — Intégration du Coran complet via `risan/quran-json`

**Date** : 2026-06-03.
**Mode** : read-only. Aucune modification de code. Rapport préalable à l'implémentation.
**Source retenue** : `risan/quran-json@3.1.2` via jsDelivr (Uthmani + translittération + traduction FR).

> Le rapport ci-dessous valide les hypothèses architecturales et le **schéma JSON réel** (fetch de 4 URLs effectué pour confirmation). Toutes les recommandations sont **additives** et compatibles avec le proto Khatma déjà en place.

---

## 1. Architecture réseau existante

**Correction importante** : `ContentSyncService` **n'existe pas** dans le projet (Glob = 0). Le service réel est **`Muslim Clock/RemoteJSONLoader.swift`** (65 lignes), une fonction statique générique :

```swift
static func load<T: Codable>(filename: String, remoteURL: String, type: T.Type) async -> T?
```

| Aspect | État | Verdict pour Coran |
|---|---|---|
| Pattern | `async/await` pur, `URLSession.shared.data(for:)`. Pas de Combine. | ✅ OK |
| Timeout | **5.0 s** (`request.timeoutInterval = 5.0`, ligne 24) | ⚠️ Trop court pour Sourate 2 (~80 KB) en cold cache → porter à 15 s |
| Cache policy | `.reloadIgnoringLocalCacheData` (ligne 25) — force réseau, ignore `URLCache` | ⚠️ Inefficace pour Coran (immutable) — court-circuiter |
| Décodage | `JSONDecoder()` par défaut, sans `keyDecodingStrategy` | ✅ OK (clés `snake_case` gérées via `CodingKeys` custom) |
| Fallback | Cascade **réseau → cache disque → bundle**, décodage avant écriture cache | ✅ Excellent — réutilisable |
| Robustesse | Force unwrap ligne 16 (`.first!`) — toléré (Apple garantit) mais non conforme CLAUDE.md | 🟡 Mineur |

**Verdict** : réutilisable avec **un seul ajustement** — ajouter un paramètre `timeout` à la signature de `load(…)`.

---

## 2. Stratégie de cache existante

- **Disque** : `FileManager.default.urls(for: .documentDirectory, …)` → **Documents** (backup iCloud activé, non purgeable par iOS).
- **URLCache** : non configuré (Grep négatif).
- **Expiration** : aucune. Pas d'invalidation ETag / hash. Voir memory audit `2026-04-08`.
- **Pour le Coran** : ~3-5 MB total pour 114 sourates JSON. Acceptable, mais **migration recommandée** vers `.cachesDirectory` (purgeable par iOS si stockage saturé, plus orthodoxe pour du contenu re-téléchargeable).

---

## 3. Schéma JSON validé (fetches effectifs)

### Tailles observées

| URL | Taille | Statut |
|---|---|---|
| `chapters/fr/index.json` | **23 229 B** | HTTP 200 |
| `chapters/fr/1.json` (Al-Fatiha) | **1 748 B** | HTTP 200 |
| `chapters/fr/112.json` (Al-Ikhlas) | **823 B** | HTTP 200 |
| `chapters/1.json` (sans FR) | **1 193 B** | HTTP 200 |

### Index racine — `[Chapter]`
- `id`: Int (1…114)
- `name`: String arabe court (ex. `"الفاتحة"`)
- `transliteration`: String (ex. `"Al-Fatihah"`)
- `translation`: String FR (ex. `"L'ouverture"`)
- `type`: String enum `"meccan" | "medinan"`
- `total_verses`: Int
- `link`: String (URL absolue jsDelivr vers la sourate FR)

### Sourate FR — extrait Al-Fatiha v1
```json
{
  "id": 1,
  "text": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ",
  "translation": "Au nom d'Allah, le Tout Miséricordieux, le Très Miséricordieux",
  "transliteration": "Bismi Allahi alrrahmani alrraheemi"
}
```

### Sourate FR — extrait Al-Ikhlas v1
```json
{
  "id": 1,
  "text": "قُلۡ هُوَ ٱللَّهُ أَحَدٌ",
  "translation": "Dis: «Il est Allah, Unique",
  "transliteration": "Qul huwa Allahu ahadun"
}
```

### Points notables
- Texte AR en **Uthmani simplifié** (présence de `ۡ` sukun + `ٱ` wasla) — compatible SF Arabic ✅
- **Aucun champ `page` / `juz` / `hizb`** → limitation majeure pour Khatma (voir §6)
- Pas de `bismillah` séparé : intégrée comme verset 1 de Fatiha. Pour les sourates 2-8 et 10-114, **il faudra l'afficher manuellement** avant verset 1 (norme UX)
- `total_verses` toujours fiable (validé v1=7 et v112=4)
- L'endpoint sans FR (`chapters/1.json`) omet `translation` à tous les niveaux

### Modèles Codable proposés

```swift
struct QuranChapterIndex: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let transliteration: String
    let translation: String?           // absent dans index racine sans FR
    let type: String                   // "meccan" | "medinan"
    let totalVerses: Int
    let link: String?                  // présent dans index, absent dans chapters/{id}

    enum CodingKeys: String, CodingKey {
        case id, name, transliteration, translation, type, link
        case totalVerses = "total_verses"
    }
}

struct QuranChapter: Codable, Identifiable {
    let id: Int
    let name: String
    let transliteration: String
    let translation: String?
    let type: String
    let totalVerses: Int
    let verses: [QuranAyah]

    enum CodingKeys: String, CodingKey {
        case id, name, transliteration, translation, type, verses
        case totalVerses = "total_verses"
    }
}

struct QuranAyah: Codable, Identifiable, Hashable {
    let id: Int                        // numéro dans la sourate
    let text: String                   // arabe Uthmani
    let translation: String?           // FR (nil sur endpoint sans trad)
    let transliteration: String
}
```

---

## 4. Modèles existants — verdict : **nouveau modèle**

Le proto `QuranTextModel.swift` est **orthogonal** à `quran-json` :
- Proto : modèle **par page Madinah** (`QuranPage { page, verses[(sura, ayah, text)] }`)
- `quran-json` : modèle **par sourate** (`Chapter { id, verses[…] }`)

**Conflits / friction** :
- Noms proches mais distincts (`QuranVerse` vs `QuranAyah`) → pas de collision Swift, mais évite la confusion en gardant les noms distincts.
- `SuraNames` (lignes 47-69) : hard-codé pour 10 sourates → **redondant** une fois `index.json` chargé. À retirer Phase 5.
- Le proto charge en synchrone (`Bundle.main.url`) → incompatible avec le pattern `async/await` de `RemoteJSONLoader`.

**Recommandation** : créer `QuranChapter.swift` + `QuranLibraryLoader.swift` en parallèle, garder le proto fonctionnel jusqu'à la Phase 5, puis le retirer.

---

## 5. UI / navigation

### Patterns RTL réutilisables (déjà dans le projet)
`.environment(\.layoutDirection, .rightToLeft)` — 16 occurrences (ex. `MainView.swift:45`, `AdhkarView.swift:278`, `AdhanOverlay.swift:95`, `QuranReaderView.swift:191`). Bonne base.

### Proto actuel (`QuranReaderView`)
Modèle **paginé Madinah**. Header dynamique sourates (lignes 119-132). Versets en `AttributedString` RTL (lignes 184-197). Chevrons RTL-aware. `@AppStorage("quranBookmarkPage")` ligne 26.

### Schéma cible — navigation à 2 niveaux

1. **`QuranLibraryView`** (NavigationStack) — liste 114 sourates depuis `index.json` :
   - Numéro + transliteration + nom arabe + traduction FR + badge meccan/medinan
   - Search bar (filtre sur transliteration + translation FR)
2. **`QuranChapterDetailView`** — versets en `ScrollView` verticale :
   - Pour chaque ayah : bloc AR RTL (grande taille) + transliteration (petite, gris italique) + traduction FR (subhead)
   - Marker `﴿n﴾` à la fin du bloc arabe (déjà fait, ligne 191 proto)
   - Toggle (afficher/masquer translit & FR) via `@AppStorage`

### Conflit avec Khatma
Le plan raisonne en **pages 1…604** (`QuranPlan.startPage`, `endPage`, `quranBookmarkPage`). `quran-json` n'expose **pas** de champ `page`. Trois options :

| Option | Description | Recommandé ? |
|---|---|---|
| (a) | Garder le proto Madinah pour Khatma + ajouter la lib sourate-based en parallèle (2 readers) | ❌ Redondant |
| (b) | **Embarquer un mapping ayah↔page** (~80 KB JSON, source Tanzil/QPC) | ✅ Recommandé |
| (c) | Convertir Khatma en `ayahsRead` plutôt que `pagesRead` | ❌ Refonte lourde, casse presets |

---

## 6. Points de friction

| # | Friction | Mitigation |
|---|---|---|
| F1 | **Polices arabes** : aucune `.ttf`/`.otf` embarquée (`Font.custom` absent). Tout l'arabe utilise **SF Arabic** système | Acceptable pour MVP. Optionnel : `KFGQPC-Uthmanic-Hafs.otf` (~3 MB, libre) pour rendu Madinah authentique (Phase 6) |
| F2 | **Index 23 KB** à charger | OK une fois au lancement du module, cache mémoire + disque ; pas de re-fetch à chaque ouverture |
| F3 | **Lazy par sourate** | Fetch à la demande à l'ouverture de la sourate. Cache illimité (Coran immutable). Sourate 2 ≈ 60-80 KB max |
| F4 | **Traducteur FR** : repo `risan/quran-json` agrège la traduction **Muhammad Hamidullah** (Tanzil.net → Complex Roi Fahd). Traduction la plus standard en FR | ✅ Conforme. Afficher attribution dans Settings (D4) |
| F5 | **Licence** | Code MIT ; texte AR domaine public ; Hamidullah FR libre de droits. Vérifier `LICENSE` du repo en Phase 1 |
| F6 | **Translittération** | Style alquran.cloud (ASCII brut, ex. `alrrahmani`) — pas ALA-LC scientifique. Acceptable pour lecture rapide, à signaler |
| F7 | **Mapping page Madinah absent** de `quran-json` | **Bloqueur architectural** — résolu en embarquant `quran-page-mapping.json` statique (cf. §5 option b) |
| F8 | **Bismillah** absente comme champ séparé | Pour sourates 2-8, 10-114 → afficher manuellement en tête de la sourate (norme UX attendue) |

---

## 7. Plan d'implémentation phasé

| Phase | Description | Fichiers | Risque | Tests |
|---|---|---|---|---|
| **1** | Modèles Codable + loader CDN avec cache. Ajout `QuranChapter`, `QuranAyah`, `QuranChapterIndex`. Nouveau `QuranLibraryLoader.swift` : `loadIndex() async`, `loadChapter(id:) async`, cache `Caches/quran/`. Réutilise `RemoteJSONLoader` (timeout porté à 15 s via paramètre) | + `QuranChapter.swift`, + `QuranLibraryLoader.swift`, M `RemoteJSONLoader.swift` | 🟢 Faible | Unit : fixtures Fatiha + Ikhlas + index local. Manuel : avion mode → fallback cache |
| **2** | Vue liste sourates `QuranLibraryView`. NavigationStack, liste paresseuse, search bar, badge meccan/medinan. Branchée depuis `QuranTrackerView` (remplace bouton "Lire dans l'app") | + `QuranLibraryView.swift`, M `QuranTrackerView.swift` | 🟢 Faible | Manuel : 114 lignes, recherche "Ya-Sin", scroll. `RenderPreview` |
| **3** | Vue détail sourate `QuranChapterDetailView`. Header (nom AR + transliteration + traduction + type). Liste versets : bloc AR RTL grande taille, marker `﴿n﴾` teal, transliteration gris italique, traduction FR. Toggle affichage translit & FR | + `QuranChapterDetailView.swift` | 🟢 Faible | Manuel : Fatiha + Baqara (long scroll) + Ikhlas. Dynamic Type XL |
| **4** | Mapping ayah ↔ page Madinah. Embarquer `quran-page-mapping.json` (source Tanzil/QPC). Service `QuranPageMapper.swift` : `page(for: sura, ayah)` + `firstAyah(of: page)`. Lien Khatma : ouverture sourate auto-scrolle au verset correspondant à `lastPageReached` | + `quran-page-mapping.json`, + `QuranPageMapper.swift`, M `QuranChapterDetailView`, M `QuranTrackerView` | 🟡 Moyen | Unit : mapping(1,1)=1, mapping(2,142)=22, mapping(114,6)=604 |
| **5** | Retrait du proto. Supprimer `QuranTextModel.swift`, `QuranTextLoader.swift`, `QuranReaderView.swift`, `quran-pages.json`. Migrer `@AppStorage("quranBookmarkPage")` (compatible — Int 1…604). Section Settings « À propos du texte » | D 4 fichiers, M `QuranTrackerView`, M `SettingsView` | 🟡 Moyen (suppression) | `BuildProject`. Grep symboles `SuraNames`/`QuranMushaf`/`QuranTextLoader` hors module |
| **6** *(optionnel)* | Police calligraphique. Embarquer `KFGQPC-Uthmanic-Hafs.otf` (~3 MB), enregistrer dans `Info.plist UIAppFonts`, appliquer via `Font.custom` dans `QuranChapterDetailView` | + font file, M Info.plist, M `QuranChapterDetailView` | 🟢 Faible | `RenderPreview`. Comparer avant/après |

---

## Résumé exécutif

Le schéma jsDelivr `quran-json@3.1.2` est **propre, stable et fetchable** (4 URLs vérifiées, HTTP 200). `RemoteJSONLoader` est **réutilisable** moyennant un paramètre de timeout. Le proto Madinah actuel (`QuranTextModel`/`QuranReaderView`/`quran-pages.json`) est **orthogonal** au schéma `quran-json` — repartir sur de nouveaux modèles `QuranChapter`/`QuranAyah` et retirer le proto en Phase 5. **Seul bloqueur** : `quran-json` n'expose pas le numéro de page Madinah qui pilote tout le plan Khatma — résolu via un fichier statique embarqué `quran-page-mapping.json`. Implémentation faisable en 5 phases commitables, risque global **faible à moyen**.

---

## Décisions à valider avant Phase 2

| # | Décision | Recommandation |
|---|---|---|
| **D1** | **Cache disque** : `.cachesDirectory` (purgeable iOS) ou `.documentDirectory` (persistant + iCloud) ? | `.cachesDirectory` — Coran rechargeable depuis CDN, pas de raison de gonfler le backup iCloud |
| **D2** | **Mapping page Madinah** : fichier statique embarqué (option b) ou 2 readers parallèles (option a) ? | Option (b) — 1 reader unifié, mapping statique 80 KB |
| **D3** | **Police arabe** : SF Arabic (0 poids) ou KFGQPC Uthmanic Hafs (~3 MB) ? | Phase 6 optionnelle après validation produit |
| **D4** | **Crédit traducteur** : afficher "Traduction : Muhammad Hamidullah" dans Settings ? | Oui (transparence + protège juridiquement) |
| **D5** | **Bismillah** pour sourates 2-114 (sauf 9) : afficher manuellement en tête ? | Oui (norme attendue par les utilisateurs) |

---

## Annexe — Fichiers clés (chemins absolus)

```
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/RemoteJSONLoader.swift          # service réseau (à étendre)
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/DailyContentService.swift       # exemple de consumer existant
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/QuranTextModel.swift            # proto Madinah (à retirer Phase 5)
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/QuranTextLoader.swift           # proto loader (à retirer Phase 5)
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/QuranReaderView.swift           # proto reader (à retirer Phase 5)
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/QuranTrackerView.swift          # point de branchement Khatma
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/QuranPlanModel.swift            # pages 1…604 (mapping ayah↔page requis)
/Volumes/Kappsi_docs/Dev/Muslim Clock/Muslim Clock/quran-pages.json                # dataset démo (à retirer Phase 5)
```
