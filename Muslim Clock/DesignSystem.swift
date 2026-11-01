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

/// Accent du domaine « pureté » (wudû'/ghusl) — bleu d'eau claire, distinct du
/// teal Coran (plus vert), de l'adhkarBookletAccent (teal grisé) et du bleu
/// système du tab Réglages (plus saturé). Token nommé (pas de couleur ad-hoc).
let wuduAccent = Color(red: 0.38, green: 0.65, blue: 0.92)

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

    /// Surface **secondaire** (zones « pour aller plus loin » des onglets).
    ///
    /// Un cran de verre en dessous de `glassCard` : `.clear` + teinte 0.08 — la
    /// carte recule optiquement et laisse voir le fond. Réutilise la grammaire
    /// existante (`.regular` = contenu, `.clear` = discret). Fallback opaque quand
    /// « Réduire la transparence » est actif — couleur adaptée au fond de l'onglet
    /// via `GlassFallback` (cosmique par défaut, `warm` pour le tab Rappel).
    func glassCardSecondary(cornerRadius: CGFloat = CornerRadius.card,
                            tint: Color? = nil,
                            fallback: Color = GlassFallback.cosmic) -> some View {
        modifier(GlassCardSecondary(cornerRadius: cornerRadius, tint: tint, fallback: fallback))
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

/// Couleurs de fallback « Réduire la transparence » par fond d'onglet.
/// Le verre échantillonne le backdrop ; le fallback opaque, lui, doit être
/// choisi à la main pour rester cohérent avec le fond de chaque tab.
enum GlassFallback {
    /// Mesh cosmique (tabs Salat / Qibla).
    static let cosmic = Color(red: 0.07, green: 0.07, blue: 0.14)
    /// Gradient chaud brun du tab Rappel (point médian, légèrement éclairci).
    static let warm = Color(red: 0.16, green: 0.09, blue: 0.06)
}

/// Implémentation de `glassCardSecondary` — ViewModifier pour accéder à
/// l'environnement d'accessibilité (fond plein si Réduire la transparence).
struct GlassCardSecondary: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat
    let tint: Color?
    let fallback: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content.background(
                shape.fill(fallback)
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

enum ZoneSpacing {
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
    /// Jumu'ah — or doux, distinct de la nuit (indigo) et de l'état « en cours » (orange).
    static let jumuah = Color(red: 0.93, green: 0.72, blue: 0.28)
}

/// ═══════════════════════════════════════════════════════════════
/// EN-TÊTE DE SECTION (onglet Salat, zone secondaire)
/// ═══════════════════════════════════════════════════════════════

/// Seuil visuel entre la zone prioritaire (glance) et la zone d'enrichissement.
/// Trait-capsule teinté par l'état de la prière (fil conducteur entre les zones),
/// titre FR uppercase discret, écho arabe décoratif à droite.
struct ZoneSectionHeader: View {
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
/// THÈME DE LECTURE (lecteur Coran + lecteur ʿIlm)
/// ═══════════════════════════════════════════════════════════════

/// Fond de lecture — surfaces unies et statiques, pensées pour la lecture
/// prolongée : contraste élevé mais non maximal (pas de blanc/noir purs, évite
/// la halation), aucune animation sous le texte pour garder les diacritiques
/// nets. Préférence PARTAGÉE entre les lecteurs (clé `"quranReadingTheme"`,
/// conservée pour ne pas perdre la persistance existante) : le confort de
/// lecture est global, l'identité de module reste portée par l'accent
/// (teal = Coran, purple = ʿIlm).
enum ReadingTheme: String, CaseIterable, Identifiable {
    /// Papier crème, texte brun foncé — confort de jour, évoque le mushaf imprimé.
    case sepia
    /// Gris très sombre, texte blanc cassé — confort du soir. Défaut (comportement historique).
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sepia: String(localized: "Sépia")
        case .dark: String(localized: "Sombre")
        }
    }

    var icon: String {
        switch self {
        case .sepia: "sun.max"
        case .dark: "moon"
        }
    }

    /// Schéma imposé à la vue pour que barre de navigation, menus et matériaux suivent le fond.
    var colorScheme: ColorScheme {
        switch self {
        case .sepia: .light
        case .dark: .dark
        }
    }

    var background: Color {
        switch self {
        case .sepia: Color(red: 0.98, green: 0.95, blue: 0.89)
        case .dark: Color(red: 0.09, green: 0.10, blue: 0.11)
        }
    }

    var cardBackground: Color {
        switch self {
        case .sepia: Color(red: 1.0, green: 0.99, blue: 0.96)
        case .dark: Color.white.opacity(0.06)
        }
    }

    var cardStroke: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.14)
        case .dark: Color.white.opacity(0.06)
        }
    }

    /// Texte principal (arabe, titres).
    var textPrimary: Color {
        switch self {
        case .sepia: sepiaInk
        case .dark: Color.white.opacity(0.87)
        }
    }

    /// Texte secondaire (traduction, translittération).
    var textSecondary: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.65)
        case .dark: Color.white.opacity(0.6)
        }
    }

    /// Métadonnées discrètes (compteurs, fins de section, séparateurs de titre).
    var textTertiary: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.45)
        case .dark: Color.white.opacity(0.4)
        }
    }

    /// Filets et pistes de progression.
    var divider: Color {
        switch self {
        case .sepia: sepiaInk.opacity(0.12)
        case .dark: Color.white.opacity(0.08)
        }
    }

    /// Encre brun foncé du thème sépia (#3E2F1C).
    private var sepiaInk: Color { Color(red: 0.24, green: 0.18, blue: 0.11) }
}

/// ═══════════════════════════════════════════════════════════════
/// TEXTE SACRÉ — un seul « langage scripturaire » (Rappel, ʿIlm, Coran)
/// ═══════════════════════════════════════════════════════════════

/// Accent par domaine : teal = Coran, purple = ʿIlm. Le hadith appartient au
/// domaine ʿIlm. Remplace les `.indigo` / `.teal` / `.purple` dispersés.
enum ModuleAccent {
    static let quran: Color = .teal
    static let hadith: Color = .purple
    static let ilm: Color = .purple
}

/// Typographie du texte sacré (verset, hadith, matn). Source unique de vérité :
/// plus aucun `.system(22)` pour de l'arabe scripturaire.
enum ScriptureFont {
    static let fontName = "AmiriQuran-Regular"
    /// Verset, hadith, matn (lecteur, Rappel, leçon).
    static let arabicBody: CGFloat = 24
    /// Flash cards, cartes compactes, fiches.
    static let arabicCompact: CGFloat = 22
    static let arabicLineSpacing: CGFloat = 12
    static let translationLineSpacing: CGFloat = 6

    /// Amiri Quran, mise à l'échelle Dynamic Type (`relativeTo:`) — la taille
    /// donnée est celle du réglage par défaut.
    static func arabic(_ size: CGFloat = arabicBody) -> Font {
        .custom(fontName, size: size, relativeTo: .title3)
    }

    /// Traduction : serif, droite (l'italique est réservé à la ligne de source).
    static func translation(_ style: Font.TextStyle = .callout) -> Font {
        .system(style, design: .serif)
    }

    /// Traduction à taille fixe — uniquement là où la taille est un réglage de
    /// lecture choisi par l'utilisateur (lecteur Coran).
    static func translation(size: CGFloat) -> Font {
        .system(size: size, design: .serif)
    }

    /// Ligne de source / référence.
    static func source() -> Font {
        .system(.footnote, design: .serif).italic()
    }
}

/// Fonds d'onglets qui ne sont pas le fond cosmique.
enum TabBackground {
    /// Dégradé chaud brun de l'onglet Rappel (cf. `GlassFallback.warm`).
    static let rappel = LinearGradient(
        colors: [Color(red: 0.1, green: 0.05, blue: 0.05), Color(red: 0.2, green: 0.1, blue: 0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension View {
    /// Carte de texte sacré : même surface pour verset, hadith, révision.
    /// La carte redimensionne comme un bloc (anti-wiggle n°6).
    func scriptureCard(accent: Color) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: CornerRadius.card, tint: accent)
            .geometryGroup()
    }

    /// Carte repliable de la zone secondaire : verre secondaire, contenu
    /// **clippé** à la forme (pendant l'animation de dépli, le contenu inséré
    /// débordait sous la carte suivante), et redimensionnement en bloc.
    /// Le contenu déplié doit porter `.transition(.opacity)`.
    func collapsibleCard(tint: Color?) -> some View {
        self
            .glassCardSecondary(tint: tint)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .geometryGroup()
    }
}

/// Emplacement d'une carte conditionnelle dans une zone en `spacing: 0` :
/// le conteneur survit à l'absence de carte (il anime l'entrée/sortie —
/// anti-wiggle n°4) et porte l'espacement bas DANS la condition, donc aucun
/// trou quand la carte est absente.
struct ZoneCardSlot<Content: View>: View {
    let isVisible: Bool
    var spacing: CGFloat = ZoneSpacing.intraZoneSecondary
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            if isVisible {
                content()
                    .padding(.bottom, spacing)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.35), value: isVisible)
    }
}

/// Bascule FR ↔ arabe d'une carte. Largeur minimale fixe (« FR » vs « عربي ») :
/// aucun déplacement horizontal au toggle (anti-wiggle n°3).
struct LanguageToggleChip: View {
    /// `true` quand l'arabe est affiché : le bouton propose alors « FR ».
    let isArabic: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: isArabic ? "FR" : "عربي")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(minWidth: 42)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .contentTransition(.opacity)
                // Cible tactile ≥ 44 pt (HIG) ; la capsule visible reste compacte.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(isArabic ? Text("Afficher la traduction") : Text("Afficher le texte arabe"))
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
