//
//  AdhanOverlay.swift
//  Muslim Clock
//
//  Overlay élégant pendant l'Adhan
//

import SwiftUI

struct AdhanOverlayView: View {
    let prayerName: String
    let prayerTime: Date
    let onDismiss: () -> Void
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // ── FOND BLUR AVEC GRADIENT ──
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color(red: 0.1, green: 0.15, blue: 0.2).opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .blur(radius: 20)
            
            // ── CONTENU PRINCIPAL ──
            VStack(spacing: 30) {
                
                Spacer()
                
                // ICÔNE ANIMÉE
                ZStack {
                    // Cercle de lueur pulsante
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(glowOpacity), Color.clear],
                                center: .center,
                                startRadius: 50,
                                endRadius: 120
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale)
                    
                    // Icône de mosquée
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 80, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 20)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                        glowOpacity = 0.6
                    }
                }
                
                // TEXTE PRINCIPAL
                VStack(spacing: 12) {
                    Text("Temps de la prière")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(2)
                        .textCase(.uppercase)
                    
                    Text(prayerName)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text(prayerArabicName)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.orange)
                        .environment(\.layoutDirection, .rightToLeft)
                    
                    Text(prayerTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 20, design: .monospaced).weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 8)
                }
                
                // RAPPEL SPIRITUEL
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 60)
                    
                    Text(spiritualReminder)
                        .font(.system(size: 14, design: .serif))
                        .italic()
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // BOUTON DE FERMETURE
                Button(action: onDismiss) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("J'ai compris")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 15, y: 8)
                }
                .padding(.bottom, 50)
            }
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    // Rappel spirituel selon la prière
    private var spiritualReminder: String {
        prayerName.lowercased() == "fajr"
            ? "الصلاة رحمكم الله، الصلاة خير من النوم"
            : "الصلاة رحمكم الله"
    }
    
    // Nom arabe de la prière
    private var prayerArabicName: String {
        switch prayerName.lowercased() {
        case "fajr": return "الفجر"
        case "dhuhr": return "الظهر"
        case "asr": return "العصر"
        case "maghrib": return "المغرب"
        case "isha": return "العشاء"
        default: return ""
        }
    }
}

// MARK: - PREVIEW
#Preview {
    AdhanOverlayView(
        prayerName: "Maghrib",
        prayerTime: Date(),
        onDismiss: {}
    )
}
