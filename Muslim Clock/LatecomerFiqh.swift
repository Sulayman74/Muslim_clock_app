//
//  LatecomerFiqh.swift
//  Muslim Clock — Compléter la prière en arrivant en retard (masbûq) + prière mortuaire
//
//  Contenu de RÉFÉRENCE, statique et authentifié, selon la position retenue par
//  Ibn Bâz, Ibn ʿUthaymîn et la Lajna ad-Dâ'ima : ce que le retardataire prie
//  avec l'imam est le DÉBUT de sa prière (d'après « فأتموا » — al-Bukhârî 636),
//  il complète la fin après le salâm de l'imam.
//
//  ⚠️ Cadrage : rappel pédagogique avec ses dalils — PAS une fatwa personnelle.
//  En cas de situation particulière, consulter un savant.
//
//  Codé en dur (KISS, comme TravelFiqh) : contenu figé et vérifié → pas de JSON.
//

import Foundation

// MARK: - Modèles de contenu

/// Une preuve textuelle : texte arabe + traduction + référence.
struct LatecomerDalil: Identifiable {
    let id = UUID()
    let arabic: String
    let translation: String
    let reference: String
}

/// Une rubrique de la fiche (règle générale, comment rejoindre l'imam…).
struct LatecomerSection: Identifiable {
    let id: String
    let icon: String
    let title: String
    let summary: String
    let dalils: [LatecomerDalil]
    let scholarNote: String
}

/// Un exemple concret pour une prière donnée.
struct LatecomerExample: Identifiable {
    let id: String
    let prayer: String
    let icon: String
    /// Situation d'arrivée (ex. « Tu arrives pendant la 3ᵉ rakʿa »).
    let scenario: String
    /// Ce qui est rattrapé avec l'imam.
    let caught: String
    /// Ce qu'il reste à faire après le salâm de l'imam.
    let toComplete: String
}

/// Une étape de la prière mortuaire (janâza).
struct JanazaStep: Identifiable {
    let id: Int
    let title: String
    let detail: String
    /// Invocation arabe associée, si applicable.
    let arabic: String?
    let reference: String?
}

// MARK: - Contenu

enum LatecomerFiqhContent {

    // ── Rubriques : la règle, puis comment rejoindre ──

    static let sections: [LatecomerSection] = [

        LatecomerSection(
            id: "rule",
            icon: "arrow.triangle.merge",
            title: "La règle : ce que tu rattrapes est le début de ta prière",
            summary: "Viens avec calme, prie ce que tu rattrapes avec l'imam, puis complète le reste après son salâm.",
            dalils: [
                LatecomerDalil(
                    arabic: "إِذَا سَمِعْتُمُ الإِقَامَةَ فَامْشُوا إِلَى الصَّلاَةِ، وَعَلَيْكُمْ بِالسَّكِينَةِ وَالْوَقَارِ، وَلاَ تُسْرِعُوا، فَمَا أَدْرَكْتُمْ فَصَلُّوا، وَمَا فَاتَكُمْ فَأَتِمُّوا",
                    translation: "Quand vous entendez l'iqâma, marchez vers la prière avec sérénité et dignité, ne vous précipitez pas : ce que vous rattrapez, priez-le ; et ce qui vous a échappé, complétez-le.",
                    reference: "al-Bukhârî 636 / Muslim 602 — Abû Hurayra"
                )
            ],
            scholarNote: "D'après « فأتمّوا » (« complétez »), ce que le retardataire prie avec l'imam est le début de sa prière, et ce qu'il complète ensuite en est la fin — position d'Ibn Bâz (fatwas 4171, 17090), d'Ibn ʿUthaymîn et de la Lajna ad-Dâ'ima (l'avis inverse est notamment celui du madhhab hanbalite tardif). Pour la récitation : la sourate après la Fâtiha se récite dans les rakʿas priées AVEC l'imam ; dans celles complétées après son salâm, on se limite à la Fâtiha quand elles correspondent aux 3ᵉ/4ᵉ. Exception : si la rakʿa complétée est ta 2ᵉ (Fajr, ou Maghrib/Isha avec une seule rakʿa rattrapée), tu y récites Fâtiha + sourate — à voix haute si la prière est à voix haute (Ibn Bâz, fatwa 15633)."
        ),

        LatecomerSection(
            id: "join",
            icon: "figure.walk.arrival",
            title: "Rejoindre l'imam, rattraper la rakʿa",
            summary: "Takbîr d'entrée debout, puis rejoins l'imam dans sa posture — quelle qu'elle soit. La rakʿa est rattrapée si tu rattrapes le rukûʿ.",
            dalils: [
                LatecomerDalil(
                    arabic: "إِذَا جِئْتُمْ إِلَى الصَّلَاةِ وَنَحْنُ سُجُودٌ فَاسْجُدُوا وَلَا تَعُدُّوهَا شَيْئًا، وَمَنْ أَدْرَكَ الرَّكْعَةَ فَقَدْ أَدْرَكَ الصَّلَاةَ",
                    translation: "Si vous arrivez à la prière alors que nous sommes prosternés, prosternez-vous et ne comptez pas cela ; et qui rattrape la rakʿa a rattrapé la prière.",
                    reference: "Abû Dâwûd 893 — jugé hasan par al-Albânî ; la seconde partie est confirmée par al-Bukhârî 580 / Muslim 607"
                ),
                LatecomerDalil(
                    arabic: "زَادَكَ اللَّهُ حِرْصًا وَلَا تَعُدْ",
                    translation: "Qu'Allah augmente ton zèle — mais ne recommence pas (Abû Bakra avait couru et fait le rukûʿ avant d'atteindre le rang).",
                    reference: "al-Bukhârî 783 — Abû Bakra"
                )
            ],
            scholarNote: "Qui rattrape le rukûʿ avec l'imam a rattrapé la rakʿa — la Fâtiha tombe alors pour le retardataire (Ibn Bâz fatwa 20591, Ibn ʿUthaymîn, Lajna ad-Dâ'ima fatwa n° 16765). Entre toujours par la takbîrat al-ihrâm DEBOUT — obligatoire selon les quatre écoles — puis rejoins l'imam dans sa position sans attendre qu'il se relève."
        ),
    ]

    // ── Exemples concrets — les 5 prières ──
    // Convention : ce qui est rattrapé = début de ta prière (cf. rubrique « règle »).

    static let examples: [LatecomerExample] = [
        LatecomerExample(
            id: "fajr", prayer: "Fajr", icon: "sunrise.fill",
            scenario: "Tu arrives pendant la 2ᵉ rakʿa (2 rakʿas au total).",
            caught: "1 rakʿa rattrapée — c'est ta 1ʳᵉ.",
            toComplete: "Après le salâm de l'imam : lève-toi, prie 1 rakʿa (Fâtiha + sourate, à voix haute), tashahhud, salâm."
        ),
        LatecomerExample(
            id: "dhuhr", prayer: "Dhuhr", icon: "sun.max.fill",
            scenario: "Tu arrives pendant la 3ᵉ rakʿa (4 rakʿas au total).",
            caught: "2 rakʿas rattrapées — tes 1ʳᵉ et 2ᵉ.",
            toComplete: "Complète 2 rakʿas (tes 3ᵉ et 4ᵉ, Fâtiha seule), tashahhud final, salâm."
        ),
        LatecomerExample(
            id: "asr", prayer: "Asr", icon: "sun.dust.fill",
            scenario: "Tu arrives quand l'imam est déjà au tashahhud final.",
            caught: "Aucune rakʿa rattrapée — entre quand même avec lui.",
            toComplete: "Après son salâm : lève-toi et prie tes 4 rakʿas complètes, comme d'habitude."
        ),
        LatecomerExample(
            id: "maghrib", prayer: "Maghrib", icon: "sunset.fill",
            scenario: "Tu arrives pendant la 3ᵉ rakʿa (3 rakʿas au total).",
            caught: "1 rakʿa rattrapée — c'est ta 1ʳᵉ.",
            toComplete: "Complète 2 rakʿas : prie ta 2ᵉ (Fâtiha + sourate, à voix haute) puis assieds-toi pour le tashahhud intermédiaire, lève-toi pour ta 3ᵉ (Fâtiha seule), tashahhud final, salâm."
        ),
        LatecomerExample(
            id: "isha", prayer: "Isha", icon: "moon.stars.fill",
            scenario: "Tu arrives pendant la 4ᵉ rakʿa (4 rakʿas au total).",
            caught: "1 rakʿa rattrapée — c'est ta 1ʳᵉ.",
            toComplete: "Complète 3 rakʿas : ta 2ᵉ (Fâtiha + sourate, à voix haute) puis tashahhud intermédiaire, puis tes 3ᵉ et 4ᵉ (Fâtiha seule, à voix basse), tashahhud final, salâm."
        ),
    ]

    // ── Prière mortuaire (janâza) ──

    static let janazaIntro = "La prière mortuaire se fait entièrement debout : quatre takbîrs, sans rukûʿ ni sujûd, puis le salâm."

    static let janazaMerit = LatecomerDalil(
        arabic: "مَنْ شَهِدَ الْجَنَازَةَ حَتَّى يُصَلَّى عَلَيْهَا فَلَهُ قِيرَاطٌ، وَمَنْ شَهِدَهَا حَتَّى تُدْفَنَ فَلَهُ قِيرَاطَانِ",
        translation: "Qui assiste à la janâza jusqu'à la prière a un qîrât de récompense ; qui y assiste jusqu'à l'enterrement en a deux — « semblables à deux montagnes immenses ».",
        reference: "al-Bukhârî 1325 / Muslim 945 — Abû Hurayra ; « chaque qîrât comme le mont Uhud » : al-Bukhârî 47"
    )

    static let janazaSteps: [JanazaStep] = [
        JanazaStep(
            id: 1,
            title: "1ᵉʳ takbîr",
            detail: "Takbîrat al-ihrâm, puis récite al-Fâtiha (précédée du taʿawwudh, à voix basse).",
            arabic: nil,
            reference: "Ibn ʿAbbâs récita la Fâtiha sur une janâza et dit : « afin que vous sachiez que c'est la sunna » — al-Bukhârî 1335"
        ),
        JanazaStep(
            id: 2,
            title: "2ᵉ takbîr",
            detail: "Prie sur le Prophète ﷺ — la salât ibrâhîmiyya, comme dans le tashahhud.",
            arabic: nil,
            reference: nil
        ),
        JanazaStep(
            id: 3,
            title: "3ᵉ takbîr",
            detail: "Invoque sincèrement pour le défunt — c'est le cœur de cette prière.",
            arabic: "اللَّهُمَّ اغْفِرْ لِحَيِّنَا وَمَيِّتِنَا، وَشَاهِدِنَا وَغَائِبِنَا، وَصَغِيرِنَا وَكَبِيرِنَا، وَذَكَرِنَا وَأُنْثَانَا",
            reference: "at-Tirmidhî 1024 / Ibn Mâjah 1498 — authentifié par al-Albânî (chez Abû Dâwûd 3201 avec un ordre légèrement différent) ; voir aussi Muslim 963 : « اللهم اغفر له وارحمه وعافه واعف عنه… »"
        ),
        JanazaStep(
            id: 4,
            title: "4ᵉ takbîr",
            detail: "Marque une courte pause (tu peux encore invoquer), puis salue une fois sur ta droite — c'est ce qui est préservé des compagnons (Ibn Bâz) ; un second salâm est rapporté et permis (Ibn ʿUthaymîn).",
            arabic: nil,
            reference: "Ibn Bâz, fatwas 14156 et 12877 ; Ibn ʿUthaymîn, ash-Sharh al-Mumtiʿ 5/424"
        ),
    ]

    static let janazaLatecomerNote = "Le retardataire à la janâza entre par le takbîr et suit l'imam là où il en est. Après le salâm de l'imam, il complète les takbîrs manqués avec leurs invocations tant que le corps n'a pas été emporté — sinon il enchaîne les takbîrs. C'est l'application de la règle générale « ce qui vous a échappé, complétez-le » (position d'Ibn Bâz et de la Lajna ad-Dâ'ima)."
}
