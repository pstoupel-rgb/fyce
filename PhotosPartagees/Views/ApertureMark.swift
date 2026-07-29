import SwiftUI

/// Le symbole Poze (diaphragme d'objectif) dessiné nativement — recolorable et
/// animable. Même géométrie que l'icône d'app (iris 6 lames dans un carré 256).
///
/// `reveal` (0 → 1) anime l'ouverture : le cercle se trace, puis les lames
/// apparaissent l'une après l'autre en s'ouvrant (scale + rotation).
struct ApertureMark: View {
    var color: Color = Theme.txt
    var reveal: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 256
            ZStack {
                Circle()
                    .inset(by: 28 * s)
                    .trim(from: 0, to: reveal)
                    .stroke(color.opacity(0.92), style: StrokeStyle(lineWidth: 10 * s, lineCap: .round))
                    .rotationEffect(.degrees(-90))   // départ du tracé en haut
                ApertureBlades()
                    .trim(from: 0, to: reveal)
                    .stroke(color, style: StrokeStyle(lineWidth: 12 * s, lineCap: .round, lineJoin: .round))
                    .scaleEffect(0.55 + 0.45 * reveal)
                    .rotationEffect(.degrees(Double(1 - reveal) * -45))
                    .opacity(Double(reveal))
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

/// Écran de lancement animé : le diaphragme s'ouvre lame par lame sur le halo,
/// puis le mot-symbole apparaît. Continuité directe avec l'icône d'app.
struct SplashView: View {
    @State private var reveal: CGFloat = 0
    @State private var showText = false

    var body: some View {
        ZStack {
            HaloBackground()
            VStack(spacing: 22) {
                ApertureMark(color: Theme.txt, reveal: reveal)
                    .frame(width: 118, height: 118)
                Wordmark(size: 34)
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.95)) { reveal = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) { showText = true }
        }
    }
}
