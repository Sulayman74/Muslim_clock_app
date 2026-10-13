# Données du correcteur de récitation : sources et licences

| Fichier | Riwaya | Source | Numérotation |
|---|---|---|---|
| `quran-search-corpus.json` | Hafs ʿan ʿĀṣim | existant (Tanzil, imla'i vocalisé) | koufi, 6 236 versets |
| `quran-warsh.json` | Warsh ʿan Nāfiʿ | KFGQPC, *Warsh Uthmanic Data* v10 (2021-08-05) | madani, 6 214 versets |
| `quran-qaloun.json` | Qālūn ʿan Nāfiʿ | KFGQPC, *Qaloon Uthmanic Data* v10 (2021-08-08) | madani, 6 214 versets |
| `riwaya_equivalences.json` | toutes | rédigé pour l'app, à partir d'un diff Hafs ↔ Warsh/Qaloun | — |

## Warsh / Qaloun : King Fahd Glorious Quran Printing Complex (KFGQPC)

- Éditeur : مجمع الملك فهد لطباعة المصحف الشريف, King Fahd Glorious Quran
  Printing Complex, Médine. Plateforme développeurs :
  https://qurancomplex.gov.sa/en/techquran/dev/
- Fichiers téléchargés sans authentification depuis le miroir GitHub
  https://github.com/thetruetruth/quran-data-kfgqpc (`warsh/data/warshData_v10.json`,
  `qaloon/data/QaloonData_v10.json`). Le miroir n'a pas de fichier LICENSE ; il
  renvoie au KFGQPC comme source.
- Conditions : le KFGQPC diffuse ses textes pour que les développeurs les
  intègrent dans leurs applications. Les conditions publiées pour ses polices
  ("may not be reproduced, modified without the express written approval")
  et l'usage établi (QUL/Tarteel, quran-api) imposent de :
  1. **citer la source**, « Texte Warsh/Qaloun : Complexe du Roi Fahd pour
     l'impression du Noble Coran (KFGQPC) », dans Réglages > À propos (à faire
     en phase 6 avec l'UI) ;
  2. **ne pas altérer le texte coranique.**
- ⚠️ À confirmer avant la mise en production : la page des conditions du
  KFGQPC n'était pas joignable au moment de l'intégration (connexion refusée).
  Si un accord écrit est requis, on peut retirer les deux fichiers sans toucher
  au code : `RecitationReferenceLoader.availableRiwayat()` ne renverra plus que
  Hafs.

### Conversions appliquées (encodage uniquement, aucun mot ajouté, retiré ou déplacé)

Conversion par un script ponctuel (non versionné), vers le schéma compact
`{s:[{c,n,e,v:[{i,t}]}]}` du corpus Hafs, verset par verset.

- Tanwin « ouverts » KFGQPC U+0656 / U+0657 / U+065E remplacés par leurs points
  de code Unicode standard U+08F2 / U+08F0 / U+08F1 (même conversion que
  fawazahmed0/quran-api et que le lecteur uthmani de l'app).
- Ya final non pointé maghrébin U+06D2 (ے, glyphe propre aux polices KFGQPC)
  remplacé par U+064A (ي) : sinon les polices standard l'affichent comme le yeh
  barree ourdou. Simple convention d'écriture, la lettre est la même.
- Retrait du numéro de verset final, du signe de hizb ۞ (U+06DE), des marques
  RLM (U+200F) et des espaces insécables.
- Noms de sourates (`n`, `e`) repris du corpus Hafs, pour un affichage cohérent
  entre riwayat. Les numéros de sourate sont les mêmes ; seule la numérotation
  des versets change.

## Pourquoi pas QUL (qul.tarteel.ai) ?

QUL propose les mêmes textes KFGQPC (Warsh, Qaloun verset par verset), mais le
téléchargement demande un compte. Les éditions `ara-quranwarsh` /
`ara-quranqaloon` de fawazahmed0/quran-api ont été renumérotées en koufi
(6 236 versets), alors que le correcteur travaille dans la numérotation propre
de la riwaya (madani, 6 214).
