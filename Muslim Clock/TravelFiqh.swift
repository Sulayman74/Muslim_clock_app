//
//  TravelFiqh.swift
//  Muslim Clock — Mode voyage (Safar) : facilités (rukhsa) du voyageur
//
//  Contenu de RÉFÉRENCE, statique et authentifié : les facilités du voyageur
//  (raccourcir, regrouper, rompre le jeûne à rattraper), chacune accompagnée de
//  ses preuves (Coran, Sunna sahîh, parole de savant).
//
//  ⚠️ Cadrage : ce sont des *rukhsa* (facilités) avec leurs dalils — PAS des
//  obligations, et PAS une fatwa personnelle. En cas de doute, consulter un savant.
//
//  Codé en dur (KISS) : 3 rubriques figées et vérifiées → aucun JSON distant.
//  Layout + bindings uniquement dans les Views (cf. CLAUDE.md), le contenu est data.
//

import SwiftUI

// MARK: - Modèle de contenu

/// Une preuve textuelle : texte arabe + traduction + référence.
struct TravelDalil: Identifiable {
    let id = UUID()
    let arabic: String
    let translation: String
    let reference: String
}

/// Une facilité du voyageur : statut (recommandation / permission), résumé et preuves.
struct TravelRuling: Identifiable {
    let id: String
    let icon: String
    let title: String
    /// Résumé en une ligne (ex. « Ẓuhr · ʿAsr · ʿIshâ → 2 rakʿas »).
    let summary: String
    /// Statut clair : facilité recommandée, permission, etc. — jamais « obligation ».
    let status: String
    let quran: TravelDalil?
    let hadiths: [TravelDalil]
    /// Précision d'un savant / point de fiqh (attribué prudemment).
    let scholarNote: String
}

/// Les facilités du voyageur, avec leurs preuves. Ordre = pédagogique (qasr d'abord,
/// car c'est la pratique constante du Prophète ﷺ ; puis jamʿ ; puis le jeûne).
enum TravelFiqhContent {
    static let rulings: [TravelRuling] = [

        // 1 — Raccourcir (Qasr)
        TravelRuling(
            id: "qasr",
            icon: "arrow.down.right.and.arrow.up.left",
            title: "Raccourcir — Qasr",
            summary: "Ẓuhr · ʿAsr · ʿIshâ → 2 rakʿas. (Fajr et Maghrib inchangés.)",
            status: "Fortement recommandé — pratique constante du Prophète ﷺ.",
            quran: TravelDalil(
                arabic: "وَإِذَا ضَرَبْتُمْ فِي الْأَرْضِ فَلَيْسَ عَلَيْكُمْ جُنَاحٌ أَن تَقْصُرُوا مِنَ الصَّلَاةِ",
                translation: "Et quand vous parcourez la terre, ce n'est pas un péché pour vous de raccourcir la Salât.",
                reference: "Coran, an-Nisâ' (4:101)"
            ),
            hadiths: [
                TravelDalil(
                    arabic: "صَحِبْتُ رَسُولَ اللَّهِ ﷺ فَكَانَ لَا يَزِيدُ فِي السَّفَرِ عَلَى رَكْعَتَيْنِ",
                    translation: "J'ai accompagné le Messager d'Allah ﷺ : en voyage, il ne dépassait jamais deux rakʿas.",
                    reference: "al-Bukhârî 1102 / Muslim 689 — Ibn ʿUmar"
                ),
                TravelDalil(
                    arabic: "صَلَاةُ السَّفَرِ رَكْعَتَانِ، تَمَامٌ غَيْرُ قَصْرٍ، عَلَى لِسَانِ نَبِيِّكُمْ ﷺ",
                    translation: "La prière du voyage est de deux rakʿas ; c'est une prière complète, non écourtée, par la parole de votre Prophète ﷺ.",
                    reference: "Ibn Mâjah 1063 / an-Nasâ'î — ʿUmar (sahîh)"
                )
            ],
            scholarNote: "Raccourcir est la sunna constante du Prophète ﷺ tout au long de ses voyages. Les savants de la Lajna ad-Dâ'ima et Cheikh Ibn Bâz la qualifient de sunna mu'akkada : elle est préférée à la prière complète pour le voyageur."
        ),

        // 2 — Regrouper (Jamʿ)
        TravelRuling(
            id: "jam",
            icon: "square.stack.3d.up.fill",
            title: "Regrouper — Jamʿ",
            summary: "Ẓuhr + ʿAsr ensemble, et Maghrib + ʿIshâ ensemble, en cas de besoin.",
            status: "Permission (rukhsa) quand il y a un besoin — pas systématique.",
            quran: nil,
            hadiths: [
                TravelDalil(
                    arabic: "جَمَعَ رَسُولُ اللَّهِ ﷺ فِي غَزْوَةِ تَبُوكَ بَيْنَ الظُّهْرِ وَالْعَصْرِ، وَالْمَغْرِبِ وَالْعِشَاءِ",
                    translation: "Le Messager d'Allah ﷺ, lors de l'expédition de Tabûk, regroupa le Ẓuhr et le ʿAsr, ainsi que le Maghrib et le ʿIshâ.",
                    reference: "Muslim 706 — Muʿâdh ibn Jabal"
                ),
                TravelDalil(
                    arabic: "كَانَ رَسُولُ اللَّهِ ﷺ إِذَا عَجِلَ بِهِ السَّيْرُ جَمَعَ بَيْنَ الْمَغْرِبِ وَالْعِشَاءِ",
                    translation: "Quand le Messager d'Allah ﷺ était pressé par la marche, il regroupait le Maghrib et le ʿIshâ.",
                    reference: "al-Bukhârî 1107 — Ibn ʿUmar"
                )
            ],
            scholarNote: "Le regroupement est une facilité liée au besoin (déplacement, fatigue). Il se distingue du qasr : Ibn Taymiyya précise que raccourcir concerne tout voyageur, tandis que regrouper est pour celui qui en a besoin. On peut donc voyager en raccourcissant sans regrouper."
        ),

        // 3 — Le jeûne (facilité de rompre, à rattraper)
        TravelRuling(
            id: "sawm",
            icon: "moon.stars.fill",
            title: "Le jeûne — Facilité de rompre",
            summary: "Rompre le jeûne obligatoire est permis ; les jours sont à rattraper (qadâ').",
            status: "Facilité : rompre est permis (préférable si difficile) ; rattrapage obligatoire.",
            quran: TravelDalil(
                arabic: "فَمَن كَانَ مِنكُم مَّرِيضًا أَوْ عَلَىٰ سَفَرٍ فَعِدَّةٌ مِّنْ أَيَّامٍ أُخَرَ",
                translation: "Quiconque parmi vous est malade ou en voyage devra jeûner un nombre égal d'autres jours.",
                reference: "Coran, al-Baqara (2:184)"
            ),
            hadiths: [
                TravelDalil(
                    arabic: "هِيَ رُخْصَةٌ مِنَ اللَّهِ، فَمَنْ أَخَذَ بِهَا فَحَسَنٌ، وَمَنْ أَحَبَّ أَنْ يَصُومَ فَلَا جُنَاحَ عَلَيْهِ",
                    translation: "C'est une facilité d'Allah : qui la prend fait bien, et qui préfère jeûner n'encourt aucun blâme.",
                    reference: "Muslim 1121 — Ḥamza al-Aslamî"
                ),
                TravelDalil(
                    arabic: "لَيْسَ مِنَ الْبِرِّ الصِّيَامُ فِي السَّفَرِ",
                    translation: "Il n'est pas de la piété de jeûner en voyage (quand cela devient une réelle difficulté).",
                    reference: "al-Bukhârî 1946 / Muslim 1115 — Jâbir"
                )
            ],
            scholarNote: "Les Compagnons voyageaient avec le Prophète ﷺ : certains jeûnaient, d'autres non, sans que l'un blâme l'autre (al-Bukhârî 1947). Ibn Qudâma (al-Mughnî) : si le jeûne est pénible, rompre est meilleur ; les jours manqués se rattrapent après le Ramadan."
        )
    ]

    /// Avertissement d'adab affiché en pied de la fiche.
    static let disclaimer = "Ces rappels exposent des facilités (rukhsa) avec leurs preuves — ce ne sont ni des obligations ni une fatwa. En cas de situation particulière, consulte un savant de confiance."
}

// MARK: - Carte d'accueil (compacte, ouvre la fiche)

/// Carte discrète sur l'accueil quand le mode voyage est actif : résume l'accès aux
/// facilités du voyageur et ouvre la fiche détaillée. Auto-masquée hors mode voyage.
struct TravelFiqhCard: View {
    @AppStorage(TravelKeys.active) private var travelModeActive = false
    @State private var showDetail = false

    var body: some View {
        if travelModeActive {
            Button { showDetail = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(travelModeAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Facilités du voyageur")
                            .font(.footnote.bold())
                            .foregroundColor(.white)
                        Text("Qasr · Jamʿ · Jeûne — avec les preuves")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .cardStyle()
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetail) { TravelFiqhView() }
        }
    }
}

// MARK: - Fiche détaillée

/// Fiche des facilités du voyageur : une section par règle, chacune avec son statut
/// et ses preuves (Coran, Sunna, savants), plus un avertissement d'adab en pied.
struct TravelFiqhView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(TravelFiqhContent.rulings) { ruling in
                        TravelRulingSection(ruling: ruling)
                    }

                    Text(TravelFiqhContent.disclaimer)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Facilités du voyageur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(travelModeAccent)
                }
            }
        }
    }
}

/// Rendu d'une règle : en-tête (icône + titre + résumé), badge de statut, puis les
/// preuves (verset, hadiths, note de savant).
private struct TravelRulingSection: View {
    let ruling: TravelRuling

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: ruling.icon)
                    .font(.title3)
                    .foregroundStyle(travelModeAccent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ruling.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(ruling.summary)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Text(ruling.status)
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(travelModeAccent.opacity(0.25), in: Capsule())

            if let quran = ruling.quran {
                dalilView(quran, tag: "Coran")
            }
            ForEach(ruling.hadiths) { hadith in
                dalilView(hadith, tag: "Sunna")
            }

            Text(ruling.scholarNote)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Bloc d'une preuve : texte arabe (RTL), traduction, référence.
    private func dalilView(_ dalil: TravelDalil, tag: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dalil.arabic)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            Text(dalil.translation)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Text("\(tag) — \(dalil.reference)")
                .font(.caption2)
                .foregroundColor(travelModeAccent.opacity(0.9))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.badge, style: .continuous))
    }
}

// MARK: - Previews

#Preview("Fiche voyageur") {
    TravelFiqhView()
}

#Preview("Carte") {
    ZStack {
        Color.black.ignoresSafeArea()
        TravelFiqhCard()
            .padding()
    }
}
