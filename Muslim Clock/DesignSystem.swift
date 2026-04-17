//
//  DesignSystem.swift
//  Muslim Clock
//
//  🎨 Guide de style iOS 18+ conforme
//

import SwiftUI

/// ═══════════════════════════════════════════════════════════════
/// DESIGN SYSTEM MUSLIM CLOCK
/// Conforme aux standards iOS 18+ Liquid Glass
/// ═══════════════════════════════════════════════════════════════

extension View {
    
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
    /// 20pt - Standard iOS 18 (TabBar, Cards, Sheets)
    static let standard: CGFloat = 20
    
    /// 16pt - Gros boutons
    static let large: CGFloat = 16
    
    /// 12pt - Boutons moyens
    static let medium: CGFloat = 12
    
    /// 10pt - Petits boutons
    static let small: CGFloat = 10
    
    /// 8pt - Mini éléments (badges, chips)
    static let mini: CGFloat = 8
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
