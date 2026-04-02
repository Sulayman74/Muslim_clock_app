//
//  QiblahView.swift
//  Muslim Clock
//
//  Redesign iOS 26 — Custom Kaaba + Progressive Haptics + Liquid Glass
//

import SwiftUI
import CoreLocation

// MARK: - ═══════════════════════════════════════════════════
// VUE PRINCIPALE
// ═══════════════════════════════════════════════════════════

struct QiblaView: View {
    @ObservedObject var manager: CompassManager
    
    // MARK: - Couleurs
    private let vertSapin = Color(red: 0.09, green: 0.33, blue: 0.16)
    private let orQiblah  = Color(red: 0.85, green: 0.68, blue: 0.32)
    
    private var relativeQibla: Double {
        (manager.qiblaAngle - manager.heading + 360)
            .truncatingRemainder(dividingBy: 360)
    }
    
    /// Opacité du glow basée sur la proximité (0→4 mapped to 0→1)
    private var glowIntensity: Double {
        Double(manager.proximityLevel) / 4.0
    }
    
    var body: some View {
        ZStack {
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 1. FOND ANIMÉ
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            backgroundLayer
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 2. CONTENU
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            VStack(spacing: 0) {
                Spacer().frame(height: 24)
                headerSection
                Spacer()
                compassSection
                Spacer()
                footerInfo
                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 20)
        }
        .onAppear  { manager.startCompass() }
        .onDisappear { manager.stopCompass() }
    }
    
    // MARK: - Background
    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            // Couche verte qui apparaît progressivement avec la proximité
            vertSapin
                .opacity(glowIntensity * 0.8)
            
            // Radial glow central quand on s'approche
            RadialGradient(
                colors: [
                    .green.opacity(0.3 * glowIntensity),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: manager.proximityLevel)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Qiblah")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11))
                Text(manager.cityName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.secondary)
            
            // ✅ Date hégirien compact sous le nom de ville
            WidgetDateHeader(date: .now, compact: true)
        }
        .foregroundStyle(.white)
    }
    
    // MARK: - Compass
    private var compassSection: some View {
        let size: CGFloat = 320
        
        return ZStack {
            
            // ── Cercle Liquid Glass ──
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
                .overlay(
                    Circle()
                        .stroke(
                            .white.opacity(0.08 + glowIntensity * 0.4),
                            lineWidth: 1.2
                        )
                )
                // Glow progressif autour du cercle
                .overlay(
                    Circle()
                        .stroke(orQiblah.opacity(glowIntensity * 0.5), lineWidth: 3)
                        .blur(radius: 10)
                )
            
            // ── Graduations (tournent avec le heading) ──
            CompassDialView(size: size)
                .rotationEffect(.degrees(-manager.heading))
                .animation(
                    .interpolatingSpring(stiffness: 80, damping: 14),
                    value: manager.heading
                )
            
            // ── Triangle indicateur fixe en haut ──
            VStack {
                TriangleShape()
                    .fill(orQiblah)
                    .frame(width: 14, height: 10)
                    .shadow(color: orQiblah.opacity(0.6), radius: 4)
                    .offset(y: -4)
                Spacer()
            }
            .frame(height: size)
            
            // ── Aiguille Qiblah ──
            QiblaNeedle(
                proximityLevel: manager.proximityLevel,
                accentColor: orQiblah,
                size: size
            )
            .rotationEffect(.degrees(relativeQibla))
            .animation(
                .interpolatingSpring(stiffness: 80, damping: 14),
                value: relativeQibla
            )
            
            // ── KAABA AU CENTRE — apparaît quand aligné ──
            KaabaIcon(
                size: 44,
                goldColor: orQiblah
            )
            .scaleEffect(manager.isCorrectDirection ? 1.0 : 0.3)
            .opacity(manager.isCorrectDirection ? 1.0 : 0.0)
            .animation(
                .interpolatingSpring(stiffness: 120, damping: 10),
                value: manager.isCorrectDirection
            )
            
            // ── Center dot (visible quand Kaaba n'est pas là) ──
            Circle()
                .fill(.white.opacity(0.5))
                .frame(width: 8, height: 8)
                .opacity(manager.isCorrectDirection ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: manager.isCorrectDirection)
        }
    }
    
    // MARK: - Footer
    private var footerInfo: some View {
        VStack(spacing: 16) {
            // Barre de proximité visuelle
            ProximityBar(level: manager.proximityLevel, accentColor: orQiblah)
            
            // Status
            Text(statusText)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(statusColor)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.3), value: manager.proximityLevel)
            
            // Degrés
            HStack(spacing: 24) {
                degreeLabel(title: "Bearing", value: manager.qiblaAngle)
                degreeLabel(title: "Offset", value: manager.angularOffset)
                degreeLabel(title: "Heading", value: manager.heading)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
        }
    }
    
    private var statusText: String {
        switch manager.proximityLevel {
        case 4: return "ALIGNÉ"
        case 3: return "PRESQUE..."
        case 2: return "PLUS PROCHE"
        case 1: return "ON S'APPROCHE"
        default: return "CHERCHER"
        }
    }
    
    private var statusColor: Color {
        switch manager.proximityLevel {
        case 4: return orQiblah
        case 3: return .green
        case 2: return .cyan
        case 1: return .white.opacity(0.6)
        default: return .white.opacity(0.35)
        }
    }
    
    private func degreeLabel(title: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .tracking(1)
            Text("\(Int(value))°")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.65))
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(value))
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// KAABA ICON — Dessinée en SwiftUI Path (vue isométrique)
// ═══════════════════════════════════════════════════════════

struct KaabaIcon: View {
    let size: CGFloat
    let goldColor: Color
    
    var body: some View {
        ZStack {
            // Glow derrière
            Circle()
                .fill(
                    RadialGradient(
                        colors: [goldColor.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
            
            // La Kaaba
            KaabaShape()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                .frame(width: size, height: size)
                .overlay(
                    // Face latérale plus claire pour l'effet 3D
                    KaabaSide()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .frame(width: size, height: size)
                )
                .overlay(
                    // Bande dorée (Hizam / ceinture du Kiswah)
                    KaabaBand()
                        .fill(goldColor)
                        .frame(width: size, height: size)
                )
                .overlay(
                    // Porte dorée
                    KaabaDoor()
                        .fill(goldColor.opacity(0.8))
                        .frame(width: size, height: size)
                )
                .shadow(color: goldColor.opacity(0.5), radius: 12)
        }
    }
}

/// Face frontale du cube
struct KaabaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            // Face frontale
            p.move(to: CGPoint(x: w * 0.10, y: h * 0.28))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.28))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.92))
            p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.92))
            p.closeSubpath()
            
            // Toit en perspective
            p.move(to: CGPoint(x: w * 0.10, y: h * 0.28))
            p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.10))
            p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.10))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.28))
            p.closeSubpath()
        }
    }
}

/// Face latérale droite (plus claire)
struct KaabaSide: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            p.move(to: CGPoint(x: w * 0.72, y: h * 0.28))
            p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.10))
            p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.76))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.92))
            p.closeSubpath()
        }
    }
}

/// Bande dorée (Hizam) sur les deux faces visibles
struct KaabaBand: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            // Bande sur la face frontale
            p.addRect(CGRect(
                x: w * 0.10,
                y: h * 0.44,
                width: w * 0.62,
                height: h * 0.035
            ))
            // Bande sur la face droite (en perspective)
            p.move(to: CGPoint(x: w * 0.72, y: h * 0.44))
            p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.335))
            p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.37))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.475))
            p.closeSubpath()
        }
    }
}

/// Porte de la Kaaba (arche dorée)
struct KaabaDoor: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let doorW = w * 0.13
        let doorH = h * 0.20
        let doorX = w * 0.34
        let doorBottom = h * 0.92
        let doorTop = doorBottom - doorH
        
        return Path { p in
            p.move(to: CGPoint(x: doorX, y: doorBottom))
            p.addLine(to: CGPoint(x: doorX, y: doorTop + doorW * 0.35))
            p.addQuadCurve(
                to: CGPoint(x: doorX + doorW, y: doorTop + doorW * 0.35),
                control: CGPoint(x: doorX + doorW / 2, y: doorTop)
            )
            p.addLine(to: CGPoint(x: doorX + doorW, y: doorBottom))
            p.closeSubpath()
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// PROXIMITY BAR — Barre de proximité visuelle
// ═══════════════════════════════════════════════════════════

struct ProximityBar: View {
    let level: Int // 0-4
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { i in
                Capsule()
                    .fill(i <= level ? colorFor(i) : .white.opacity(0.1))
                    .frame(width: i <= level ? 32 : 24, height: 4)
                    .animation(
                        .interpolatingSpring(stiffness: 200, damping: 15)
                            .delay(Double(i) * 0.04),
                        value: level
                    )
            }
        }
    }
    
    private func colorFor(_ step: Int) -> Color {
        switch step {
        case 1: return .white.opacity(0.5)
        case 2: return .cyan
        case 3: return .green
        case 4: return accentColor
        default: return .clear
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// COMPASS DIAL — Graduations + Cardinaux
// ═══════════════════════════════════════════════════════════

struct CompassDialView: View {
    let size: CGFloat
    
    private let cardinals: [(String, Double, Color)] = [
        ("N", 0,   .red),
        ("E", 90,  .white),
        ("S", 180, .white),
        ("W", 270, .white),
    ]
    
    var body: some View {
        ZStack {
            // Graduations tous les 5°
            ForEach(0..<72, id: \.self) { i in
                let angle = Double(i) * 5
                let isMajor = angle.truncatingRemainder(dividingBy: 30) == 0
                let isCardinal = angle.truncatingRemainder(dividingBy: 90) == 0
                
                Rectangle()
                    .fill(.white.opacity(isCardinal ? 0.8 : (isMajor ? 0.4 : 0.15)))
                    .frame(
                        width: isCardinal ? 2.0 : (isMajor ? 1.5 : 1.0),
                        height: isCardinal ? 16 : (isMajor ? 10 : 6)
                    )
                    .offset(y: -(size / 2 - 24))
                    .rotationEffect(.degrees(angle))
            }
            
            // Lettres cardinales
            ForEach(cardinals, id: \.1) { label, angle, color in
                Text(label)
                    .font(.system(size: label == "N" ? 18 : 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color.opacity(label == "N" ? 1.0 : 0.6))
                    .offset(y: -(size / 2 - 50))
                    .rotationEffect(.degrees(angle))
            }
            
            // Degrés intermédiaires
            ForEach([30, 60, 120, 150, 210, 240, 300, 330], id: \.self) { deg in
                Text("\(deg)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .offset(y: -(size / 2 - 52))
                    .rotationEffect(.degrees(Double(deg)))
            }
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// QIBLA NEEDLE — Aiguille avec couleur progressive
// ═══════════════════════════════════════════════════════════

struct QiblaNeedle: View {
    let proximityLevel: Int
    let accentColor: Color
    let size: CGFloat
    
    private var needleColor: Color {
        switch proximityLevel {
        case 4: return .white
        case 3: return .green
        case 2: return .cyan
        default: return accentColor
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Losange en pointe
            Diamond()
                .fill(needleColor)
                .frame(width: 12, height: 16)
                .shadow(color: needleColor.opacity(0.6), radius: 6)
            
            // Trait dégradé
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [needleColor, needleColor.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2.5, height: size / 2 - 65)
            
            Spacer()
        }
        .frame(height: size - 40)
        .animation(.easeInOut(duration: 0.3), value: proximityLevel)
    }
}

// MARK: - ═══════════════════════════════════════════════════
// SHAPES UTILITAIRES
// ═══════════════════════════════════════════════════════════

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

// MARK: - Preview
#Preview {
    QiblaView(manager: CompassManager())
        .preferredColorScheme(.dark)
}
