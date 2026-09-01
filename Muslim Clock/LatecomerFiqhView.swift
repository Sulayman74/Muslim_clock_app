//
//  LatecomerFiqhView.swift
//  Muslim Clock — Fiche « Compléter la prière » (masbûq) + prière mortuaire
//
//  Sheet de référence affichant le contenu statique de `LatecomerFiqh.swift` :
//  règle générale, exemples pour les 5 prières, description de la janâza.
//  Layout + bindings uniquement — le contenu est data (cf. CLAUDE.md).
//

import SwiftUI

// MARK: - Fiche (sheet)

struct LatecomerFiqhView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CosmicBackground(season: IslamicSeasonInfo.current())
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {

                    // ── Header ──
                    VStack(spacing: 8) {
                        Image(systemName: "figure.walk.arrival")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("Arrivé en retard à la prière ?")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Comment compléter sa prière derrière l'imam, et la prière mortuaire — avec les preuves.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 28)

                    // ── Rubriques (règle + rejoindre) ──
                    ForEach(LatecomerFiqhContent.sections) { section in
                        sectionCard(section)
                    }

                    // ── Exemples : les 5 prières ──
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Exemples pour les 5 prières", systemImage: "list.number")
                            .font(.headline)
                            .foregroundStyle(.green)

                        ForEach(LatecomerFiqhContent.examples) { example in
                            exampleRow(example)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // ── Janâza ──
                    janazaCard

                    // ── Cadrage ──
                    Text("Rappel pédagogique avec ses preuves — pas une fatwa personnelle. Pour un cas particulier, consulte un savant.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(14)
            }
        }
    }

    // MARK: - Rubrique avec dalils

    private func sectionCard(_ section: LatecomerSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(section.title, systemImage: section.icon)
                .font(.headline)
                .foregroundStyle(.green)

            Text(verbatim: section.summary)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            ForEach(section.dalils) { dalil in
                dalilView(dalil)
            }

            Text(verbatim: section.scholarNote)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dalilView(_ dalil: LatecomerDalil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: dalil.arabic)
                .font(.custom("AmiriQuran-Regular", size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
            Text(verbatim: dalil.translation)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            Text(verbatim: dalil.reference)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green.opacity(0.9))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Exemple par prière

    private func exampleRow(_ example: LatecomerExample) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(example.prayer, systemImage: example.icon)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text(verbatim: example.scenario)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
            Text(verbatim: example.caught)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
            Text(verbatim: example.toComplete)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Janâza

    private var janazaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("La prière mortuaire (janâza)", systemImage: "hands.and.sparkles.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            Text(verbatim: LatecomerFiqhContent.janazaIntro)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)

            dalilView(LatecomerFiqhContent.janazaMerit)

            ForEach(LatecomerFiqhContent.janazaSteps) { step in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(verbatim: "\(step.id)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.indigo.opacity(0.6)))
                        Text(verbatim: step.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Text(verbatim: step.detail)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                    if let arabic = step.arabic {
                        Text(verbatim: arabic)
                            .font(.custom("AmiriQuran-Regular", size: 19))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    if let reference = step.reference {
                        Text(verbatim: reference)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.indigo.opacity(0.9))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(verbatim: LatecomerFiqhContent.janazaLatecomerNote)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.indigo.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Carte d'accès (onglet Rappel)

struct LatecomerFiqhAccessCard: View {
    @State private var showFiche = false

    var body: some View {
        Button {
            showFiche = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.walk.arrival")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Arrivé en retard à la prière ?")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Compléter derrière l'imam · exemples · prière mortuaire")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(14)
            .glassCardSecondary(cornerRadius: 16, tint: .green, fallback: GlassFallback.warm)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFiche) {
            LatecomerFiqhView()
        }
    }
}

#Preview("Fiche masbûq") {
    LatecomerFiqhView()
}
