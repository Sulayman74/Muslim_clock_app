# Plan — Onglet 5 « Apprendre » : correcteur de récitation + révision hebdo (quiz)

Date : 2026-10-12. Statut : **plan, rien de codé**.
Cible réelle du projet : iOS 26.2 (pbxproj), pas 17 comme l'indique CLAUDE.md.
Cela ouvre `SpeechAnalyzer` (Speech) et `FoundationModels` (on-device).

---

## 0. Résumé exécutif

| Sujet | Verdict | Pourquoi |
|---|---|---|
| 5ᵉ onglet « Apprendre » | **Go**, faible risque | TabView en `Int`, 4 tags, accent par onglet déjà en place. Il faut juste un tag 4, une couleur, et rediriger 2 deep-links. |
| Quiz hebdo aqidah / fiqh | **Go**, risque faible, effort surtout **éditorial** | Le module Ilm existe (3 textes, Leitner 5 boîtes, rappels). Il manque : modèle question, thèmes, planificateur hebdo, vue quiz. |
| Correcteur de récitation — niveau **mots** (omission, substitution, ajout, répétition) | **Go**, 100 % on-device | Pipeline ASR + normaliseur + corpus déjà en prod (91 % top-1 au spike). Reste à écrire un **aligneur** et une vue résultat. |
| Correcteur — niveau **tajwid** (madd, ghunna, qalqala…) | **No-go** pour un jugement automatique | Aucun des moteurs disponibles (SFSpeech, Whisper-Coran, Gemini, Claude) n'offre une précision vérifiable. Un faux « tu t'es trompé » sur une récitation juste est inacceptable. On affiche les **règles applicables** au verset, pas un verdict. |
| Appel API Gemini ou Claude | **Non pour l'analyse audio.** Optionnel plus tard pour **formuler** un conseil texte. | Claude ne prend **pas d'audio** en entrée. Gemini oui, mais : backend obligatoire (clé API), rupture de la règle « jamais de reco serveur » gravée dans `QuranVerseIdentifier.swift:103`, modification de `PrivacyInfo.xcprivacy`, et précision tajwid non garantie. Le conseil texte peut être fait par templates (V1) puis `FoundationModels` on-device (V2), sans aucun appel réseau. |
| Choix Hafs / Warsh / Qaloun | **Go** avec données externes | QUL (Tarteel) distribue Warsh (ayah + mot à mot) et Qaloun (ayah) en JSON. Numérotation des versets différente de Hafs (6 214 vs 6 236) → mapping à prévoir. |

---

## 1. Existant à réutiliser (audit)

### Navigation
- `MainView.swift:212` `@State private var selectedTab = 0` ; TabView l.422-526, 4 onglets (Salat 0, Rappel 1, Qiblah 2, Réglages 3).
- Accent par onglet : `tabColor` l.276-284.
- Deep-links Ilm : `MainView.swift:726` et `:817` forcent `selectedTab = 1` ; `IlmProgramCard` lit le flag `pendingOpenIlmTracker`.
- Pas d'enum d'onglets. Pas de système de thème UI global (`.preferredColorScheme(.dark)` forcé). Le seul « thème » est `ReadingTheme` (sépia/sombre) partagé Coran + Ilm.
- Convention couleur déjà commentée dans `DesignSystem.swift:260-261` : teal = Coran, **purple = ʿIlm**.

### Module Ilm (`Ilm*.swift`, `ilm_tracks.json`, 166 Ko, bundle only)
- Tracks : `usul3` (20 leçons), `qawaid4` (6), `nawawi40` (42). Pas de fiqh, pas de Nawaqid, pas de quiz.
- `IlmProgress` : Leitner 5 boîtes (`reviewBox`, `nextReviewAt`), décodage tolérant → **extensible sans migration**.
- `IlmReviewOutcome` (`known/almost/forgot`) + `gradeReview()` : un mauvais QCM peut rétrograder la boîte de la leçon liée.
- `IlmReminderScheduler` : 1 notif quotidienne, pattern à dupliquer pour l'hebdo.
- Tests : `Muslim ClockTests/IlmMathTests.swift` (Swift Testing).
- Le JSON est **partagé avec Android** (`android/app/src/main/assets/ilm_tracks.json`) → tout nouveau schéma doit rester lisible côté Kotlin.

### Voix / récitation
- `QuranVerseIdentifier` : `SFSpeechRecognizer(ar-SA)`, `requiresOnDeviceRecognition = true`, arrêt 30 s / silence 2,5 s. Sortie : texte seul, **sans timestamps**.
- `QuranSearchNormalizer` : squelette sans harakât, hamzas unifiées, basmala retirée. Pur, testé.
- `QuranVerseMatcher` : index inversé IDF + trigrammes FNV-1a. Conçu pour **pardonner** — l'inverse d'un correcteur. On le garde pour **identifier** le passage, pas pour le juger.
- `QuranRecorder` : M4A AAC mono 44,1 kHz, 10 min max, `markVerse(ayahId:)` manuel. Partage via `ShareLink`.
- Corpus : `quran-search-corpus.json` (Hafs, 6 236 versets, imla'i vocalisé).
- Permissions micro + speech déclarées, textes à **réécrire** pour couvrir « analyse de ta récitation ».
- Plan B déjà documenté dans `PLAN_FEATURE_QURAN_SPOTLIGHT.md` : Whisper-Coran `tarteel-ai/whisper-base-ar-quran` (Apache 2.0, ~134-150 Mo en CoreML, WER ~5,8 %).

---

## 2. Faisabilité détaillée — correcteur de récitation

### 2.1 Ce qu'on peut détecter, et avec quoi

| Niveau | Erreur | SFSpeech / SpeechAnalyzer (on-device) | Whisper-Coran on-device | Gemini audio (cloud) | Claude |
|---|---|---|---|---|---|
| 1 | Mot omis / ajouté / substitué / répété | ✅ fiable sur mots courants, faux positifs sur mots rares | ✅ meilleur vocabulaire coranique | ✅ mais non vérifiable | ❌ pas d'audio |
| 1b | Hésitation, retour en arrière | ✅ via timestamps (`SpeechAnalyzer`) | ✅ timestamps | ⚠️ | ❌ |
| 2 | Fin de verset manquée, ordre des versets | ✅ par alignement | ✅ | ✅ | ❌ |
| 3 | Harakât (i'rab) | ⚠️ le modèle « dictée » normalise | ⚠️ partiel | ⚠️ plausible mais hallucine | ❌ |
| 4 | Tajwid (madd, ghunna, qalqala, idgham) | ❌ | ❌ | ❌ non fiable | ❌ |
| 5 | Spécificités de riwaya (imala, naql, taqlil Warsh) | ❌ transcrit « à la Hafs » | ❌ entraîné Hafs | ⚠️ | ❌ |

Conclusion produit : **V1 = correcteur de mots + hésitations, par riwaya, on-device**. Le tajwid est traité comme **fiche de vigilance** (règles présentes dans le verset, issues du script « QPC Hafs Tajweed » de QUL), jamais comme verdict.

### 2.2 Choix du moteur de transcription

Recommandation : **`SpeechAnalyzer` + `DictationTranscriber`** (iOS 26), locale `ar-SA`, preset `timeIndexedProgressiveTranscription`, `attributeOptions: [.audioTimeRange]`.
- Même modèle que `SFSpeechRecognizer` on-device (donc même support ar-SA constaté au spike), mais **avec time-ranges par segment** → alignement automatique verset/mot, plus besoin du bouton « Verset suivant ».
- Zéro téléchargement supplémentaire, zéro dépendance.
- À vérifier au premier spike : `await SpeechTranscriber.supportedLocales` contient bien `ar-SA` sur device. Sinon fallback `SFSpeechRecognizer` sans timestamps (mode dégradé : alignement par verset uniquement).

Phase ultérieure (si le WER du moteur Apple sur vocabulaire coranique déçoit) : **Whisper-Coran via WhisperKit**, téléchargé à la demande (pattern `AudioCacheManager`, manifest SHA-256). Décision sur mesure : 30 extraits × 3 riwayat, critère WER mot < 8 %.

### 2.3 Gemini ou Claude ?

- **Claude** (`claude-opus-5` par défaut si on y vient) : entrée texte/image/PDF uniquement. Il ne peut **pas** écouter la récitation. Son seul rôle possible : transformer une liste d'erreurs structurée en conseil pédagogique FR/AR. Ça impose un **proxy serveur** (jamais de clé dans l'app), donc hébergement, coût, RGPD. Hors de proportion pour V1.
- **Gemini** (3.x Flash) : accepte l'audio nativement (~25 tokens/s, soit environ 0,005 $/min d'audio en entrée d'après la grille publique). Mais : (a) il faut un backend ; (b) il faut abandonner la règle « jamais de reco serveur » et mettre à jour `PrivacyInfo.xcprivacy` + les textes de permission ; (c) sa précision tajwid n'est ni mesurée ni garantie, et il répondra avec assurance même quand il se trompe. Pour un sujet religieux, un faux positif coûte plus cher qu'une absence de détection.
- **Alternative retenue pour le « conseil »** :
  - V1 : **templates** localisés (`Localizable.xcstrings`). Les types d'erreurs sont finis, donc les phrases aussi. Ex. « Au verset 3, le mot « X » n'a pas été entendu. Réécoute le récitateur puis réessaie. »
  - V2 : **`FoundationModels`** on-device (`SystemLanguageModel.default`, vérifier `isAvailable` et `supportsLocale(fr)`) pour reformuler les templates en un paragraphe fluide, avec `@Generable` pour garder une structure. Gratuit, privé, pas de réseau. Désactivé proprement si indisponible (appareil non éligible).
  - Audio : `AVSpeechSynthesizer` (voix fr) lit le conseil + lecture du verset de référence par un récitateur **de la riwaya choisie**.

Position finale : **aucun appel LLM cloud dans cette feature**. On garde la porte ouverte (proxy + Claude texte) si un jour on veut des explications plus riches, mais ce n'est pas un prérequis.

### 2.4 Données par riwaya

| Riwaya | Texte de référence | Source | Numérotation | Audio de référence |
|---|---|---|---|---|
| Hafs | déjà en bundle (`quran-search-corpus.json`) | Tanzil / existant | Kufi, 6 236 | Alafasy (déjà via `cdn.islamic.network`) |
| Warsh | à ajouter, JSON ayah + mot-à-mot (`qpc-warsh`) | QUL `qul.tarteel.ai/resources/quran-script` | Madani, 6 214 | à sourcer (ex. mp3quran.net, récitateurs Warsh) |
| Qaloun | à ajouter, JSON ayah | QUL (Qaloon ayah by ayah) | Madani, 6 214 | à sourcer |

Points durs :
- **Mapping de numérotation** : les plans de lecture, la khatma et `QuranPageMapper` sont en Hafs. Le correcteur travaille **dans la numérotation de la riwaya** et n'écrit jamais dans les modules Hafs. Un petit fichier `riwaya_ayah_map.json` (Hafs ↔ Madani) servira uniquement à proposer « ouvrir ce passage dans le Coran ».
- **Normalisation riwaya-neutre** : `QuranSearchNormalizer` unifie déjà ؤ→و, أ/إ/آ→ا, etc. Il faut une table d'équivalences supplémentaire pour Warsh/Qaloun (ex. مومنين/مؤمنين déjà couvert ; الصراط/السراط ; formes avec naql). Table en JSON, testée.
- **Licence** : vérifier la licence de chaque ressource QUL (KFGQPC exige l'attribution). À documenter dans Réglages > À propos.
- **Poids** : ~1,4 Mo par riwaya compressé dans le bundle. Acceptable. Si on veut alléger, chargement à la demande via `RemoteJSONLoader` depuis le GitHub Pages existant.

### 2.5 Logique métier (domaine)

```
Riwaya (enum: hafs, warsh, qaloun)             @AppStorage("recitation_riwaya")
RecitationReference                              surah, ayahRange (numérotation riwaya),
                                                 words: [ReferenceWord(ayah, index, display, normalized)]
RecitationTranscript                             tokens: [HeardToken(normalized, timeRange?, confidence?)]
RecitationAligner.align(reference, transcript)   -> RecitationAlignment
   • Needleman-Wunsch sur tokens normalisés
   • coût de substitution = 1 - similarité trigrammes (réutilise la logique FNV du matcher)
   • similarité ≥ 0,75 → "match", 0,5-0,75 → "approximatif", < 0,5 → "substitué"
RecitationAlignment                              items: [AlignedWord(kind: matched|approximate|omitted|substituted|inserted|repeated,
                                                         referenceIndex?, heard?, timeRange?)]
                                                 accuracy (matched / reference.count), hesitations (gaps > 3 s intra-verset)
RecitationCoach.tips(alignment, riwaya)          -> [CoachTip(kind, ayah, wordIndex?, textFr, textAr?)]  (templates V1)
RecitationProgressStore                          UserDefaults JSON "recitation_progress":
                                                 [ayahKey: {attempts, bestAccuracy, lastDate, weakWordIndexes}]
```

Règles non négociables :
1. **On-device only.** Pas d'audio qui sort de l'appareil, sauf partage explicite par l'utilisateur (`ShareLink` existant).
2. **Pas de verdict tajwid.** Les fiches de vigilance sont informatives.
3. **Confiance affichée.** Sous 3 mots entendus ou accuracy < 0,3, on dit « je n'ai pas bien entendu » au lieu de lister des erreurs.
4. **Disclaimer permanent** : « Un mot non signalé n'est pas forcément juste. Fais valider ta récitation par un enseignant. »
5. Le correcteur ne modifie **jamais** `QuranPlanModel`, `ReadingEntry` ou la khatma.

### 2.6 Parcours utilisateur
1. Onglet Apprendre → carte « Récitation » → choix sourate + plage (ou « où j'en suis » depuis le plan Coran) + riwaya (mémorisée).
2. Écran de récitation : texte de référence **flouté** (mode mémorisation, déjà dans `IlmLessonView`) ou visible. Bouton micro. Transcription live discrète (pas de texte brut affiché, juste un indicateur « j'écoute »).
3. Stop (manuel ou silence) → alignement → **vue résultat** : texte de référence colorié (vert / orange / rouge / barré), score monospaced, liste de conseils, bouton « Écouter le conseil », bouton « Écouter le récitateur sur ce verset », « Réessayer ce verset ».
4. Sauvegarde dans `RecitationProgressStore` → la carte « Récitation » affiche « 3 versets à retravailler ».

---

## 3. Faisabilité détaillée — révision hebdo + quiz

### 3.1 Principe
Transposer la **méthode des Trois Fondements** : chaque notion est apprise sous forme *question → réponse → preuve (dalil)*. Trois familles de questions :
- **Mas'ala** : « Qu'est-ce que la Hanîfiyya ? »
- **Dalîl** : « Quelle est la preuve que l'invocation est une adoration ? » (réponses = versets/hadiths, le distracteur est un vrai verset hors sujet).
- **Application** : scénario vrai/faux (« Jurer par autre qu'Allah est du shirk mineur »).

### 3.2 Contenu (effort principal, éditorial)

| Domaine | Source matn | Statut dans l'app | Questions V1 |
|---|---|---|---|
| Aqidah | Thalâthat al-Usûl | track `usul3` ✅ | ~60 |
| Aqidah | Al-Qawâ'id al-Arba' | track `qawaid4` ✅ | ~20 |
| Aqidah | Nawâqid al-Islâm (10 annulatifs) | **à ajouter** (10 leçons) | ~30 |
| Aqidah | Al-Usûl as-Sitta | à ajouter (6 leçons), V2 | — |
| Fiqh | Manhaj as-Sâlikîn (as-Sa'dî) — tahâra, salât | **à ajouter** (~15 leçons) ; recoupe `WuduFiqh`, `LatecomerFiqh`, `TravelFiqh` existants | ~40 |
| Hadith | 40 Nawawî | track `nawawi40` ✅ | ~40 (V2) |

Règles de conformité éditoriale (vérifiées par un test unitaire au chargement) :
- Chaque question porte **au moins un dalil** (Coran avec référence sourate:verset, ou hadith avec recueil + numéro + grade).
- Chaque explication cite le matn ou un sharh reconnu (Ibn Bâz, Ibn 'Uthaymîn, al-Fawzân, as-Sa'dî).
- Les questions de fiqh sur un khilâf reconnu sont soit évitées, soit formulées « selon l'avis retenu dans Manhaj as-Sâlikîn ».
- **Aucun LLM à l'exécution** pour produire ou répondre à une question religieuse. Le contenu est rédigé hors ligne, relu par toi, puis figé en JSON. Un LLM peut servir d'assistant de rédaction, jamais de source.

### 3.3 Modèle de données (nouveau fichier `ilm_quiz.json`, partagé Android)

```json
{
  "version": 1,
  "topics": [
    { "id": "aqidah_usul3", "domain": "aqidah", "titleFr": "Les Trois Fondements", "titleAr": "ثلاثة الأصول", "trackId": "usul3" },
    { "id": "fiqh_taharah", "domain": "fiqh", "titleFr": "La purification", "titleAr": "الطهارة", "trackId": "manhaj_salikin" }
  ],
  "questions": [
    {
      "id": "q_usul3_009a",
      "topicId": "aqidah_usul3",
      "lessonId": "usul3_09",
      "kind": "dalil",
      "format": "mcq",
      "promptFr": "Quelle est la preuve que l'invocation (du'â') est une adoration ?",
      "promptAr": "ما الدليل على أن الدعاء عبادة؟",
      "choices": [
        { "fr": "« Votre Seigneur a dit : Invoquez-Moi, Je vous répondrai » (40:60)", "ar": "﴿وَقَالَ رَبُّكُمُ ادْعُونِي أَسْتَجِبْ لَكُمْ﴾" },
        { "fr": "« Et c'est en Allah que les croyants doivent placer leur confiance » (3:122)", "ar": "..." },
        { "fr": "« Accomplis la prière pour ton Seigneur et sacrifie » (108:2)", "ar": "..." },
        { "fr": "« Ils redoutent un jour dont le mal est répandu » (76:7)", "ar": "..." }
      ],
      "correctIndex": 0,
      "explanationFr": "Le verset ordonne l'invocation puis qualifie son abandon d'orgueil envers Son adoration : l'invocation est donc une adoration.",
      "dalil": [
        { "kind": "quran", "ref": "40:60" },
        { "kind": "hadith", "ref": "Tirmidhî 3371", "grading": "sahîh (al-Albânî)" }
      ],
      "scholarRef": "Sharh Thalâthat al-Usûl, Ibn 'Uthaymîn",
      "difficulty": 1
    }
  ]
}
```

`format` ∈ `mcq | trueFalse`. `kind` ∈ `masala | dalil | application`. `lessonId` optionnel mais fortement recommandé : c'est le pont avec Leitner.

### 3.4 Logique métier

```
QuizContentLoader.shared          bundle, index par id, validations DEBUG (ids uniques, ≥1 dalil, correctIndex valide)
QuizProgress (Codable, tolérant)  answers: [questionID: QuizAnswerRecord(correct, date)]
                                  weeklySessions: [weekKey("2026-W41"): WeeklySessionResult(score, total, date)]
                                  clé UserDefaults "ilm_quiz_progress"
WeeklyReviewPlanner.build(week:)  -> [QuizQuestion]  (pur, testé)
   • taille cible : 10 (préréglage 5 / 10 / 20)
   • 50 % : questions liées aux leçons dues dans IlmProgress.nextReviewAt (pont Leitner)
   • 30 % : rotation de thèmes — 1 thème aqidah + 1 thème fiqh par semaine (index = numéro de semaine mod nb thèmes)
   • 20 % : questions ratées dans les 4 dernières semaines
   • complément aléatoire déterministe (seed = weekKey) si un seau est vide
IlmViewModel (extension)          answer(question, choice) -> grade
   • juste  → rien côté Leitner (la révision flashcard reste souveraine)
   • faux   → progress.gradeReview(lessonId, .forgot) si lessonId présent
IlmWeeklyReminderScheduler        notif hebdo id "ilm_reminder_weekly", jour/heure réglables (défaut vendredi 18 h)
```

Semaine : ISO (lundi) pour rester aligné sur `weekStreak` existant dans `IlmMath`. Le `weekStreak` du quiz est calculé séparément (semaine validée = session terminée avec ≥ 70 %).

### 3.5 Vues
- `IlmTopicsView` : liste des thèmes par domaine (aqidah / fiqh / hadith), avec % de maîtrise. C'est l'endroit naturel pour « ranger des thèmes » ensuite.
- `IlmQuizView` : une question par page (`TabView` paginé comme `IlmLessonView`), 4 choix, verrouillage après réponse, révélation explication + dalil en FR/AR (ZStack superposé, toggle par opacité, règle anti-wiggle n°3), compteur `.monospacedDigit()`.
- `WeeklyReviewCard` : carte du hub, état « À faire cette semaine (10 questions, ~6 min) » / « Fait : 8/10 ».
- Fin de session : score, liste des erreurs avec lien vers la leçon correspondante (`IlmLessonRoute`).

---

## 4. Le 5ᵉ onglet

- Tag **4**, label « Apprendre » (`String(localized:)`, AR : « تعلّم »), icône `graduationcap.fill`, accent **purple** (convention déjà posée en commentaire dans `DesignSystem.swift`).
- Racine : `NavigationStack { ZStack { CosmicBackground ; ScrollView { LearnHubView } } }`, même structure que l'onglet Rappel.
- `LearnHubView` (nouvelle vue, layout uniquement) : 3 zones avec `ZoneSectionHeader` :
  1. **Récitation** → `RecitationEntryCard` (riwaya courante, versets à retravailler).
  2. **Révision de la semaine** → `WeeklyReviewCard`.
  3. **Programmes** → `IlmProgramCard` **déplacée** depuis `DailyContentView.swift:81` (pas dupliquée ; le Coran/khatma reste dans Rappel).
- Modifications ciblées :
  - `MainView.swift` `tabColor` : `case 4: return .purple`.
  - `MainView.swift:726` et `:817` : deep-link Ilm → `selectedTab = 4`.
  - `NotificationDeepLink` : nouvelle route `weeklyQuiz` et `recitation` (même mécanique : flag + 30 s d'expiration).
  - Textes figés à mettre à jour si on ajoute des tracks : `IlmTrackerView.swift:87, :299`, `IlmProgramCard.swift:78`.
- Thèmes **UI** (si c'est ce que tu entendais par « thèmes ») : `ReadingTheme` pourrait remonter dans Réglages comme préférence globale. Hors scope ici, noté seulement.

---

## 4b. Cohérence UI : Coran, hadiths et cartes Rappel alignés sur le programme d'apprentissage

Demande : que le verset et le hadith de l'onglet Rappel, le lecteur Coran, la leçon et la révision ʿIlm partagent **le même fond et la même typographie**. Audit comparatif (2026-10-12) : 17 écarts concrets, les principaux ci-dessous.

| Élément | Verset / Hadith du jour (`DailyContentView`) | Leçon ʿIlm (`IlmLessonView`) | Révision (`IlmFlashCardView`) | Lecteur Coran |
|---|---|---|---|---|
| Police arabe | `.system(22)`, interligne 10, centré | `AmiriQuran-Regular` 25, interligne 14, droite | `.system(22, .medium)`, interligne 11 | `AmiriQuran-Regular` 24, interligne 12, centré |
| Police FR | `.body .serif .italic`, sans interligne | `16 .serif`, interligne 7 | `13` sans serif | `13 .serif` |
| Surface | `glassCard(tint:)` 20 pt | pleine page `ReadingTheme.background` | `.ultraThinMaterial` + contour | `ReadingTheme.cardBackground` 14 pt |
| Fond écran | dégradé brun en dur (`MainView.swift:473`) | `ReadingTheme` uni (sépia/sombre) | `CosmicBackground` | `ReadingTheme` |
| Accent | indigo (verset), teal (hadith) | purple | purple | teal |
| Couleur texte | primaire système (non fixée) | tokens `ReadingTheme` | `.white.opacity(x)` en dur | tokens `ReadingTheme` |

### Cible : un seul « langage scripturaire »
Principe KISS : **pas de nouveau système de thème**. On étend `DesignSystem.swift` avec trois tokens et un modificateur, puis on les applique partout où du texte sacré est affiché.

```swift
// DesignSystem.swift — nouveaux tokens
enum ScriptureFont {
    static let arabicBody: CGFloat = 24          // verset, hadith, matn (lecteur, Rappel, leçon)
    static let arabicCompact: CGFloat = 22       // flashcard, cartes compactes
    static let arabicLineSpacing: CGFloat = 12
    static let translationLineSpacing: CGFloat = 6
    static func arabic(_ size: CGFloat = arabicBody) -> Font { .custom("AmiriQuran-Regular", size: size) }
    static func translation(_ size: CGFloat = 16) -> Font { .system(size: size, design: .serif) }
    static func source() -> Font { .system(size: 13, design: .serif).italic() }
}

enum ModuleAccent {           // remplace les .indigo/.teal/.purple dispersés
    static let quran: Color = .teal
    static let hadith: Color = .purple   // le hadith appartient au domaine ʿIlm
    static let ilm: Color = .purple
}

extension View {
    /// Carte de texte sacré : même surface pour Rappel, Ilm, Coran.
    func scriptureCard(accent: Color) -> some View {
        self.padding(16).glassCard(cornerRadius: CornerRadius.card, tint: accent).geometryGroup()
    }
}
```

Règles d'application :
1. **Arabe** : toujours `ScriptureFont.arabic()`, `lineSpacing(arabicLineSpacing)`, `multilineTextAlignment(.trailing)` dans les contextes de lecture (leçon, révision), `.center` uniquement pour le verset isolé (Rappel, Bismillah). Couleur : `ReadingTheme.textPrimary` quand la vue a un thème, sinon `.primary`. Plus aucun `.system(22)` pour de l'arabe scripturaire.
2. **Traduction FR** : `ScriptureFont.translation()`, interligne 6, **non italique** (l'italique reste pour la ligne de source).
3. **Source / référence** : `ScriptureFont.source()`, couleur accent du module à 0,85.
4. **Surface** : `scriptureCard(accent:)` pour verset, hadith, et les cartes de révision. Les sheets ʿIlm abandonnent `.ultraThinMaterial` écrit sur place au profit de `glassCard` / `glassCardSecondary`. Coins : `CornerRadius.card` partout, fin des 14/16/18 en dur.
5. **Fond** : le dégradé brun de l'onglet Rappel devient un token `TabBackground.rappel` (ou on bascule Rappel sur `CosmicBackground` comme Salat/Qibla et les sheets ʿIlm — à trancher, voir §6). `ReadingTheme` reste réservé aux vues **de lecture longue** (lecteur Coran, leçon), et doit aussi s'appliquer à la **révision** flashcard (aujourd'hui elle l'ignore).
6. **Bascule FR/AR** : un seul composant `LanguageToggleChip(isArabic:)` (11 pt bold rounded, `minWidth 42`, `.ultraThinMaterial`) utilisé par verset, hadith, Sunnah, flashcard. Respecte la règle anti-wiggle n°3.
7. **Icône partage** : 16 pt partout.
8. **CTA** : `primaryButtonStyle(color: ModuleAccent.ilm)` à la place des `purple.gradient` + coins 16 en dur.

### Fichiers touchés (phase 0b, avant tout nouveau développement)
- `DesignSystem.swift` : `ScriptureFont`, `ModuleAccent`, `scriptureCard`, `LanguageToggleChip`.
- `DailyContentView.swift` l.198-208 (verset), l.275-285 (hadith), l.176-181 et l.256-261 (toggles), l.227 et l.314 (surfaces).
- `IlmLessonView.swift` l.226-254 (fonts), l.236-239 (source), CTA.
- `IlmFlashCardView.swift` l.81-92 (fonts), l.99-104 (surface), appliquer `ReadingTheme`.
- `IlmTrackerView.swift` : surfaces l.204, 228, 261, 287, 369 → `glassCardSecondary`.
- `QuranChapterDetailView.swift` l.517, 553, 573 : passer par `ScriptureFont` (valeurs inchangées, c'est juste la source de vérité qui bouge).
- `QuranKhatmaCard.swift:136,191`, `IlmProgramCard.swift:91,153` : `cornerRadius: 18` → `CornerRadius.card`.
- `RamadanDuaCardView`, `WuduFiqhView`, `LatecomerFiqhView` : mêmes tokens (déjà en AmiriQuran, tailles 19-22 à ramener à `arabicCompact`).
- `MainView.swift:473` : fond Rappel → token.

Effort : 1 j. Validation : `RenderPreview` sur les 6 vues, Dynamic Type (AmiriQuran ne scale pas via text styles : utiliser `@ScaledMetric` sur les tailles), VoiceOver inchangé.

Ce chantier est **préalable** au 5ᵉ onglet : les nouvelles vues (hub, quiz, résultat de récitation) naissent directement avec ces tokens.

---

## 5. Plan d'implémentation

| Phase | Contenu | Fichiers | Effort | Validation |
|---|---|---|---|---|
| **0b — Cohérence UI** (§4b) | Tokens `ScriptureFont`, `ModuleAccent`, `scriptureCard`, `LanguageToggleChip` ; application sur verset/hadith Rappel, leçon, révision, lecteur Coran, Tracker | `DesignSystem.swift`, `DailyContentView.swift`, `IlmLessonView.swift`, `IlmFlashCardView.swift`, `IlmTrackerView.swift`, `QuranChapterDetailView.swift`, cartes programmes | 1 j | `RenderPreview` × 6, Dynamic Type via `@ScaledMetric`, anti-wiggle toggle |
| **0 — Onglet** | Tab 4, `LearnHubView`, déplacement `IlmProgramCard`, deep-links, couleur | `MainView.swift`, `LearnHubView.swift` (new), `DailyContentView.swift`, `NotificationDeepLink.swift`, `DesignSystem.swift` (accent nommé `ilmAccent`), `Localizable.xcstrings` | 0,5 j | Build, `RenderPreview`, test deep-link notif Ilm |
| **1 — Quiz : socle** | Modèles `QuizQuestion/QuizTopic/QuizProgress`, `QuizContentLoader`, `WeeklyReviewPlanner`, extension `IlmViewModel`, scheduler hebdo | `IlmQuiz.swift`, `QuizContentLoader.swift`, `WeeklyReviewPlanner.swift`, `IlmWeeklyReminderScheduler.swift`, tests `WeeklyReviewPlannerTests.swift`, `QuizContentValidationTests.swift` | 1,5 j | Tests Swift Testing (répartition 50/30/20, déterminisme par seed, rétrogradation Leitner) |
| **2 — Quiz : UI** | `IlmQuizView`, `IlmTopicsView`, `WeeklyReviewCard`, écran de fin | 4 vues | 1,5 j | Preview + protocole anti-wiggle |
| **3 — Contenu pack 1** | `ilm_quiz.json` : usul3 (60), qawaid4 (20), nawaqid (30) + track `nawaqid10` dans `ilm_tracks.json` ; fiqh tahâra/salât (40) + track `manhaj_salikin` | JSON + relecture par toi | 2-3 j éditorial | Test de validation du contenu ; copie vers `android/.../assets` |
| **4 — Récitation : socle** | `Riwaya`, `RecitationReferenceLoader` (Hafs depuis corpus existant, Warsh/Qaloun depuis JSON QUL), équivalences riwaya, `RecitationAligner`, `RecitationCoach` (templates), `RecitationProgressStore` | `Recitation*.swift`, `quran-warsh.json`, `quran-qaloun.json`, `riwaya_equivalences.json`, tests `RecitationAlignerTests.swift` | 2 j | Tests purs : omission, substitution, insertion, répétition, basmala, versets identiques |
| **5 — Récitation : capture** | `RecitationTranscriber` sur `SpeechAnalyzer` + `DictationTranscriber` (ar-SA, time ranges), fallback `SFSpeechRecognizer` ; audio live 16 kHz mono pour l'ASR + M4A pour la réécoute (réutilise `QuranRecorder`) | `RecitationTranscriber.swift`, ajustement `QuranRecorder` | 1,5 j | Spike device : `supportedLocales` contient ar-SA ? latence ? ; 20 essais loggés comme au spike précédent |
| **6 — Récitation : UI + conseil** | `RecitationSetupView`, `RecitationSessionView`, `RecitationResultView` (texte colorié, score, conseils), `AVSpeechSynthesizer` pour le conseil, lecture du verset par récitateur de la riwaya | 3 vues + `RecitationAudioAdvisor.swift` | 2 j | Preview, test device, VoiceOver |
| **7 — Options** | `FoundationModels` pour reformuler les conseils (si `isAvailable`), fiches de vigilance tajwid depuis script QUL tajweed | `RecitationCoachLLM.swift` (`@available`, désactivable) | 1 j | Comparaison template vs modèle sur 10 cas |
| **8 — Éval Whisper** | Spike WhisperKit + Whisper-Coran derrière le `DebugPanelSection`, 30 extraits × 3 riwayat | DEBUG only | 1 j | Décision GO/NO-GO sur WER |

Ordre conseillé : 0b → 0 → 1 → 2 → 3 (livrable « quiz hebdo » autonome) puis 4 → 5 → 6 (livrable « correcteur »). Les deux chantiers sont indépendants après la phase 0.

### Prérequis transverses
- Réécrire `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` (fr/en/ar) pour couvrir l'analyse locale de la récitation.
- Ajouter l'attribution QUL / KFGQPC dans « À propos ».
- Mettre à jour CLAUDE.md : cible iOS 26.2, et la règle « on-device only pour la voix » comme invariant projet.
- Nouvelles clés UserDefaults à inventorier : `recitation_riwaya`, `recitation_progress`, `ilm_quiz_progress`, `ilm_weekly_reminder_*`.

### Risques
| Risque | Impact | Mitigation |
|---|---|---|
| `SpeechTranscriber` sans ar-SA on-device | perte des timestamps | fallback `SFSpeechRecognizer`, alignement par verset ; Whisper en phase 8 |
| Faux positifs sur mots rares (modèle dictée) | frustration, perte de confiance | seuil « approximatif », message « je n'ai pas bien entendu », jamais de rouge sous confiance faible |
| Licence textes Warsh/Qaloun | blocage store | vérifier avant la phase 4, attribution |
| Contenu quiz erroné | gravité religieuse | relecture humaine obligatoire, dalil systématique, test de validation, pas de LLM runtime |
| Déplacement `IlmProgramCard` casse une habitude | UX | deep-link conservé, onboarding « nouveau : onglet Apprendre » via `WhatsNewView` |

---

## 6. Décisions à trancher avant de coder
1. **Déplacer** `IlmProgramCard` dans le nouvel onglet (recommandé) ou la **dupliquer** dans Rappel ?
2. Confirmer la règle : **aucun appel LLM cloud** pour cette feature (ni Gemini ni Claude). Templates puis FoundationModels on-device.
3. Pack de contenu 1 : commencer par aqidah seule (usul3 + qawaid4 + nawaqid) ou inclure déjà le fiqh tahâra/salât ?
4. Jour du rappel hebdo par défaut : vendredi 18 h ?
5. Riwayat à livrer en V1 : les trois d'un coup, ou Hafs + Warsh d'abord (Qaloun n'a pas de mot-à-mot sur QUL) ?
6. Fond de l'onglet Rappel : garder le dégradé brun (tokenisé) ou passer sur `CosmicBackground` comme Salat, Qibla et les sheets ʿIlm ?
7. Accent du hadith du jour : passer de teal à purple (domaine ʿIlm), et le verset de indigo à teal (domaine Coran) ?

---

## Sources externes consultées
- Pricing audio Gemini : https://ai.google.dev/gemini-api/docs/pricing
- QUL scripts Warsh / Qaloon : https://qul.tarteel.ai/resources/quran-script et https://qul.tarteel.ai/docs/quran-text
- Whisper-Coran : https://huggingface.co/tarteel-ai/whisper-base-ar-quran
- Conversions CoreML tierces : https://github.com/yalabdullmohsen/SSUNNAH/releases/tag/whisper-quran-coreml-v2-q6 , https://github.com/Azzam-Alrashed/Aqra/pull/2
- Apple : `SpeechAnalyzer`, `SpeechTranscriber.supportedLocales`, `SystemLanguageModel.availability` (DocumentationSearch Xcode)
