//
//  SeasonalUpdatePopupView.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 01/04/2026.
//

import SwiftUI

struct SeasonalUpdatePopupView: View {
    @Binding var isPresented: Bool
    @Binding var lastSetupTimestamp: Double
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.triangle.2.circlepath.clock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange, .white.opacity(0.3))
                .padding(.top, 30)
            
            VStack(spacing: 8) {
                Text("Changement de Saison")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Les horaires de votre mosquée ont probablement changé avec la nouvelle saison (heure d'été/hiver). \nVoulez-vous relancer une analyse rapide pour rester synchronisé ?")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    isPresented = false
                    // Tu pourrais utiliser un environnement object pour naviguer directement,
                    // ou simplement fermer et laisser l'utilisateur aller dans les réglages.
                } label: {
                    Text("J'y vais")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(15)
                }
                
                Button {
                    lastSetupTimestamp = Date().timeIntervalSince1970 // Ignore pour 4 mois
                    isPresented = false
                } label: {
                    Text("Ignorer pour l'instant")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                        .padding()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.5))
    }
}
