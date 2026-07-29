import SwiftUI

/// Système de couleurs « Aurora glass » de Poze : fond sombre profond, verre
/// translucide, et une palette de dégradés au choix pour personnaliser groupes
/// et events.
enum Theme {
    /// Fond général très sombre, légèrement bleuté.
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.078)      // #0a0a14
    static let bgElevated = Color(red: 0.07, green: 0.07, blue: 0.12)
    static let accent = Color(red: 0.486, green: 0.361, blue: 1.0)     // #7c5cff
    static let accent2 = Color(red: 0.133, green: 0.827, blue: 0.933)  // #22d3ee

    /// Dégradé signature (le « o » de Poze, l'objectif).
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Dégradés prédéfinis pour habiller un groupe ou un event.
enum Colorway: String, CaseIterable, Codable, Identifiable {
    case aurora, sunset, ocean, forest, candy, gold

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .aurora: return [Color(hex: 0x7c5cff), Color(hex: 0x22d3ee)]
        case .sunset: return [Color(hex: 0xff6a5c), Color(hex: 0xffb35c)]
        case .ocean:  return [Color(hex: 0x2563eb), Color(hex: 0x22d3ee)]
        case .forest: return [Color(hex: 0x22c55e), Color(hex: 0x84cc16)]
        case .candy:  return [Color(hex: 0xec4899), Color(hex: 0x8b5cf6)]
        case .gold:   return [Color(hex: 0xf59e0b), Color(hex: 0xef4444)]
        }
    }

    var label: String {
        switch self {
        case .aurora: return "Aurora"
        case .sunset: return "Coucher"
        case .ocean:  return "Océan"
        case .forest: return "Forêt"
        case .candy:  return "Bonbon"
        case .gold:   return "Or"
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var primary: Color { colors.first ?? Theme.accent }
}

extension Color {
    /// Initialise une couleur depuis un entier hexadécimal (0xRRGGBB).
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

/// Carte en verre réutilisable (glassmorphism) — la brique visuelle de l'app.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }
}
