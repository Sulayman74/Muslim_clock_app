//
//  ProphetSunnahCard.swift
//  Muslim Clock
//
//  Carte affichant ce que le Prophète ﷺ aimait réciter pour la prière contextuelle
//  (obligatoire + Rawatib associée), avec overrides Vendredi / Ramadan / 10 jours
//  de Dhul-Hijjah.
//
//  Sources documentées : Sahih Bukhari, Sahih Muslim, Abu Dawud, Tirmidhi,
//  An-Nasa'i, Ibn Majah, Musnad Ahmad.
//

import SwiftUI

// MARK: - Modèle

struct ProphetSunnah {
    /// Titre court pour l'en-tête de la card.
    let title: String
    /// SF Symbol associé.
    let icon: String
    /// Couleur d'accent (utilisée pour le tint glass + l'icône).
    let accentColor: Color
    /// Texte principal en français.
    let mainText: String
    /// Texte arabe optionnel (référence Quran/Hadith).
    let arabicText: String?
    /// Recommandation Sunnah/Rawatib associée à la prière (optionnel).
    let sunnahRecommendation: String?
    /// Liste des sources (Bukhari, Muslim, etc.).
    let sources: [String]
}

// MARK: - Provider

/// Logique de sélection contextuelle.
///
/// Priorité descendante :
/// 1. Vendredi + Ramadan (combo)
/// 2. Ramadan (général)
/// 3. 10 premiers jours de Dhul-Hijjah
/// 4. Vendredi (Jumu'ah ou autre prière vendredi)
/// 5. Recommandation par prière (Fajr/Dhuhr/Asr/Maghrib/Isha)
enum ProphetSunnahProvider {

    /// Retourne la Sunnah à afficher pour le contexte courant.
    /// `prayerName` = "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Jumu'ah".
    static func current(
        prayerName: String,
        season: IslamicSeasonInfo,
        isFriday: Bool
    ) -> ProphetSunnah {

        // 1. Ramadan + Vendredi → combo prioritaire
        if season.seasonKey == "ramadan" && isFriday {
            return ProphetSunnah(
                title: String(localized: "Vendredi en Ramadan"),
                icon: "moon.stars.fill",
                accentColor: Color(red: 0.95, green: 0.75, blue: 0.25),
                mainText: String(localized: "Combinez la baraka : récitez **Al-Kahf** dans la journée, multipliez les **Salawat** sur le Prophète ﷺ, et préparez votre cœur pour **Tarawih** ce soir."),
                arabicText: "« أَكْثِرُوا عَلَيَّ مِنَ الصَّلَاةِ يَوْمَ الْجُمُعَةِ »",
                sunnahRecommendation: String(localized: "Tarawih après Isha — récitation longue, multipliez les rak'at selon votre énergie."),
                sources: ["Abu Dawud 1047", "Sahih Muslim 854"]
            )
        }

        // 2. Ramadan général
        if season.seasonKey == "ramadan" {
            return ProphetSunnah(
                title: String(localized: "Ramadan Mubarak"),
                icon: "moon.fill",
                accentColor: Color(red: 0.95, green: 0.75, blue: 0.25),
                mainText: String(localized: "Préparez le **Suhur** (béni, ne le manquez pas), rompez vite après Maghrib avec une **datte** et de l'**eau**, et prolongez la nuit en **Tarawih**. Les 10 dernières nuits : cherchez **Laylat al-Qadr**."),
                arabicText: "« إِنَّا أَنْزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ »",
                sunnahRecommendation: String(localized: "Du'a Iftar : « ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ » — La soif est partie, les veines sont humectées, la récompense est acquise, in chā Allah."),
                sources: ["Sahih Bukhari 1923 (Suhur)", "Abu Dawud 2357 (Iftar)", "Sourate 97 (Al-Qadr)"]
            )
        }

        // 3. Aïd al-Adha + jours de Tashreeq (10-13 Dhul-Hijjah)
        if season.hijriMonth == 12 && (10...13).contains(season.hijriDay) {
            return ProphetSunnah(
                title: String(localized: "Aïd al-Adha & Tashreeq"),
                icon: "star.fill",
                accentColor: Color(red: 0.1, green: 0.55, blue: 0.35),
                mainText: String(localized: "Jours de réjouissance et de **Dhikr**. Multipliez le **Takbir** à voix haute, partagez le sacrifice avec famille, voisins et pauvres. Les 3 jours de **Tashreeq** (11-13) sont des jours de manger, de boire et d'évoquer Allah."),
                arabicText: "« اللهُ أَكْبَرُ، اللهُ أَكْبَرُ، لاَ إِلَهَ إِلاَّ اللهُ، وَاللهُ أَكْبَرُ، اللهُ أَكْبَرُ، وَلِلَّهِ الْحَمْدُ »",
                sunnahRecommendation: String(localized: "Takbir muqayyad à voix haute après chaque prière obligatoire, du Fajr du 9 jusqu'à Asr du 13."),
                sources: ["Sahih Bukhari 969", "Sahih Muslim 1141 (Tashreeq)"]
            )
        }

        // 4. 10 premiers jours de Dhul-Hijjah (1-9, avec Arafah le 9)
        if season.hijriMonth == 12 && season.hijriDay <= 9 {
            return ProphetSunnah(
                title: String(localized: "10 jours bénis de Dhul-Hijjah"),
                icon: "building.columns.fill",
                accentColor: Color(red: 0.1, green: 0.55, blue: 0.35),
                mainText: String(localized: "Multipliez le **Takbir, Tahlil et Tahmid**. Jeûnez le **9 (Arafah)** : il efface les péchés de l'année passée et de l'année à venir. Les meilleures œuvres sont en ces jours."),
                arabicText: "« اللهُ أَكْبَرُ، اللهُ أَكْبَرُ، لاَ إِلَهَ إِلاَّ اللهُ، وَاللهُ أَكْبَرُ، اللهُ أَكْبَرُ، وَلِلَّهِ الْحَمْدُ »",
                sunnahRecommendation: String(localized: "Takbir d'Arafah à dire à voix haute du Fajr du 9 au Asr du 13 Dhul-Hijjah."),
                sources: ["Sahih Bukhari 969", "Sahih Muslim 1162 (jeûne d'Arafah)"]
            )
        }
        // Jour 14+ de Dhul-Hijjah → tombe dans la logique par-prière (default switch)

        // 4. Vendredi (général)
        if isFriday {
            return ProphetSunnah(
                title: String(localized: "Vendredi — Jour béni"),
                icon: "building.columns.fill",
                accentColor: .orange,
                mainText: String(localized: "Récitez **Sourate Al-Kahf** durant la journée — une lumière entre les deux vendredis. À Jumu'ah, le Prophète ﷺ aimait réciter **Al-A'la (87)** puis **Al-Ghashiyah (88)**, ou parfois **Al-Jumu'ah (62)** + **Al-Munafiqun (63)**. Multipliez les **Salawat**."),
                arabicText: "« مَنْ قَرَأَ سُورَةَ الْكَهْفِ فِي يَوْمِ الْجُمُعَةِ أَضَاءَ لَهُ مِنَ النُّورِ مَا بَيْنَ الْجُمُعَتَيْنِ »",
                sunnahRecommendation: String(localized: "Heure d'exaucement : la dernière heure avant Maghrib, ne pas négliger l'invocation."),
                sources: ["An-Nasa'i (Sahih)", "Sahih Muslim 878", "Sahih Muslim 877"]
            )
        }

        // 5. Recommandation par prière (général)
        switch prayerName.lowercased() {
        case "fajr":
            return ProphetSunnah(
                title: String(localized: "Sunnah du Fajr"),
                icon: "sun.and.horizon.fill",
                accentColor: Color(red: 1.0, green: 0.75, blue: 0.2),
                mainText: String(localized: "Le Prophète ﷺ allongeait Fajr. Il récitait souvent **Qaf (50)**, **At-Tur (52)**, **At-Takwir (81)** ou similaires du Mufassal long. **2 rak'at avant Fajr** sont plus précieuses que ce monde et tout ce qu'il contient."),
                arabicText: "« رَكْعَتَا الْفَجْرِ خَيْرٌ مِنَ الدُّنْيَا وَمَا فِيهَا »",
                sunnahRecommendation: String(localized: "2 rak'at de Sunnah avant Fajr : Al-Kafirun (109) en 1ère, Al-Ikhlas (112) en 2ème."),
                sources: ["Sahih Muslim 725", "Sahih Muslim 726 (recitations Sunnah)"]
            )

        case "dhuhr":
            return ProphetSunnah(
                title: String(localized: "Sunnah du Dhuhr"),
                icon: "sun.max.fill",
                accentColor: .yellow,
                mainText: String(localized: "Le Prophète ﷺ récitait dans Dhuhr des sourates du **Mufassal moyen** (~30-40 versets). Il aimait les rallonger en 1ère rak'a."),
                arabicText: nil,
                sunnahRecommendation: String(localized: "**4 rak'at avant** Dhuhr (très méritoires, le Prophète ﷺ ne les délaissait pas) + **2 rak'at après**."),
                sources: ["Sahih Muslim 728", "Tirmidhi 428"]
            )

        case "jumu'ah", "jumuah":
            return ProphetSunnah(
                title: String(localized: "Sunnah de Jumu'ah"),
                icon: "building.columns.fill",
                accentColor: .orange,
                mainText: String(localized: "À Jumu'ah, le Prophète ﷺ récitait **Al-A'la (87)** puis **Al-Ghashiyah (88)**, ou parfois **Al-Jumu'ah (62)** + **Al-Munafiqun (63)**."),
                arabicText: "« سَبِّحِ اسْمَ رَبِّكَ الْأَعْلَى ﴿﴾ هَلْ أَتَاكَ حَدِيثُ الْغَاشِيَةِ »",
                sunnahRecommendation: String(localized: "Lire Al-Kahf dans la journée + multiplier les Salawat sur le Prophète ﷺ."),
                sources: ["Sahih Muslim 877", "Sahih Muslim 878"]
            )

        case "asr":
            return ProphetSunnah(
                title: String(localized: "Sunnah de l'Asr"),
                icon: "sun.dust.fill",
                accentColor: .cyan,
                mainText: String(localized: "Le Prophète ﷺ récitait à l'Asr environ la **moitié** de ce qu'il récitait à Dhuhr. Asr est la **prière médiane** — particulièrement préservée."),
                arabicText: "« حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلَاةِ الْوُسْطَى »",
                sunnahRecommendation: String(localized: "4 rak'at avant Asr (Sunnah ghayr muakkadah) : « Qu'Allah fasse miséricorde à celui qui les prie »."),
                sources: ["Sahih Muslim 452", "Coran 2:238", "Abu Dawud 1271"]
            )

        case "maghrib":
            return ProphetSunnah(
                title: String(localized: "Sunnah du Maghrib"),
                icon: "sunset.fill",
                accentColor: Color(red: 0.85, green: 0.4, blue: 0.2),
                mainText: String(localized: "Maghrib se récitait avec le **Mufassal court** : **At-Tin (95)**, **Ad-Dhariyat (51)**, **At-Tur (52)**, **Al-Mursalat (77)** sont rapportées. Parfois plus court (At-Tin), parfois plus long (At-Tur)."),
                arabicText: nil,
                sunnahRecommendation: String(localized: "**2 rak'at après Maghrib** (Sunnah muakkadah) : Al-Kafirun (109) + Al-Ikhlas (112), comme dans la Sunnah avant Fajr."),
                sources: ["Sahih Bukhari 763", "Sahih Muslim 463", "Tirmidhi 431"]
            )

        case "isha":
            return ProphetSunnah(
                title: String(localized: "Sunnah de l'Isha"),
                icon: "moon.stars.fill",
                accentColor: .indigo,
                mainText: String(localized: "Le Prophète ﷺ récitait à Isha le **Mufassal moyen** : **Al-Inshiqaq (84)**, **As-Shams (91)**, **Al-Layl (92)**. Il a réprouvé Mu'adh quand il a rallongé trop."),
                arabicText: "« اقْرَأْ بِسَبِّحِ اسْمَ رَبِّكَ، وَالشَّمْسِ وَضُحَاهَا، وَاللَّيْلِ إِذَا يَغْشَى »",
                sunnahRecommendation: String(localized: "**2 rak'at après Isha** + clôturez la nuit par le **Witr** : Al-A'la (87), Al-Kafirun (109), Al-Ikhlas (112) — ou ajoutez Al-Falaq + An-Nas en 3ème rak'a."),
                sources: ["Sahih Bukhari 705", "Abu Dawud 1422 (Witr)"]
            )

        default:
            return ProphetSunnah(
                title: String(localized: "Sunnah du Prophète ﷺ"),
                icon: "sparkles",
                accentColor: .orange,
                mainText: String(localized: "Le Prophète ﷺ disait : « Priez comme vous m'avez vu prier. » Soyez assidu, calmes et concentrés dans chaque rak'a."),
                arabicText: "« صَلُّوا كَمَا رَأَيْتُمُونِي أُصَلِّي »",
                sunnahRecommendation: nil,
                sources: ["Sahih Bukhari 631"]
            )
        }
    }
}

// MARK: - Vue

struct ProphetSunnahCardView: View {
    let sunnah: ProphetSunnah

    @State private var showArabic: Bool = false
    /// Carte d'enrichissement repliée par défaut pour alléger la densité de
    /// l'écran Salat. L'utilisateur déplie au tap sur l'en-tête.
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête cliquable (repli / dépli)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(sunnah.accentColor.opacity(0.18))
                            .frame(width: 38, height: 38)
                        Image(systemName: sunnah.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(sunnah.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(sunnah.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(sunnah.accentColor)
                        Text("Ce que le Prophète ﷺ aimait")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                // Toggle FR/AR si arabe disponible
                if sunnah.arabicText != nil {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showArabic.toggle() }
                        } label: {
                            Text(verbatim: showArabic ? "FR" : "عربي")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .glassEffect(.clear, in: Capsule())
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .sensoryFeedback(.selection, trigger: showArabic)
                    }
                }

                // Corps : texte FR ou AR
                Group {
                    if showArabic, let arabic = sunnah.arabicText {
                        Text(verbatim: arabic)
                            .font(.system(size: 17, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                            .lineSpacing(6)
                    } else {
                        // mainText supporte le markdown **bold**
                        Text(.init(sunnah.mainText))
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showArabic)

                // Recommandation Sunnah/Rawatib (encart bouton-like)
                if let recommendation = sunnah.sunnahRecommendation {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(sunnah.accentColor.opacity(0.85))
                            .padding(.top, 2)
                        Text(.init(recommendation))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(sunnah.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Sources
                if !sunnah.sources.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 9))
                        Text(verbatim: sunnah.sources.joined(separator: " · "))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(16)
        .glassCard(tint: sunnah.accentColor)
    }
}
