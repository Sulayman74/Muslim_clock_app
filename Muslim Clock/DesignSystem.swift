//
//  DesignSystem.swift
//  Muslim Clock
//
//  🎨 Guide de style iOS 18+ conforme
//

import SwiftUI

/// Accent du mode voyage (Safar) — indigo/violet « nuit du safar », distinct des
/// 4 couleurs d'onglets (rouge/orange/teal/bleu) et en harmonie avec le fond cosmique.
/// Token nommé (pas de couleur ad-hoc inline).
let travelModeAccent = Color(red: 0.44, green: 0.38, blue: 0.82)

/// Formate une durée de lecture audio en `m:ss` (ou `h:mm:ss` au-delà d'une heure).
///
/// Source unique du format de temps du lecteur (mini-player, plein écran, carte
/// « Reprendre », playlist). Robuste aux valeurs non-finies ou négatives → `0:00`.
func playbackTimeLabel(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

/// ═══════════════════════════════════════════════════════════════
/// DESIGN SYSTEM MUSLIM CLOCK
/// Conforme aux standards iOS 18+ Liquid Glass
/// ═══════════════════════════════════════════════════════════════

extension View {

    // MARK: - SURFACE UNIQUE (Liquid Glass)

    /// Surface de carte **unique** de l'app.
    ///
    /// Remplace les usages dispersés de `.regularMaterial` / `.ultraThinMaterial` /
    /// `.glassEffect(...)` inline par un seul style cohérent (Liquid Glass). Une
    /// teinte optionnelle porte l'état sémantique de la carte (voir la refonte
    /// couleur : orange = maintenant, green = à venir, indigo = nuit).
    ///
    /// - Parameters:
    ///   - cornerRadius: cran de l'échelle (`CornerRadius.card` par défaut).
    ///   - tint: teinte d'accent optionnelle, appliquée à faible opacité.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = CornerRadius.card, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if let tint {
            glassEffect(.regular.tint(tint.opacity(0.12)), in: shape)
        } else {
            glassEffect(.regular, in: shape)
        }
    }

    /// Surface **secondaire** (zone « Pour aller plus loin » de l'onglet Salat).
    ///
    /// Un cran de verre en dessous de `glassCard` : `.clear` + teinte 0.08 — la
    /// carte recule optiquement et laisse voir les étoiles. Réutilise la grammaire
    /// existante (`.regular` = contenu, `.clear` = discret). Fallback opaque quand
    /// « Réduire la transparence » est actif.
    func glassCardSecondary(cornerRadius: CGFloat = CornerRadius.card, tint: Color? = nil) -> some View {
        modifier(GlassCardSecondary(cornerRadius: cornerRadius, tint: tint))
    }

    // MARK: - CARDS (20pt corner radius)

    /// Carte standard (widgets, contenu principal)
    func cardStyle() -> some View {
        self
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
    
    /// Carte premium (avec bordure lumineuse)
    func premiumCardStyle(borderColor: Color = .orange) -> some View {
        self
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [borderColor, borderColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: borderColor.opacity(0.15), radius: 12, y: 6)
    }
    
    // MARK: - BUTTONS
    
    /// Bouton principal (16pt)
    func primaryButtonStyle(color: Color = .orange) -> some View {
        self
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color.gradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
    
    /// Bouton secondaire (12pt)
    func secondaryButtonStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    /// Bouton petit (10pt)
    func tertiaryButtonStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - SPECIAL SHAPES
    
    /// Mini chip (8pt)
    func chipStyle(color: Color = .orange) -> some View {
        self
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
    }
}

/// Implémentation de `glassCardSecondary` — ViewModifier pour accéder à
/// l'environnement d'accessibilité (fond plein si Réduire la transparence).
struct GlassCardSecondary: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            // Fond opaque harmonisé avec le mesh cosmique « default ».
            content.background(
                shape.fill(Color(red: 0.07, green: 0.07, blue: 0.14))
                    .overlay(shape.fill((tint ?? .clear).opacity(0.14)))
                    .overlay(shape.stroke(.white.opacity(0.10), lineWidth: 1))
            )
        } else if let tint {
            content.glassEffect(.clear.tint(tint.opacity(0.08)), in: shape)
        } else {
            content.glassEffect(.clear, in: shape)
        }
    }
}

/// ═══════════════════════════════════════════════════════════════
/// ESPACEMENT DE L'ÉCRAN SALAT (échelle sémantique)
/// ═══════════════════════════════════════════════════════════════

enum SalatSpacing {
    /// Entre cartes de la zone prioritaire.
    static let intraZonePrimary: CGFloat = 16
    /// Entre cartes de la zone secondaire (densité légèrement plus compacte).
    static let intraZoneSecondary: CGFloat = 12
    /// Seuil entre les deux zones.
    static let interZone: CGFloat = 36
    /// L'en-tête de section colle légèrement à sa zone.
    static let sectionHeaderBottom: CGFloat = 4
}

/// ═══════════════════════════════════════════════════════════════
/// ÉTAT DE PRIÈRE — source unique des couleurs sémantiques
/// (orange = en cours, vert = prochaine, indigo = nuit/qiyam)
/// ═══════════════════════════════════════════════════════════════

enum PrayerStateTint {
    static let now: Color = .orange
    static let upcoming: Color = .green
    static let night: Color = .indigo
}

/// ═══════════════════════════════════════════════════════════════
/// EN-TÊTE DE SECTION (onglet Salat, zone secondaire)
/// ═══════════════════════════════════════════════════════════════

/// Seuil visuel entre la zone prioritaire (glance) et la zone d'enrichissement.
/// Trait-capsule teinté par l'état de la prière (fil conducteur entre les zones),
/// titre FR uppercase discret, écho arabe décoratif à droite.
struct SalatSectionHeader: View {
    let titleFr: LocalizedStringKey
    let titleAr: String
    /// Couleur d'état de la prière (orange en cours / vert prochaine / indigo nuit).
    var accent: Color = PrayerStateTint.upcoming
    @ScaledMetric(relativeTo: .footnote) private var barWidth: CGFloat = 20

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(accent.opacity(0.9))
                .frame(width: barWidth, height: 2)
            Text(titleFr)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .kerning(1.2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Text(verbatim: titleAr)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// ═══════════════════════════════════════════════════════════════
/// CORNER RADIUS CONSTANTS
/// ═══════════════════════════════════════════════════════════════

enum CornerRadius {

    // MARK: Échelle sémantique (3 crans)

    /// 12pt — badges, chips, petits boutons.
    static let badge: CGFloat = 12

    /// 20pt — cartes et sheets (surface standard de l'app).
    static let card: CGFloat = 20

    /// 28pt — overlays plein écran et grandes modals.
    static let modal: CGFloat = 28

    // MARK: Alias de compatibilité (ancienne API — à retirer après migration complète)

    static let standard = card
    static let large = card
    static let medium = badge
    static let small = badge
    static let mini = badge
}

/// ═══════════════════════════════════════════════════════════════
/// PREVIEW
/// ═══════════════════════════════════════════════════════════════

#Preview("Design System") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 20) {
                
                // CARDS
                VStack(alignment: .leading, spacing: 12) {
                    Text("Carte Standard")
                        .font(.headline)
                    Text("Avec 20pt corner radius")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                
                // PREMIUM CARD
                VStack(alignment: .leading, spacing: 12) {
                    Text("Carte Premium")
                        .font(.headline)
                    Text("Avec bordure lumineuse")
                        .font(.caption)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .premiumCardStyle()
                
                // BUTTONS
                VStack(spacing: 12) {
                    Text("Bouton Principal")
                        .primaryButtonStyle()
                    
                    Text("Bouton Secondaire")
                        .secondaryButtonStyle()
                    
                    Text("Bouton Petit")
                        .tertiaryButtonStyle()
                    
                    Text("Badge 45%")
                        .chipStyle()
                }
            }
            .padding()
        }
    }
}
