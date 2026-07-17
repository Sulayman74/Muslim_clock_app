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
