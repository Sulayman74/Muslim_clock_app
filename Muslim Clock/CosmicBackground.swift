//
//  CosmicBackground.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 02/04/2026.
//

import SwiftUI

// MARK: - ═══════════════════════════════════════════════════
// COSMIC BACKGROUND
// MeshGradient + étoiles + étoiles filantes + poussière
// ═══════════════════════════════════════════════════════════

struct CosmicBackground: View {
    let season: IslamicSeasonInfo
    
    private var meshColors: [Color] {
        switch season.seasonKey {
        case "ramadan":
            return [
                Color(red: 0.12, green: 0.08, blue: 0.02), Color(red: 0.20, green: 0.14, blue: 0.03), Color(red: 0.10, green: 0.07, blue: 0.02),
                Color(red: 0.18, green: 0.12, blue: 0.02), Color(red: 0.30, green: 0.22, blue: 0.05), Color(red: 0.15, green: 0.10, blue: 0.03),
                Color(red: 0.08, green: 0.05, blue: 0.01), Color(red: 0.22, green: 0.15, blue: 0.03), Color(red: 0.06, green: 0.04, blue: 0.01)
            ]
        case "hajj":
            return [
                Color(red: 0.02, green: 0.10, blue: 0.06), Color(red: 0.03, green: 0.16, blue: 0.08), Color(red: 0.02, green: 0.08, blue: 0.05),
                Color(red: 0.04, green: 0.18, blue: 0.10), Color(red: 0.06, green: 0.25, blue: 0.14), Color(red: 0.03, green: 0.12, blue: 0.07),
                Color(red: 0.01, green: 0.06, blue: 0.03), Color(red: 0.04, green: 0.14, blue: 0.08), Color(red: 0.01, green: 0.05, blue: 0.02)
            ]
        case "muharram":
            return [
                Color(red: 0.03, green: 0.04, blue: 0.14), Color(red: 0.06, green: 0.06, blue: 0.22), Color(red: 0.02, green: 0.03, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.20), Color(red: 0.08, green: 0.08, blue: 0.30), Color(red: 0.04, green: 0.04, blue: 0.16),
                Color(red: 0.02, green: 0.02, blue: 0.10), Color(red: 0.05, green: 0.05, blue: 0.18), Color(red: 0.01, green: 0.01, blue: 0.08)
            ]
        case "shaban":
            return [
                Color(red: 0.10, green: 0.05, blue: 0.14), Color(red: 0.14, green: 0.07, blue: 0.20), Color(red: 0.08, green: 0.04, blue: 0.12),
                Color(red: 0.12, green: 0.06, blue: 0.18), Color(red: 0.18, green: 0.10, blue: 0.28), Color(red: 0.10, green: 0.05, blue: 0.15),
                Color(red: 0.06, green: 0.03, blue: 0.10), Color(red: 0.12, green: 0.06, blue: 0.16), Color(red: 0.04, green: 0.02, blue: 0.08)
            ]
        default:
            return [
                Color(red: 0.04, green: 0.04, blue: 0.12), Color(red: 0.08, green: 0.06, blue: 0.20), Color(red: 0.03, green: 0.03, blue: 0.10),
                Color(red: 0.06, green: 0.05, blue: 0.18), Color(red: 0.12, green: 0.08, blue: 0.28), Color(red: 0.05, green: 0.04, blue: 0.15),
                Color(red: 0.02, green: 0.02, blue: 0.08), Color(red: 0.07, green: 0.05, blue: 0.16), Color(red: 0.01, green: 0.01, blue: 0.06)
            ]
        }
    }
    
    private var starColor: Color {
        switch season.seasonKey {
        case "ramadan": return Color(red: 1.0, green: 0.9, blue: 0.6)
        case "hajj": return Color(red: 0.7, green: 1.0, blue: 0.8)
        case "muharram": return Color(red: 0.7, green: 0.8, blue: 1.0)
        default: return .white
        }
    }
    
    var body: some View {
        ZStack {
            // Couche 1 : MeshGradient cosmique
            MeshGradient(
                width: 3, height: 3,
                points: [
                    .init(0, 0),    .init(0.5, 0),     .init(1, 0),
                    .init(0, 0.5),  .init(0.55, 0.45),  .init(1, 0.5),
                    .init(0, 1),    .init(0.5, 1),     .init(1, 1)
                ],
                colors: meshColors
            )
            .ignoresSafeArea()
            
            // Couche 2 : Étoiles fixes scintillantes
            FixedStarsLayer(starColor: starColor)
                .ignoresSafeArea()
            
            // Couche 3 : Poussière cosmique flottante
            CosmicDustLayer(dustColor: starColor)
                .ignoresSafeArea()
                .opacity(0.6)
            
            // Couche 4 : Étoiles filantes
            ShootingStarsLayer(trailColor: starColor)
                .ignoresSafeArea()
                .opacity(0.8)
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// COUCHE 1 : ÉTOILES FIXES SCINTILLANTES
// ═══════════════════════════════════════════════════════════

private struct FixedStarData {
    let x, y, radius: CGFloat
    let baseOpacity, flickerSpeed, flickerPhase: Double
}

struct FixedStarsLayer: View {
    let starColor: Color
    
    private let stars: [FixedStarData] = {
        var rng = CosmicRNG(seed: 42)
        return (0..<70).map { _ in
            FixedStarData(
                x: .random(in: 0...1, using: &rng),
                y: .random(in: 0...1, using: &rng),
                radius: .random(in: 0.4...1.6, using: &rng),
                baseOpacity: .random(in: 0.3...0.9, using: &rng),
                flickerSpeed: .random(in: 0.5...2.5, using: &rng),
                flickerPhase: .random(in: 0...(.pi * 2), using: &rng)
            )
        }
    }()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let flicker = sin(time * star.flickerSpeed + star.flickerPhase)
                    let opacity = max(0.1, min(1.0, star.baseOpacity + flicker * 0.25))
                    let rect = CGRect(x: star.x * size.width - star.radius,
                                      y: star.y * size.height - star.radius,
                                      width: star.radius * 2, height: star.radius * 2)
                    context.opacity = opacity
                    context.fill(Path(ellipseIn: rect), with: .color(starColor))
                    
                    if star.radius > 1.0 {
                        let halo = CGRect(x: star.x * size.width - star.radius * 2.5,
                                          y: star.y * size.height - star.radius * 2.5,
                                          width: star.radius * 5, height: star.radius * 5)
                        context.opacity = opacity * 0.12
                        context.fill(Path(ellipseIn: halo), with: .color(starColor))
                    }
                }
            }
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// COUCHE 2 : POUSSIÈRE COSMIQUE FLOTTANTE
// Particules lentes qui dérivent dans des directions variées
// ═══════════════════════════════════════════════════════════

private struct DustParticle {
    let startX, startY: CGFloat
    let driftX, driftY: CGFloat     // Direction de dérive
    let speed: Double               // Vitesse (cycle en secondes)
    let radius: CGFloat
    let baseOpacity: Double
    let phase: Double               // Décalage temporel
}

struct CosmicDustLayer: View {
    let dustColor: Color
    
    private let particles: [DustParticle] = {
        var rng = CosmicRNG(seed: 777)
        return (0..<25).map { _ in
            DustParticle(
                startX: .random(in: 0...1, using: &rng),
                startY: .random(in: 0...1, using: &rng),
                driftX: .random(in: -0.08...0.08, using: &rng),
                driftY: .random(in: -0.06...0.06, using: &rng),
                speed: .random(in: 12...30, using: &rng),
                radius: .random(in: 1.0...3.0, using: &rng),
                baseOpacity: .random(in: 0.15...0.5, using: &rng),
                phase: .random(in: 0...100, using: &rng)
            )
        }
    }()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for p in particles {
                    let t = (time + p.phase).truncatingRemainder(dividingBy: p.speed) / p.speed
                    
                    // Mouvement sinusoïdal doux (aller-retour)
                    let xOffset = sin(t * .pi * 2) * p.driftX
                    let yOffset = cos(t * .pi * 2) * p.driftY
                    
                    let x = ((p.startX + xOffset).truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0) * size.width
                    let y = ((p.startY + yOffset).truncatingRemainder(dividingBy: 1.0) + 1.0).truncatingRemainder(dividingBy: 1.0) * size.height
                    
                    // Pulsation douce
                    let pulse = sin(time * 0.8 + p.phase) * 0.15
                    let opacity = max(0.05, p.baseOpacity + pulse)
                    
                    // Particule avec halo doux
                    let haloRect = CGRect(x: x - p.radius * 3, y: y - p.radius * 3,
                                          width: p.radius * 6, height: p.radius * 6)
                    context.opacity = opacity * 0.3
                    context.fill(Path(ellipseIn: haloRect), with: .color(dustColor))
                    
                    let coreRect = CGRect(x: x - p.radius, y: y - p.radius,
                                          width: p.radius * 2, height: p.radius * 2)
                    context.opacity = opacity
                    context.fill(Path(ellipseIn: coreRect), with: .color(dustColor))
                }
            }
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════
// COUCHE 3 : ÉTOILES FILANTES
// Traînées lumineuses occasionnelles
// ═══════════════════════════════════════════════════════════

private struct ShootingStar {
    let startX, startY: CGFloat     // Point de départ (normalisé 0-1)
    let angle: Double               // Direction en radians
    let speed: CGFloat              // Longueur de la traînée
    let triggerTime: Double         // Quand apparaître (secondes dans le cycle)
    let duration: Double            // Combien de temps visible
    let length: CGFloat             // Longueur de la traînée
}

struct ShootingStarsLayer: View {
    let trailColor: Color
    
    // Cycle total en secondes — les étoiles filantes se répètent
    private let cycleDuration: Double = 45.0
    
    private let shootingStars: [ShootingStar] = {
        var rng = CosmicRNG(seed: 1337)
        return (0..<5).map { i in
            ShootingStar(
                startX: .random(in: 0.1...0.9, using: &rng),
                startY: .random(in: 0.05...0.4, using: &rng),
                angle: .random(in: 0.3...1.2, using: &rng),          // Diagonale vers bas-droite
                speed: .random(in: 0.4...0.8, using: &rng),
                triggerTime: Double(i) * 9.0 + .random(in: 0...4, using: &rng),
                duration: .random(in: 0.6...1.2, using: &rng),
                length: .random(in: 60...120, using: &rng)
            )
        }
    }()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
                
                for star in shootingStars {
                    // Est-ce que cette étoile est active ?
                    let elapsed = cycleTime - star.triggerTime
                    guard elapsed >= 0 && elapsed < star.duration else { continue }
                    
                    let progress = elapsed / star.duration  // 0 → 1
                    
                    // Position de la tête
                    let headX = star.startX * size.width + CGFloat(progress) * star.speed * size.width * cos(star.angle)
                    let headY = star.startY * size.height + CGFloat(progress) * star.speed * size.height * sin(star.angle)
                    
                    // Position de la queue (derrière la tête)
                    let tailX = headX - star.length * cos(star.angle) * CGFloat(min(progress * 3, 1.0))
                    let tailY = headY - star.length * sin(star.angle) * CGFloat(min(progress * 3, 1.0))
                    
                    // Opacité : fade in rapide, fade out doux
                    let fadeIn = min(progress * 5, 1.0)
                    let fadeOut = max(1.0 - (progress - 0.6) / 0.4, 0)
                    let opacity = fadeIn * fadeOut
                    
                    // Dessiner la traînée (ligne épaisse → fine)
                    var path = Path()
                    path.move(to: CGPoint(x: tailX, y: tailY))
                    path.addLine(to: CGPoint(x: headX, y: headY))
                    
                    context.opacity = opacity * 0.8
                    context.stroke(path,
                                   with: .color(trailColor.opacity(0.9)),
                                   lineWidth: 1.5)
                    
                    // Halo de la tête
                    let headRect = CGRect(x: headX - 3, y: headY - 3, width: 6, height: 6)
                    context.opacity = opacity
                    context.fill(Path(ellipseIn: headRect), with: .color(trailColor))
                    
                    let glowRect = CGRect(x: headX - 8, y: headY - 8, width: 16, height: 16)
                    context.opacity = opacity * 0.25
                    context.fill(Path(ellipseIn: glowRect), with: .color(trailColor))
                }
            }
        }
    }
}

// MARK: - Seeded RNG

private struct CosmicRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}
