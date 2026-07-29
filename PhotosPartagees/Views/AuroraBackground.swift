import SwiftUI

/// Fond sobre : noir profond, avec un halo très discret en haut pour éviter le
/// « trou noir » total. Aucune animation — le mouvement est réservé au geste clé
/// (le swipe). Le nom est conservé pour compatibilité avec les vues existantes.
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Color.white.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}
