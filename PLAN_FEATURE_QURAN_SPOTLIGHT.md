# Plan — « Spotlight du Coran » (recherche de verset : texte + récitation)

Synthèse de 2 analyses parallèles (expert SwiftUI/architecture, CTO
risques/phasage), recadrée le 6 septembre 2026 : ce n'est pas un Shazam
(empreintes audio inapplicables — la voix de l'utilisateur ≠ l'enregistrement
d'un récitateur), c'est un **moteur de recherche du Coran** à la Spotlight :

> Je cherche un verset — en le **tapant** ou en le **récitant** — et l'app me
> retrouve la sourate, le numéro de verset, et **toutes les occurrences**.

## 0. Ce que le recadrage change (et pourquoi il est meilleur)

Dans le cadrage « Shazam », la voix était le produit et l'ASR arabe (le maillon
risqué) était sur le chemin critique. Dans le cadrage « Spotlight » :

- **Le cœur du produit est le moteur de recherche** (normalisation arabe +
  index + scoring flou) — zéro risque, 100 % offline, fiable dès le jour 1.
- **La voix est UNE méthode de saisie** (le bouton micro de la barre de
  recherche, comme Spotlight iOS). Si l'ASR déçoit, la feature existe quand
  même ; si l'ASR marche, c'est la magie en plus.
- **Les occurrences deviennent un résultat de première classe** : chercher
  « فبأي آلاء ربكما تكذبان » liste les 31 emplacements navigables dans
  Ar-Rahman — c'est une vraie valeur d'étude, pas un cas limite à gérer.
- Le transcript vocal alimente le même champ de recherche → il est **visible
  et éditable** : une reconnaissance imparfaite se corrige au clavier au lieu
  d'échouer silencieusement.

## 1. Architecture (inchangée sur le fond — elle était déjà « search-first »)

Séparation pur / I-O / UI, pattern du repo (AdhkarSearch, IlmMath).

| Fichier | Rôle |
|---------|------|
| `QuranSearchNormalizer.swift` (pur) | Normalisation arabe étendue : harakât + signes coraniques (U+06D6-U+06ED), ٱأإآ→ا, ى→ي, ة→ه, ؤ/ئ, strip basmala. Ne pas toucher `strippedTashkeel` (autres callers). |
| `QuranVerseMatcher.swift` (pur) | Index inversé mot→versets pondéré IDF → re-scoring par containment de trigrammes de caractères (tolérant : fautes de frappe ET erreurs ASR). Versets au texte identique groupés avec la **liste complète des occurrences**. Minimum 3 mots normalisés. `isConfident` (seuils centralisés). |
| `QuranSearchCorpusLoader.swift` | Corpus bundlé → index en background (<150 ms), ~6 Mo RAM, purgeable. |
| `QuranVerseIdentifier.swift` (phase voix) | Service ASR `@MainActor @Observable`, AVAudioEngine + tap, matching incrémental sur les partiels, arrêt auto (confiance / silence 2,5 s / cap 30 s). Alimente le champ de recherche. |
| UI | Barre de recherche dans `QuranLibraryView` (elle existe déjà pour les noms de sourates → étendue au plein-texte) + bouton micro à droite (à la Spotlight). Résultats : sourate, n° verset, extrait surligné, badge « ×N occurrences » dépliable. Tap → `QuranChapterDetailView(scrollToAyah:)` (scroll + highlight existants). |

**Corpus offline** : JSON texte-seul **imla'i** (graphie moderne, source Tanzil
« simple ») ~1-1,5 Mo bundlé — évite que la conversion uthmani→moderne soit le
maillon faible. L'affichage garde la bibliothèque uthmani existante. Corpus ET
requête (tapée ou dictée) passent par le MÊME normaliseur (invariant testé).

## 2. Phasage (inversé par rapport au plan Shazam — le risque sort du chemin critique)

### Phase 1 — Le Spotlight texte (MVP autonome, vendable seul, ~1 semaine)
1. `QuranSearchNormalizer` + tests (paires صلوة/صلاة, basmala, idempotence)
2. Corpus bundlé + `QuranVerseMatcher` + loader + tests (fixture avec doublons
   Ar-Rahman, fragment de verset long, fautes de frappe, seuils)
3. UI : recherche plein-texte dans `QuranLibraryView` + occurrences + navigation
4. Durcissement + strings localisées

Aucune permission, aucun réseau, aucun risque ASR. C'est une feature complète :
« retrouve n'importe quel verset en tapant quelques mots ».

### Phase 2 — RÉSULTATS DU SPIKE (6-7 sept. 2026) : ✅ **GO — SFSpeech on-device**

Mesures réelles (iPhone 14, 33 essais mesurables sur 3 batchs, récitation
naturelle, harnais DEBUG « Spike ASR Coran ») — métriques stables entre
batchs (92 → 91 % top-1) :

| Métrique | Seuil GO | Mesuré |
|----------|----------|--------|
| Top-1 | ≥ 60 % | **91 %** (30/33) |
| Top-3 | ≥ 70 % | **94 %** (31/33) |
| Faux positifs confiants | ≤ 10 % | **0 %** |
| Latence | ≤ 5 s | **~40 ms** médiane (900 ms au 1ᵉʳ essai — warmup) |

Robustesse démontrée : 18:10 identifié (0.74, confiant) avec « الفتية »
transcrit… « فيديو » ; 21:87 identifié avec « ذا النون » → « هذا ن ».
Les 3 échecs/33 sont TOUS le même pattern : versets courts enchaînés + mot
distinctif (porteur d'IDF) déformé — couverts par le fix fenêtres bi-versets,
et toujours avoués non-confiants (le retry sur verset isolé réussit).

Le pronostic « SFSpeech arabe probablement serveur-only » est DÉMENTI :
`ar-SA` est disponible ET on-device sur iPhone 14. **Whisper-Coran
(tarteel-ai, Apache 2.0, ~100 Mo) passe en réserve documentée** — plus
nécessaire.

Faits marquants : transcript massacré par l'ASR (3:18 « بالقشطة ») →
quand même identifié à 0.81 (trigrammes) ; mutashabihat 2:210/6:158/16:33 →
bon verset en tête + non-confiant (prudence exacte) ; refrain Ar-Rahman →
×31 occurrences groupées.

Modes d'échec identifiés (backlog produit) :
1. **Versets courts enchaînés** (Falaq 1-4, Masad 1-2…) : les versets récités
   occupent les rangs 1-2 mais à scores faibles → fix : indexer des fenêtres
   bi-versets (V2 du matcher).
2. Fragment de 3 mots + mot rare déformé (essai 26, seul vrai échec) :
   avoué non-confiant, le retry a réussi — couvert par l'UX top-3/réessayer.
3. Warmup ~900 ms au premier usage → prewarm du recognizer à l'ouverture.

### Phase 2 — La saisie vocale (spike GO/NO-GO, PUIS intégration)
Spike 3-5 j (code jetable) sur les DEUX moteurs, **on-device only** :
- `SFSpeechRecognizer` ar + `requiresOnDeviceRecognition = true` (support
  arabe on-device incertain — vérifier au runtime ; serveur-only = éliminé,
  le PrivacyInfo « zéro collecte » est non négociable)
- **Whisper fine-tuné Coran** embarqué (~80-150 Mo, WhisperKit/whisper.cpp,
  vérifier la licence du fine-tune ; téléchargement à la demande — pattern
  AudioCacheManager) — le seul candidat crédible sur tajwid réel

Critères GO (mesurés sur 30 versets récités réellement, dont non-arabophones) :
top-3 ≥ 70 % récitation naturelle, ≥ 85 % récitation posée, top-1 posée ≥ 60 %,
latence ≤ 5 s, faux positifs confiants ≤ 10 %. **NO-GO des deux → la feature
reste le Spotlight texte** (déjà en prod) et la voix attend la génération de
modèles suivante. Le risque n'annule plus rien.

Intégration après GO : bouton micro dans la barre, transcript live injecté
dans le champ (visible, éditable), waveform pendant l'écoute, permissions
(micro pattern QuranRecorder ; + speech seulement si moteur SFSpeech),
`NSSpeechRecognitionUsageDescription` localisée le cas échéant. **Aucune
persistance des audios.**

### Phase 3 — selon retours
Historique de recherches, « verset suivant » (aide mémorisation : « je bloque,
quelle est la suite ? »), recherche par traduction FR, translittération.

## 3. Positions produit actées

- **On-device only** pour la voix (différenciateur privacy).
- **Top-3 + éditer/réessayer**, jamais un top-1 sec — le champ éditable est le
  filet de sécurité naturel du cadrage Spotlight.
- Versets répétés : occurrences **listées et navigables** (valeur d'étude).
- Jamais demander de réciter « sans tajwid » ; wording « récite clairement, à
  un rythme posé ».
- Hors périmètre V1 : correction de tajwid, karaoké mot à mot, qira'at hors
  Hafs, widget/watch/Siri, historique.

## 4. Protocole de test

- **Phase 1 (texte)** : tests unitaires purs (normaliseur, matcher) + requêtes
  pièges : fragments courts, fautes de frappe, mots ultra-fréquents seuls
  (الله من في → noMatch), mutashabihat (Al-Baqara/Al-Imran), refrains ×31/×10.
- **Phase 2 (voix)** : golden set audio ~60 enregistrements versionné hors app
  (courts/moyens/longs, ≥ 6 locuteurs h/f/enfant natifs et francophones,
  murattal/mujawwad/voix basse, silence/réverb/bruit). Mesures : top-1/top-3
  par texte de verset, latence médiane + p95, échec-avoué vs mauvaise-réponse
  (la seconde coûte plus cher). Suite de régression relancée à chaque release
  et à chaque iOS majeur.
