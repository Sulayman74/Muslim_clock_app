# Plan — « Shazam du Coran » (identification de verset par récitation)

Synthèse de 2 analyses parallèles (expert SwiftUI/architecture, CTO
risques/phasage) — 6 septembre 2026. Base : 1.5.0 build 10.

## 0. Réalité technique d'entrée

Le vrai Shazam utilise des **empreintes audio** — inapplicable ici : la voix de
l'utilisateur ≠ l'enregistrement d'un récitateur. La voie réaliste :
**reconnaissance vocale arabe → normalisation → recherche floue sur les 6 236
versets → top-3 candidats**.

## 1. RISQUE N°1 (structurel, mesurable) — l'ASR sur récitation psalmodiée

Les modèles (Apple comme génériques) sont entraînés sur l'arabe **parlé** ; la
récitation (tajwid : madd 4-6 temps, ghunna, mélodie) + les locuteurs
non-arabophones (une grande partie de la base) donnent un WER attendu de
40-70 % en récitation naturelle. Mitigé par le matching tolérant (3-4 mots
corrects + 1 mot rare suffisent souvent à identifier un verset), mais **pas
éliminable par l'UX** → ça se mesure (Phase 0), ça ne se devine pas.

Position produit actée :
- Ne JAMAIS demander de réciter « sans tajwid » (maladroit religieusement).
  Wording : « récite clairement, à un rythme posé ».
- **Top-3 + « réessayer »**, jamais un top-1 sec : on assume l'incertitude.
  Une mauvaise réponse coûte plus cher qu'un échec avoué.
- Versets répétés (فبأي آلاء ربكما تكذبان ×31 dans Ar-Rahman) : **résultat
  groupé** (« apparaît 31× »), pas de fausse désambiguïsation.

## 2. Décision moteur — Phase 0 obligatoire (spike 3-5 j, code jetable)

**Exigence CTO : 100 % on-device, non négociable** (le PrivacyInfo « zéro
collecte » est un différenciateur — pas d'audio envoyé à un serveur).

Le spike teste LES DEUX moteurs sur le même corpus audio :
1. **SFSpeechRecognizer ar-SA avec `requiresOnDeviceRecognition = true`** —
   ⚠️ le support on-device de l'arabe est incertain, à vérifier au runtime.
   S'il n'existe qu'en mode serveur → ce moteur est éliminé d'office.
2. **Whisper fine-tuné Coran embarqué** (écosystème Tarteel/HuggingFace,
   ~80-150 Mo quantifié, via WhisperKit/whisper.cpp — vérifier la licence du
   fine-tune retenu). Le seul candidat crédible sur tajwid réel. Coût :
   téléchargement de modèle à la demande (pattern AudioCacheManager existant).
   Avantage : aucune permission speech, seulement le micro déjà en place.
3. (1 h max) Vérifier `DictationTranscriber` iOS 26 (arabe via assets de
   dictée) — piste V2, pas une stratégie.

**Critères GO/NO-GO (mesurés sur 30 versets récités réellement, dont 2-3
locuteurs non-arabophones) :**

| Critère | Seuil GO |
|---------|----------|
| Top-3, récitation naturelle (tajwid) | ≥ 70 % |
| Top-3, récitation posée | ≥ 85 % |
| Top-1, récitation posée | ≥ 60 % |
| Latence fin de parole → résultat (iPhone 12+) | ≤ 5 s médiane |
| Faux positifs confiants | ≤ 10 % |

NO-GO des deux moteurs → feature gelée, documentée, re-évaluée à la prochaine
génération de modèles. Pas de version dégradée en prod.

## 3. Architecture (indépendante du moteur — blueprint de l'expert)

Séparation stricte pur/I-O/UI, pattern du repo (AdhkarSearch, IlmMath).

### Fichiers à créer

| Fichier | Rôle |
|---------|------|
| `QuranSearchNormalizer.swift` (pur) | Normalisation arabe étendue : harakât + signes coraniques (U+06D6-U+06ED), ٱأإآ→ا, ى→ي, ة→ه, ؤ/ئ, strip basmala. **Ne pas modifier `strippedTashkeel`** (autres callers). |
| `QuranVerseMatcher.swift` (pur) | Index inversé mot→versets pondéré IDF (candidats, <5 ms) → re-scoring par **containment de trigrammes de caractères** (tolérant aux erreurs ASR ; containment et non Jaccard : on récite un *fragment*). `isConfident` : top1 ≥ 0.55, ≥ 3 mots, écart top2 ≥ 0.15. Groupage des doublons. Minimum 3 mots normalisés. |
| `QuranSearchCorpusLoader.swift` | Corpus bundlé → index en background (<150 ms), ~6 Mo RAM, purgeable/reconstruisible. |
| `QuranVerseIdentifier.swift` | Service ASR `@MainActor @Observable`, machine à états (idle/listening/matched/noMatch/permissionDenied/unavailable), AVAudioEngine + tap (RMS pour waveform), matching incrémental sur les partiels (throttle 0,6 s), arrêt auto si confiant / silence 2,5 s / cap 30 s. |
| `QuranVerseIdentifierView.swift` | Sheet sur CosmicBackground, glassCard, protocole anti-wiggle (minHeight transcript, transitions explicites, geometryGroup). |

### Corpus offline (point tranché entre les 2 agents)

Bundler un JSON texte-seul **imla'i** (graphie moderne, source Tanzil
« simple ») ~1-1,5 Mo : évite que la table de conversion uthmani→moderne
(صلوة→صلاة, سموت→سماوات…) soit le maillon faible. L'affichage continue
d'utiliser la bibliothèque uthmani existante (QuranLibraryLoader). Corpus ET
transcript passent par le MÊME `QuranSearchNormalizer` (invariant testé).
Rejeté : dépendre du cache CDN (partiel, purgeable).

### UX

- Entrée : bouton toolbar `waveform.badge.magnifyingglass` dans
  `QuranLibraryView` (visible seulement si moteur dispo). Une 2ᵉ entrée
  possible depuis la card Khatma en V1+.
- Résultat → navigation `QuranChapterDetailView(chapterIndex:scrollToAyah:)`
  (mécanisme ResumeRoute éprouvé, scroll + highlight).
- Permissions : micro (pattern QuranRecorder) ; + speech UNIQUEMENT si moteur
  SFSpeech (Whisper n'en a pas besoin). `NSSpeechRecognitionUsageDescription`
  le cas échéant + élargir le wording micro existant. PrivacyInfo : zéro
  nouvelle collecte (on-device).
- **Aucune persistance des audios d'identification** (contrairement au
  recorder — rien sur disque).

### Hors périmètre V1 (opposable)

Pas de correction de tajwid, pas de karaoké mot à mot, pas d'historique, pas
de désambiguïsation des versets identiques, pas de qira'at hors Hafs, pas de
widget/watch/Siri.

## 4. Phasage

**Phase 0 — Spike** (cf. §2). Livrable : mesures + décision GO/NO-GO + moteur.

**Phase 1 — MVP** (~2 semaines après GO), étapes buildables :
1. `QuranSearchNormalizer` + tests (paires صلوة/صلاة…, basmala, idempotence)
2. Corpus bundlé + `QuranVerseMatcher` + `CorpusLoader` + tests (fixture avec
   doublons Ar-Rahman, fragment de verset long, 2 mots → noMatch, seuils)
   — **quick win vendable dès cette étape : recherche plein-texte arabe tapée
   dans QuranLibraryView**, même sans micro
3. `QuranVerseIdentifier` (moteur gagnant) + Info.plist/InfoPlist.xcstrings
4. UI + navigation + strings localisées
5. Durcissement : modes dégradés (refus, indisponible, modèle non téléchargé),
   haptics, tuning des seuils sur récitations réelles

**Phase 2 — selon retours** : historique, écoute continue, **« verset
suivant »** (aide à la mémorisation — le cas d'usage caché : « je bloque,
quelle est la suite ? »), upgrade moteur.

## 5. Protocole de test (golden set, versionné hors app)

~60 enregistrements : 20 courts / 20 moyens / 20 longs (Ayat al-Kursi…) ;
pièges obligatoires : refrains répétés (groupage), paires mutashabihat
(Al-Baqara/Al-Imran — faux positifs confiants), célèbres vs obscurs (biais) ;
≥ 6 locuteurs (h/f/enfant, natifs ET francophones), murattal lent / mujawwad /
voix basse ; silence / réverb / bruit. Mesures : top-1/top-3 par texte de
verset, latence médiane + p95, taux échec-avoué vs mauvaise-réponse. Le
pipeline transcription+matching sur ces fichiers devient une suite de
régression relancée à chaque release et à chaque iOS majeur.

## 6. Décisions à acter avant de démarrer

1. Lancer la Phase 0 (spike 3-5 j) avec les seuils GO/NO-GO ci-dessus.
2. Principe on-device only + non-périmètre V1.
3. Politique « top-3 + réessayer » et « résultat groupé » pour les doublons.
