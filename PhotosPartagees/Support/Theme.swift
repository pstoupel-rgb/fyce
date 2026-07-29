import SwiftUI

/// Système visuel « éditorial / noir » de Poze : noir profond, typo confiante,
/// une seule couleur d'accent chaude, des filets fins au lieu de verre. La photo
/// apporte la couleur — l'interface reste neutre.
enum Theme {
    static let bg = Color(hex: 0x08080a)          // noir profond (OLED)
    static let surface = Color(hex: 0x141416)
    static let surface2 = Color(hex: 0x1b1b1e)
    static let line = Color.white.opacity(0.09)   // filet fin
    static let line2 = Color.white.opacity(0.14)
    static let txt = Color(hex: 0xf4f3ef)         // blanc cassé chaud
    static let muted = Color(hex: 0x8a8a8f)
    static let muted2 = Color(hex: 0x5c5c61)
    static let accent = Color(hex: 0xe7e3da)      // accent unique, quasi-blanc
    static let ok = Color(hex: 0x7fb08a)          // vert discret (validation)
}

/// Pastilles de couleur *sobres* pour différencier discrètement groupes et
/// events. Les noms de cas restent stables (persistance) ; seules les teintes
/// ont été assagies — plus d'arc-en-ciel.
enum Colorway: String, CaseIterable, Codable, Identifiable {
    case aurora, sunset, ocean, forest, candy, gold

    var id: String { rawValue }

    /// Couleur unie de la pastille.
    var primary: Color {
        switch self {
        case .aurora: return Color(hex: 0x5b6b82)   // ardoise bleutée
        case .sunset: return Color(hex: 0xa07d64)   // argile
        case .ocean:  return Color(hex: 0x6b7280)   // gris-bleu
        case .forest: return Color(hex: 0x7d8a72)   // sauge
        case .candy:  return Color(hex: 0x9b7280)   // vieux rose
        case .gold:   return Color(hex: 0x8a8560)   // olive
        }
    }

    var label: String {
        switch self {
        case .aurora: return "Ardoise"
        case .sunset: return "Argile"
        case .ocean:  return "Gris-bleu"
        case .forest: return "Sauge"
        case .candy:  return "Vieux rose"
        case .gold:   return "Olive"
        }
    }

    /// Dégradé très resserré (deux nuances proches) — usage rare, jamais criard.
    var gradient: LinearGradient {
        LinearGradient(colors: [primary.opacity(0.95), primary.opacity(0.65)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
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

/// Surface plate à filet fin — la brique visuelle sobre (remplace le verre).
struct SurfaceCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Theme.surface,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}
