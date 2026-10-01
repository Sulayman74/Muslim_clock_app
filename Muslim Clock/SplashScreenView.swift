//
//  SplashScreenView.swift
//  Muslim Clock
//
//  Faux écran de lancement animé, affiché par-dessus MainView au démarrage.
//

import SwiftUI

/// Faux écran de lancement animé.
///
/// La première frame est strictement identique au launch screen natif déclaré
/// dans `Muslim-Clock-Info.plist` (`UILaunchScreen` : couleur `LaunchBackground`
/// + image `SplashLogo` à sa taille intrinsèque, centrée) — le raccord natif →
/// SwiftUI est donc invisible. Ensuite :
/// 1. le logo « respire » (léger agrandissement) pendant qu'un halo s'allume ;
/// 2. l'ensemble s'estompe en s'agrandissant pour révéler `MainView` dessous.
///
/// Reduce Motion : fondu simple, aucun changement d'échelle.
struct SplashScreenView: View {
    /// Appelé une fois l'animation de sortie terminée — le parent retire la vue.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .idle

    private enum Phase {
        case idle, breathing, exiting
    }

    // MARK: - Constantes

    /// Noms d'assets partagés avec le launch screen natif (Info.plist).
    static let backgroundColorName = "LaunchBackground"
    static let logoImageName = "SplashLogo"

    /// Temps mort initial : laisse le raccord natif → SwiftUI se faire sans mouvement.
    private static let holdDuration: Duration = .milliseconds(150)
    private static let breatheDuration: TimeInterval = 0.7
    private static let exitDuration: TimeInterval = 0.45

    private static let logoBreathScale: CGFloat = 1.06
    private static let exitScale: CGFloat = 1.12
    private static let haloSize: CGFloat = 360

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(Self.backgroundColorName)
                .ignoresSafeArea()

            halo

            Image(Self.logoImageName)
                .scaleEffect(logoScale)
                .shadow(color: .white.opacity(glowOpacity), radius: 18)
        }
        .opacity(phase == .exiting ? 0 : 1)
        .scaleEffect(phase == .exiting && !reduceMotion ? Self.exitScale : 1)
        .accessibilityHidden(true)
        .task { await runSequence() }
    }

    /// Halo radial derrière le logo — s'allume et s'épanouit en phase « breathing ».
    private var halo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: Self.haloSize / 2
                )
            )
            .frame(width: Self.haloSize, height: Self.haloSize)
            .blur(radius: 20)
            .scaleEffect(phase == .idle || reduceMotion ? 0.6 : 1)
            .opacity(phase == .idle ? 0 : 1)
    }

    private var logoScale: CGFloat {
        guard !reduceMotion, phase != .idle else { return 1 }
        return Self.logoBreathScale
    }

    private var glowOpacity: Double {
        phase == .idle ? 0 : 0.35
    }

    // MARK: - Séquence

    private func runSequence() async {
        // Une sortie anticipée (Task annulée = vue retirée) ne doit pas rappeler
        // `onFinished` : le parent a déjà disposé de la vue.
        do {
            try await Task.sleep(for: Self.holdDuration)

            let breathe: Animation = reduceMotion
                ? .easeInOut(duration: Self.breatheDuration)
                : .spring(duration: Self.breatheDuration, bounce: 0.35)
            withAnimation(breathe) { phase = .breathing }
            try await Task.sleep(for: .seconds(Self.breatheDuration + 0.15))

            withAnimation(.easeIn(duration: Self.exitDuration)) { phase = .exiting }
            try await Task.sleep(for: .seconds(Self.exitDuration))

            onFinished()
        } catch {
            // Task.sleep ne lève que CancellationError : rien à faire.
        }
    }
}

#Preview {
    SplashScreenView {}
}
