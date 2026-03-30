//
//  CustomBottomBar.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//

import SwiftUI

struct CustomBottomBar: View {
    @Binding var selectedTab: Int
    
    
    var body: some View {
        HStack(spacing: 60) {
            MenuButton(icon: "house.fill", index: 0, selectedTab: $selectedTab)
            MenuButton(icon: "safari.fill", index: 1, selectedTab: $selectedTab)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 40)
        .background {
            // L'effet natif de loupe/verre d'Apple
            Capsule()
                .fill(.regularMaterial)
                // On force un léger assombrissement pour le contraste
                .environment(\.colorScheme, .dark)
                .overlay(
                    // Le reflet "Liquide" sur le bord supérieur
                    Capsule()
                        .stroke(LinearGradient(
                            colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 0.8)
                )
        }
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
    }
}
struct MenuButton: View {
    let icon: String
    let index: Int
    @Binding var selectedTab: Int
    
    
    var body: some View {
        Button(action: {
            // 1. On empêche de vibrer si on clique sur l'onglet déjà actif
            if selectedTab != index {
                // 2. Le retour haptique (Vibration légère)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                
                // 3. Changement d'onglet avec animation fluide
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    selectedTab = index
                }
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(selectedTab == index ? .primary : .secondary)
                .scaleEffect(selectedTab == index ? 1.2 : 1.0)
                .overlay(alignment: .bottom) {
                    if selectedTab == index {
                        Circle()
                            .fill(.primary)
                            .frame(width: 4, height: 4)
                            .offset(y: 10)
                    }
                }
        }
    }
}
