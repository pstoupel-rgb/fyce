import SwiftUI

/// Le symbole Poze (diaphragme d'objectif) dessiné nativement — recolorable et
/// animable. Même géométrie que l'icône d'app (iris 6 lames dans un carré 256).
struct ApertureMark: View {
    var color: Color = Theme.txt

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 256
            ZStack {
                Circle()
                    .inset(by: 28 * s)
                    .stroke(color.opacity(0.92), lineWidth: 10 * s)
                ApertureBlades()
                    .stroke(color, style: StrokeStyle(lineWidth: 12 * s, lineCap: .round, lineJoin: .round))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Les 6 lames de l'iris (chordes égales décalées → moulin à vent).
private struct ApertureBlades: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 256
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        let lines: [((CGFloat, CGFloat), (CGFloat, CGFloat))] = [
            ((51.40, 63.72), (204.60, 63.72)),
            ((145.37, 29.52), (221.97, 162.20)),
            ((221.97, 93.80), (145.37, 226.48)),
            ((204.60, 192.28), (51.40, 192.28)),
            ((110.63, 226.48), (34.03, 93.80)),
            ((34.03, 162.20), (110.63, 29.52))
        ]
        var path = Path()
        for (a, b) in lines {
            path.move(to: p(a.0, a.1))
            path.addLine(to: p(b.0, b.1))
        }
        return path
    }
}

/// Fond « halo violet » cohérent avec l'icône d'app : noir profond + lueur violette
/// en haut à droite. Réutilisé sur le splash, l'onboarding et la connexion.
struct HaloBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Color(hex: 0x7c5cff).opacity(0.34), Color(hex: 0x5b46b0).opacity(0.10), .clear],
                center: UnitPoint(x: 0.72, y: 0.16),
                startRadius: 0, endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

/// Écran de lancement animé : le diaphragme « s'ouvre » sur le halo, puis laisse
/// place à l'app. Donne une continuité directe avec l'icône.
struct SplashView: View {
    @State private var open = false

    var body: some View {
        ZStack {
            HaloBackground()
            VStack(spacing: 22) {
                ApertureMark(color: Theme.txt)
                    .frame(width: 116, height: 116)
                    .rotationEffect(.degrees(open ? 0 : -55))
                    .scaleEffect(open ? 1 : 0.65)
                    .opacity(open ? 1 : 0)
                Wordmark(size: 34)
                    .opacity(open ? 1 : 0)
                    .offset(y: open ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.72)) { open = true }
        }
    }
}
