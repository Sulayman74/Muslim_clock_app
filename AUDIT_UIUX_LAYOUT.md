# Audit UI/UX — Robustesse Layout & Rendu Natif

**Cible** : Muslim Clock — SwiftUI iOS 17+, FR/AR bilingue, Liquid Glass.
**Mode** : read-only. Aucune modification de code. Recommandations strictement **additives**.
**Date** : 2026-06-02.

> ⚠️ **Validation finale obligatoire sur device** : iPhone SE 3e gen (375pt) + iPhone 13 mini, en Dynamic Type **AX5** (le plus large), avec contenu **arabe long** (verset + hadith + nom de sourate). L'audit suivant est statique — il liste les risques mais ne remplace pas un run réel.

---

## 1. Risques d'overflow horizontal (axe X)

| Écran | Composant | Fichier:ligne | Cause | Correctif additif |
|---|---|---|---|---|
| Tab Rappel | Boutons header (Play/Refresh/Toggle/Share) | `DailyContentView.swift:30-94` | 5 boutons en `HStack` sans stratégie de repli ; sur 375pt + Dynamic Type AX5 → squeeze | Wrapper avec `ViewThatFits(in: .horizontal) { HStack {…}; VStack {…} }` ou réduire spacing 8→4 + `.font(.system(size: 10))` |
| Tab Rappel | Titre podcast carousel | `DailyContentView.swift:476-478` | `.lineLimit(2)` sans `.minimumScaleFactor` ; titre arabe long ("السلسلة الفقهية الكاملة في دروس الشيخ…") déborde | Ajouter `.minimumScaleFactor(0.75)` |
| Tab Salat | Cards épisode podcast | `DailyContentView.swift:551-556` | `.lineLimit(3)` + frame `200×170` fixe ; mélange AR+FR provoque overflow vertical text-tail | Remplacer par `.fixedSize(horizontal: false, vertical: true)` ou augmenter la hauteur réservée |
| Adhkar | Texte arabe `DhikrCardView` | `AdhkarView.swift:395-410` | `.font(.system(size: 20))` fixe + `.lineSpacing(10)` sans `minimumScaleFactor` ni `fixedSize` → dépasse sur SE | **🔴 Critique** : ajouter `.minimumScaleFactor(0.75)` ET `.fixedSize(horizontal: false, vertical: true)` |
| Adhkar | Barre boutons inférieure | `AdhkarView.swift:425-478` | 4 boutons + Spacer + badge `x N` ; HStack très serré sur 375pt | Réduire `font` boutons toggle à 9pt + padding 8→6 |
| Settings | Picker "Langue" | `SettingsView.swift:85-91` | Texte "Automatique (système)" en List — wrapping possible AX5 | `.lineLimit(1) + .truncationMode(.tail)` |
| Qibla | Labels footer (degrés / cardinaux) | `QiblahView.swift:191-199` | `.font(.system(size: 12))` + `.tracking(2)` figés | Réduire à 10pt + tracking conditionnel sur 375pt |
| Adhkar Quick Access | Bloc texte "Adhkar du Moment" | `AdhkarView.swift:531-539` | VStack `(AR bold + FR petit)` sur `maxWidth: .infinity` sans `fixedSize` vertical | `.fixedSize(horizontal: false, vertical: true)` |
| DailyContent | Source hadith/ayah | `DailyContentView.swift:116-119` | "— (Sahih Al-Bukhari 1234, livre…)" peut wrapper sur étroit | `.truncationMode(.tail)` + 10pt |

---

## 2. Sources de wiggle (sautillement / reflow)

| Écran | Composant | Fichier:ligne | Cause | Correctif additif |
|---|---|---|---|---|
| Tab Rappel | Ayah/Hadith + carousel | `DailyContentView.swift:97-196` | `.redacted(reason:)` appliqué au **parent** VStack → swap placeholder ↔ contenu change la hauteur du texte arabe | Appliquer `.redacted` au `Text` seul, ou réserver `.frame(minHeight: 120)` au Group AR avant redacted |
| Tab Rappel | Artwork podcast (AsyncImage) | `DailyContentView.swift:421-446` | `.empty`→ProgressView OK, mais le swap success change opacité/blur sans frame égalisé | Encapsuler dans `ZStack { Color.clear.frame(64×64); AsyncImage(…) }` pour figer l'espace |
| Adhkar Sheet | Toggle AR↔FR | `AdhkarView.swift:233-242` | `.animation(.easeInOut)` au **parent** HStack → anime aussi le badge `x N` | Cibler l'animation : `.animation(.easeInOut, value: showArabic)` sur le `Group` Text, pas le parent |
| Tab Salat | `CurrentPrayerGaugeView` | `PostPrayerAdhkarService.swift:108-189` | Changement de fenêtre prière (en cours → nuit → rappel) re-rend tout le VStack sans `id` — animation init parasite | Ajouter `.id(prayerVM.currentPrayerWindow)` au VStack englobant pour forcer reconstruct propre |
| Mini Player | Ondes audio (3 barres) | `MiniPlayerView.swift:108-139` | onChange `isPlaying` bascule animation → spring parasite au toggle | Wrapper l'assignation dans `withTransaction(.init(animation: nil))` pour absorber le toggle |
| FullPlayer | Artwork scale | `MiniPlayerView.swift:180-200` | `.scaleEffect(manager.isPlaying ? 1.0 : 0.88)` animé pendant fetch AsyncImage parallèle | `.animation(.easeInOut(duration: 0.2), value: manager.isPlaying)` explicite, frame réservée fixe |
| Qibla | Proximity bar 4 capsules | `QiblahView.swift:378-402` | `.animation().delay(i * 0.04)` — animation décalée fine mais peut micro-stutter | Tester `spring(dampingFraction: 0.85)` à la place de `interpolatingSpring` |

---

## 3. Typographie arabe & RTL

| Fichier:ligne | Problème | Correctif |
|---|---|---|
| `MainView.swift:42-50` (WidgetDateHeader compact) | Date hijri sans `lineSpacing` pour diacritiques + `.environment(\.layoutDirection)` manquant au VStack parent | Envelopper VStack dans `.environment(\.layoutDirection, .rightToLeft)` + `.lineSpacing(6)` |
| `AdhkarView.swift:275-278` (header AR "أذكار الصباح") | `.font(.system(size: 22, bold))` sans environment RTL enveloppant → risque alignement LTR par défaut | **🔴 Ajouter** `.environment(\.layoutDirection, .rightToLeft)` au VStack headerView |
| `AdhkarView.swift:395-410` (DhikrCardView AR) | `multilineTextAlignment(.center)` OK, mais pas de `fixedSize` vertical → texte long peut être tronqué | `.fixedSize(horizontal: false, vertical: true)` après `.lineSpacing(10)` |
| `DailyContentView.swift:99-104` (verset AR) | OK actuellement (`font(22) + lineSpacing(10) + center`), mais aucun garde-fou contre futur `.lineLimit(1)` accidentel | Ajouter commentaire `// RTL: never apply .lineLimit(1) — amputerait le sens` |
| `PostPrayerAdhkarService.swift:306-310` (rappel coranique AR) | `font(19) + lineSpacing(8)` OK ; mais sur 375pt + AX5, peut sortir | Ajouter `.minimumScaleFactor(0.80)` |
| `SettingsView.swift:89` (Picker "العربية") | Pas de padding spécifique → squeeze possible | `.padding(.horizontal, 4)` ou augmenter row height |
| `AdhanOverlay.swift:92-95` (nom prière AR overlay) | `.font(.system(size: 36, weight: .medium))` sans `lineSpacing` — un nom long ("الفجر الشريف") trop tight | `.lineSpacing(2)` + envisager 32pt si débordement |
| `WeatherMiniWidget.swift:18` (city name) | `.lineLimit(1)` OK mais pas `.truncationMode(.tail)` explicite | `.truncationMode(.tail)` pour clarté |

---

## 4. Conformité native (HIG)

| Fichier:ligne | Écart HIG | Correctif |
|---|---|---|
| `DailyContentView.swift:42-50` (Audio Ayah play button) | Bouton `frame(30×30)` — **< 44pt** cible tactile HIG | **🔴 `.frame(width: 44, height: 44)`** + `.contentShape(Rectangle())` pour hit zone élargie |
| `AdhkarView.swift:450-478` (compteur tap zone) | Padding 14h + 8v → 42×30, sous 44pt en hauteur | Augmenter padding vertical à 10 → 44×34 (toujours sous limite mais mieux) |
| `MoonWidgetView.swift:159-163` (cellules phases 5 jours) | Pas de `frame(minHeight:)` → hauteur variable selon contenu | `.frame(minHeight: 50)` par cellule pour stabilité tactile |
| `MainView.swift:362-375` (top safe area) | `safeAreaInset(.top)` + `overlay(alignment: .top)` simultanés → risque overlap update banner + network banner | Harmoniser : un seul `safeAreaInset` avec VStack interne |
| `MainView.swift:248-249` | `frame(maxWidth: .infinity)` + `.containerRelativeFrame(.horizontal)` redondants | Retirer `.containerRelativeFrame(.horizontal)` (déjà couvert par maxWidth) |
| `SettingsView.swift:51-260` | `.preferredColorScheme(.dark)` local + déjà global dans `MainView.swift:90` → cohérent mais double déclaration | Garder uniquement la déclaration globale `Muslim_ClockApp` |
| `MainView.swift:203-205` (horloge 65pt) | `.monospacedDigit()` présent ✅ — pas d'écart | OK |
| `MiniPlayerView.swift:44-57` (mini player) | Play/Pause `frame(44, 44)` ✅ | OK |

---

## 5. Patterns correctifs réutilisables

### 5.1 Texte bilingue arabe long (anti-overflow)
```swift
Text(arabicVerse)
    .font(.system(size: 22))
    .lineSpacing(10)                                       // diacritiques
    .minimumScaleFactor(0.75)                              // élastique
    .fixedSize(horizontal: false, vertical: true)          // wrap intégral
    .multilineTextAlignment(.center)
    .environment(\.layoutDirection, .rightToLeft)
```

### 5.2 Conteneur fluide (anti-frame fixe)
```swift
// ❌ Frame en dur — casse sur SE 375pt
.frame(width: 300)

// ✅ Toujours maxWidth + alignment
.frame(maxWidth: .infinity, alignment: .leading)
.padding(.horizontal, 16)
```

### 5.3 AsyncImage sans wiggle
```swift
ZStack {
    Color.clear.frame(width: 64, height: 64)               // réserve l'espace AVANT load
    AsyncImage(url: url) { phase in
        switch phase {
        case .success(let img):
            img.resizable().frame(width: 64, height: 64)
        default:
            ProgressView().frame(width: 64, height: 64)
        }
    }
}
.redacted(reason: isLoading ? .placeholder : [])
```

### 5.4 Arabe avec diacritiques (lineSpacing)
```swift
// ≥ 6pt pour الفجر/الظهر avec voyellation, ≥ 8-10pt pour versets multi-ligne
Text(arabicWithDiacritics)
    .lineSpacing(8)
    .environment(\.layoutDirection, .rightToLeft)
```

### 5.5 Collapse adaptatif HStack ↔ VStack
```swift
ViewThatFits(in: .horizontal) {
    HStack(spacing: 8) { btn1; btn2; btn3; btn4; btn5 }     // largeur dispo OK
    VStack(spacing: 4) { btn1; btn2; btn3; btn4; btn5 }     // fallback SE/AX5
}
```

### 5.6 Animation localisée (anti-wiggle parent)
```swift
// ❌ Animation au parent → anime aussi les voisins
VStack { … }.animation(.easeInOut, value: toggle)

// ✅ Animation sur le Group qui change réellement
Group {
    if toggle { TextA.transition(.opacity) }
    else      { TextB.transition(.opacity) }
}
.animation(.easeInOut(duration: 0.3), value: toggle)
```

### 5.7 Cible tactile ≥ 44pt (HIG)
```swift
Button { … } label: {
    Image(systemName: "play.fill")
        .font(.system(size: 16))
        .frame(width: 44, height: 44)                       // zone tactile garantie
        .contentShape(Rectangle())                          // étend la hit zone
}
```

---

## 6. Quick wins priorisés

| # | Priorité | Composant | Fichier:ligne | Effort | Impact "natif" |
|---|---|---|---|---|---|
| QW1 | 🔴 Critique | `DhikrCardView` AR — `fixedSize` manquant | `AdhkarView.swift:395-410` | 1 ligne | Élevé — casse layout sur SE/AX5 |
| QW2 | 🔴 Critique | Header Adhkar — environment RTL manquant | `AdhkarView.swift:275-278` | 1 ligne | Élevé — arabe mal aligné |
| QW3 | 🔴 Critique | Titre podcast carousel — `minimumScaleFactor` | `DailyContentView.swift:476-478` | 1 ligne | Élevé — titre AR long déborde |
| QW4 | 🟠 Haute | Audio Ayah play button — HIG <44pt | `DailyContentView.swift:42-50` | 1 ligne | Moyen — accessibilité tactile |
| QW5 | 🟠 Haute | Verset/hadith redacted wiggle | `DailyContentView.swift:97-114` | 2 lignes | Moyen — sensation cassée au load |
| QW6 | 🟠 Haute | `CurrentPrayerGaugeView` id manquant | `PostPrayerAdhkarService.swift:108-189` | 1 ligne | Moyen — wiggle changement fenêtre |
| QW7 | 🟡 Moyen | Header DailyContent boutons (5 trop serrés) | `DailyContentView.swift:30-94` | 3 lignes | Moyen — débordement AX5 |
| QW8 | 🟡 Moyen | Compass labels — taille adaptative | `QiblahView.swift:191-199` | 1 ligne | Faible — cosmétique étroit |
| QW9 | 🟡 Moyen | Toggle AR↔FR animation localisée | `AdhkarView.swift:233-242` | 2 lignes | Faible — animation parasite |
| QW10 | 🟢 Bas | Settings Picker `lineLimit(1)` | `SettingsView.swift:85-91` | 1 ligne | Faible — préventif AX5 |
| QW11 | 🟢 Bas | `MoonWidgetView` cellules `minHeight` | `MoonWidgetView.swift:159-163` | 1 ligne | Faible — stabilité visuelle |
| QW12 | 🟢 Bas | Cleanup `containerRelativeFrame` redondant | `MainView.swift:248-249` | 1 ligne | Très faible — clarté code |

---

## Résumé exécutif

**Convergence des risques critiques** : les 3 quick wins prioritaires (QW1, QW2, QW3) ciblent tous **l'arabe sans garde-fou élastique**. Le pattern récurrent : `font(size:)` fixe + `lineSpacing` adapté **mais** sans `minimumScaleFactor` ni `fixedSize` ni `environment(RTL)`. Sur SE 375pt + Dynamic Type AX5, le texte arabe casse le layout.

**Second axe** : **redacted + AsyncImage** créent du wiggle faute de frame réservée. `DailyContentView.swift:97` est le cas typique (placeholder appliqué au parent qui change de taille).

**Conformité HIG** : un seul vrai écart tactile (`DailyContentView.swift:42-50` à 30pt < 44pt). Le reste est conforme.

**Validation impérative** :
1. **Build & Run** sur iPhone SE 3e gen + iPhone 13 mini en simulateur ou device
2. **Réglages → Affichage → Texte → AX5** (le plus grand)
3. Naviguer : Tab Rappel (verset + hadith + podcast), Adhkar sheet, Qibla, Settings
4. Vérifier en arabe + en français — pas de troncature, pas de saut de layout au load

Tous les correctifs proposés sont **strictement additifs** : aucune refonte structurelle, uniquement des ajustements de modificateurs.
