# Passation — traductions AR/EN des clés widgets / watch / complication

> Contexte : ces clés existent déjà dans `Muslim Clock/Localizable.xcstrings` (catalogue
> partagé par les 4 targets via `membershipExceptions`) mais sans traduction. Traductions
> prêtes à coller ci-dessous — à intégrer par l'agent qui travaille sur le catalogue.
> Ne PAS créer de `Localizable.xcstrings` par target : le build l'interdit
> (« Cannot have multiple Localizable.xcstrings files in same target »).

| Clé (fr) | ar | en |
|---|---|---|
| `heure` (légende Dynamic Island) | الوقت | time |
| `restant` (légende compte à rebours) | متبقٍ | remaining |
| `C'est l'heure de la prière` | حان وقت الصلاة | It's time for prayer |
| `C'est l'heure` (ligne 1 lock screen) | حان وقت | It's time |
| `de la prière` (ligne 2 lock screen) | الصلاة | for prayer |
| `Le Cycle de Lumière` | دورة النور | The Cycle of Light |
| `Suivez vos prières d'un simple coup d'œil.` | تابع صلواتك بنظرة واحدة. | Track your prayers at a glance. |
| `Prochaine Prière` | الصلاة القادمة | Next Prayer |
| `La prochaine prière en un coup d'œil.` | الصلاة القادمة في لمحة. | The next prayer at a glance. |
| `Prochaine prière sur l'écran verrouillé.` | الصلاة القادمة على شاشة القفل. | Next prayer on your Lock Screen. |
| `Salat · 5 Cercles` | الصلاة · ٥ دوائر | Salat · 5 Circles |
| `Le cycle des 5 prières sur votre cadran.` | دورة الصلوات الخمس على واجهة ساعتك. | The 5-prayer cycle on your watch face. |
| `Qibla` | القبلة | Qibla |
| `Ouvrir la boussole Qibla.` | افتح بوصلة القبلة. | Open the Qibla compass. |
| `Adhkar` | الأذكار | Adhkar |
| `Ouvrir les Adhkar (matin ou soir selon l'heure).` | افتح الأذكار (الصباح أو المساء حسب الوقت). | Open Adhkar (morning or evening depending on the time). |
| `Coran` | القرآن | Quran |
| `Ouvrir la bibliothèque des sourates.` | افتح مكتبة السور. | Open the surah library. |
| `Prières · Lune` | الصلوات · القمر | Prayers · Moon |
| `5 sphères de prière, date hijri (FR · AR) et phase lunaire du jour.` | ٥ كرات للصلاة، التاريخ الهجري وطور القمر اليوم. | 5 prayer spheres, Hijri date (FR · AR) and today's moon phase. |
| `Iftar` | الإفطار | Iftar |
| `Fin du Sohoor` | نهاية السحور | End of Suhoor |
| `Ouvrez l'app iPhone` | افتح تطبيق الآيفون | Open the iPhone app |
| `Synchronisation` | المزامنة | Syncing |
| `Muslim Clock` | *(ne pas traduire — `shouldTranslate: false`)* | — |

## Nouvelle clé à venir (pas encore dans le catalogue)

`NotificationManager.swift` utilise désormais `String(localized:)` pour le corps des
notifications d'adhan. La clé apparaîtra à la prochaine synchro Xcode du catalogue :

| Clé (fr) | ar | en |
|---|---|---|
| `C'est l'heure de la prière du %@.` | حان وقت صلاة %@. | It's time for %@ prayer. |

## Déjà traité (ne pas refaire)

- `Muslim Clock/InfoPlist.xcstrings` créé : permissions micro + localisation en fr/ar/en.
- `developmentRegion = en` vs langue source `fr` : incohérence non corrigée (décision à prendre).
