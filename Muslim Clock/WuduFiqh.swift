//
//  WuduFiqh.swift
//  Muslim Clock — Les ablutions (wudû') pas à pas + ghusl et bienséances du vendredi
//
//  Contenu de RÉFÉRENCE, statique et authentifié — même méthodologie que
//  LatecomerFiqh/TravelFiqh : chaque point appuyé par ses dalils (arabe +
//  traduction + référence précise), divergences savantes signalées sobrement.
//
//  ⚠️ Cadrage : rappel pédagogique avec ses preuves — PAS une fatwa personnelle.
//  En cas de situation particulière, consulter un savant.
//
//  Codé en dur (KISS, comme les autres fiches) : contenu figé et vérifié → pas de JSON.
//

import Foundation

// MARK: - Modèles de contenu
// Dupliqués des modèles Latecomer/Travel (KISS — pas d'abstraction entre fiches).

/// Une preuve textuelle : texte arabe + traduction + référence.
struct WuduDalil: Identifiable {
    let id = UUID()
    let arabic: String
    let translation: String
    let reference: String
}

/// Une rubrique de la fiche (mérites, annulatifs…).
struct WuduSection: Identifiable {
    let id: String
    let icon: String
    let title: String
    let summary: String
    let dalils: [WuduDalil]
    let scholarNote: String
}

/// Une étape du wudû', dans l'ordre.
struct WuduStep: Identifiable {
    let id: Int
    let title: String
    let detail: String
    /// Texte arabe associé (invocation), si applicable.
    let arabic: String?
    let reference: String?
}

/// Une bienséance du vendredi.
struct FridayAdab: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let detail: String
    let reference: String?
}

// MARK: - Contenu

enum WuduFiqhContent {

    // ── Mérites de la purification ──

    static let meritSection = WuduSection(
        id: "merit",
        icon: "sparkles",
        title: "Le mérite de la purification",
        summary: "La purification est la moitié de la foi, la clé de la prière — et les péchés s'écoulent avec l'eau.",
        dalils: [
            WuduDalil(
                arabic: "الطُّهُورُ شَطْرُ الْإِيمَانِ",
                translation: "La purification est la moitié de la foi.",
                reference: "Muslim 223 — Abû Mâlik al-Ashʿarî"
            ),
            WuduDalil(
                arabic: "مِفْتَاحُ الصَّلَاةِ الطُّهُورُ",
                translation: "La clé de la prière est la purification.",
                reference: "Abû Dâwûd 61 / at-Tirmidhî 3 — jugé sahîh par al-Albânî"
            ),
            WuduDalil(
                arabic: "لَا تُقْبَلُ صَلَاةٌ بِغَيْرِ طُهُورٍ",
                translation: "Aucune prière n'est acceptée sans purification.",
                reference: "Muslim 224 — Ibn ʿUmar"
            ),
        ],
        scholarNote: "Quand le serviteur fait le wudû', ses péchés sortent de ses membres avec l'eau — jusqu'à sortir de sous ses ongles (Muslim 245). Et celui qui fait le wudû' avec excellence puis prie deux rakʿas sans que son âme ne s'y disperse, ses péchés antérieurs lui sont pardonnés (al-Bukhârî 159 / Muslim 226, hadith de ʿUthmân)."
    )

    // ── Le dalil d'ouverture : les obligations du verset ──

    static let quranicBasis = WuduDalil(
        arabic: "يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا قُمْتُمْ إِلَى الصَّلَاةِ فَاغْسِلُوا وُجُوهَكُمْ وَأَيْدِيَكُمْ إِلَى الْمَرَافِقِ وَامْسَحُوا بِرُءُوسِكُمْ وَأَرْجُلَكُمْ إِلَى الْكَعْبَيْنِ",
        translation: "Ô vous qui croyez ! Quand vous vous levez pour la prière, lavez vos visages et vos mains jusqu'aux coudes, passez les mains mouillées sur vos têtes, et lavez vos pieds jusqu'aux chevilles.",
        reference: "Coran, al-Mâ'ida 5:6 — les quatre obligations du wudû'"
    )

    // ── Le wudû' pas à pas ──
    // Modèle : la description du wudû' du Prophète ﷺ par ʿUthmân
    // (al-Bukhârî 159 / Muslim 226). Fard (verset 5:6) vs sunna distingués.

    static let steps: [WuduStep] = [
        WuduStep(
            id: 1,
            title: "L'intention (niyya)",
            detail: "Dans le cœur, sans formule à prononcer — vouloir se purifier pour la prière.",
            arabic: nil,
            reference: "« Les actes ne valent que par les intentions » — al-Bukhârî 1 / Muslim 1907"
        ),
        WuduStep(
            id: 2,
            title: "Bismillah",
            detail: "Mentionner le nom d'Allah en commençant.",
            arabic: "بِسْمِ اللَّهِ",
            reference: "Abû Dâwûd 101 — hadith renforcé par ses voies, authentifié par al-Albânî"
        ),
        WuduStep(
            id: 3,
            title: "Laver les mains — 3 fois",
            detail: "Jusqu'aux poignets, en commençant le wudû'. (Sunna)",
            arabic: nil,
            reference: nil
        ),
        WuduStep(
            id: 4,
            title: "Bouche et nez — 3 fois",
            detail: "Rincer la bouche (madmada) et aspirer puis rejeter l'eau du nez (istinshâq) — avec application, sauf en état de jeûne.",
            arabic: nil,
            reference: "« Mets de l'application dans l'istinshâq, sauf si tu jeûnes » — Abû Dâwûd 142 / at-Tirmidhî 788, sahîh"
        ),
        WuduStep(
            id: 5,
            title: "Le visage — 3 fois",
            detail: "Du haut du front au menton, d'une oreille à l'autre. (Obligation — verset 5:6)",
            arabic: nil,
            reference: nil
        ),
        WuduStep(
            id: 6,
            title: "Les bras jusqu'aux coudes — 3 fois",
            detail: "Coudes inclus, en commençant par la droite. (Obligation — verset 5:6)",
            arabic: nil,
            reference: "Le Prophète ﷺ aimait commencer par la droite dans sa purification — al-Bukhârî 168 / Muslim 268"
        ),
        WuduStep(
            id: 7,
            title: "La tête et les oreilles — 1 fois",
            detail: "Essuyer la tête d'avant en arrière puis revenir, et les oreilles avec l'eau restante (intérieur avec l'index, extérieur avec le pouce). (Obligation pour la tête — verset 5:6 ; les oreilles en font partie selon l'avis retenu)",
            arabic: nil,
            reference: nil
        ),
        WuduStep(
            id: 8,
            title: "Les pieds jusqu'aux chevilles — 3 fois",
            detail: "Chevilles incluses, sans oublier les talons, en commençant par le droit. (Obligation — verset 5:6)",
            arabic: "وَيْلٌ لِلْأَعْقَابِ مِنَ النَّارِ",
            reference: "« Malheur aux talons (négligés), pour le Feu » — al-Bukhârî 165 / Muslim 241"
        ),
    ]

    /// L'invocation après le wudû' et son mérite.
    /// Wording exact de Muslim 234 (la version longue avec « وحده لا شريك له »
    /// et l'ajout « اللهم اجعلني من التوابين… » est celle d'at-Tirmidhî 55).
    static let postWuduDua = WuduDalil(
        arabic: "أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَأَنَّ مُحَمَّدًا عَبْدُ اللَّهِ وَرَسُولُهُ",
        translation: "Qui fait le wudû' avec excellence puis prononce cette attestation, les huit portes du Paradis lui sont ouvertes : il entre par celle qu'il veut.",
        reference: "Muslim 234 — ʿUqba ibn ʿÂmir ; version longue et ajout « اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ » : at-Tirmidhî 55, jugé sahîh par al-Albânî"
    )

    // ── Ce qui annule le wudû' ──

    static let nullifiersSection = WuduSection(
        id: "nullifiers",
        icon: "arrow.uturn.backward",
        title: "Ce qui annule le wudû'",
        summary: "Tout ce qui sort des deux voies naturelles, le sommeil profond, et la perte de conscience.",
        dalils: [
            WuduDalil(
                arabic: "لَا يَنْصَرِفْ حَتَّى يَسْمَعَ صَوْتًا أَوْ يَجِدَ رِيحًا",
                translation: "Qu'il ne quitte pas (sa prière) tant qu'il n'a pas entendu un son ou senti une odeur.",
                reference: "al-Bukhârî 137 / Muslim 361 — ʿAbbâd ibn Tamîm, d'après son oncle"
            ),
        ],
        scholarNote: "En cas de doute (« ai-je perdu mon wudû' ? »), la certitude prime : tu restes en état de pureté tant que tu n'as pas de certitude du contraire — c'est l'enseignement direct de ce hadith. Le sommeil léger assis n'annule pas le wudû' selon la majorité ; le sommeil profond, si (Ibn Bâz, Ibn ʿUthaymîn)."
    )

    // ── Vendredi : le ghusl ──

    static let fridayGhuslSection = WuduSection(
        id: "friday_ghusl",
        icon: "shower.fill",
        title: "Le ghusl du vendredi",
        summary: "Se laver entièrement avant de se rendre à la prière du vendredi — une insistance prophétique particulière.",
        dalils: [
            WuduDalil(
                arabic: "غُسْلُ يَوْمِ الْجُمُعَةِ وَاجِبٌ عَلَى كُلِّ مُحْتَلِمٍ",
                translation: "Le ghusl du jour du vendredi incombe à toute personne pubère.",
                reference: "al-Bukhârî 879 / Muslim 846 — Abû Saʿîd al-Khudrî"
            ),
            WuduDalil(
                arabic: "مَنْ تَوَضَّأَ يَوْمَ الْجُمُعَةِ فَبِهَا وَنِعْمَتْ، وَمَنِ اغْتَسَلَ فَالْغُسْلُ أَفْضَلُ",
                translation: "Qui fait le wudû' le vendredi, c'est bien ; et qui fait le ghusl, le ghusl est meilleur.",
                reference: "Abû Dâwûd 354 / at-Tirmidhî 497 — hasan selon at-Tirmidhî, jugé sahîh par al-Albânî"
            ),
        ],
        scholarNote: "Les savants divergent : sunna fortement appuyée d'après le second hadith — position de la majorité et d'Ibn Bâz — tandis qu'Ibn ʿUthaymîn penche pour l'obligation du ghusl pour qui se rend à la prière du vendredi. Dans tous les cas, le ghusl reste la voie la plus sûre et la plus méritoire."
    )

    // ── Vendredi : les bienséances ──

    static let fridayAdab: [FridayAdab] = [
        FridayAdab(
            id: 1,
            icon: "shower.fill",
            title: "Le ghusl",
            detail: "Se laver entièrement, comme pour la grande purification.",
            reference: "al-Bukhârî 879 / Muslim 846"
        ),
        FridayAdab(
            id: 2,
            icon: "tshirt.fill",
            title: "Beaux habits, parfum et siwâk",
            detail: "Se purifier autant que possible, s'huiler ou se parfumer, porter ses beaux habits.",
            reference: "al-Bukhârî 883 / Muslim 846 (siwâk, parfum) / Abû Dâwûd 343 (beaux habits) — Salmân al-Fârisî et Abû Saʿîd"
        ),
        FridayAdab(
            id: 3,
            icon: "figure.walk",
            title: "Partir tôt",
            detail: "Plus on vient tôt, plus la récompense est grande — comme l'offrande d'un chameau, puis d'une vache, puis d'un bélier…",
            reference: "al-Bukhârî 881 / Muslim 850 — Abû Hurayra"
        ),
        FridayAdab(
            id: 4,
            icon: "ear.fill",
            title: "Écouter la khutba en silence",
            detail: "Ne pas parler pendant le sermon — même dire « tais-toi » à son voisin fait perdre la récompense.",
            reference: "al-Bukhârî 934 / Muslim 851"
        ),
        FridayAdab(
            id: 5,
            icon: "book.fill",
            title: "Lire la sourate al-Kahf",
            detail: "Une lumière entre les deux vendredis pour qui la lit ce jour-là.",
            reference: "al-Hâkim / al-Bayhaqî — jugé sahîh par al-Albânî (Sahîh al-Jâmiʿ 6470)"
        ),
        FridayAdab(
            id: 6,
            icon: "hands.sparkles.fill",
            title: "Multiplier les salawât",
            detail: "« Multipliez la prière sur moi le jour du vendredi, car vos prières me sont présentées. »",
            reference: "Abû Dâwûd 1047 — Aws ibn Aws, jugé sahîh par al-Albânî"
        ),
        FridayAdab(
            id: 7,
            icon: "hands.and.sparkles.fill",
            title: "Chercher l'heure d'exaucement",
            detail: "Il y a le vendredi une heure où le serviteur en prière n'invoque rien sans l'obtenir — beaucoup de savants la situent en fin d'après-midi.",
            reference: "al-Bukhârî 935 / Muslim 852 — Abû Hurayra"
        ),
    ]

    // ── Cadrage ──

    static let disclaimer = "Rappel pédagogique avec ses preuves — pas une fatwa personnelle. Pour un cas particulier, consulte un savant."
}
