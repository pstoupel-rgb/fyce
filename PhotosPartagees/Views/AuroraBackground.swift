import SwiftUI

/// Fond « aurora » animé : des halos de couleur qui dérivent lentement derrière
/// le verre. C'est la signature vivante de l'app — discret mais premium.
struct AuroraBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            blob(Theme.accent, size: 360)
                .offset(x: animate ? -120 : -80, y: animate ? -220 : -260)
            blob(Theme.accent2, size: 320)
                .offset(x: animate ? 140 : 100, y: animate ? -120 : -60)
            blob(Color(hex: 0xec4899), size: 300)
                .offset(x: animate ? -100 : -140, y: animate ? 260 : 300)
            blob(Color(hex: 0x22c55e).opacity(0.7), size: 240)
                .offset(x: animate ? 150 : 120, y: animate ? 280 : 240)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 90)
            .opacity(0.45)
    }
}
