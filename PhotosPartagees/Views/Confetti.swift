import SwiftUI

/// Petit système de particules maison (aucune dépendance) : un burst de confettis
/// sobres aux couleurs de la marque. Se déclenche à l'apparition, puis disparaît.
struct ConfettiView: View {
    var count: Int = 44

    private struct Piece {
        let angle: Double
        let distance: CGFloat
        let fall: CGFloat
        let size: CGFloat
        let rotation: Double
        let delay: Double
        let color: Color
        let circle: Bool
    }

    private let pieces: [Piece]
    @State private var go = false

    init(count: Int = 44) {
        self.count = count
        let palette: [Color] = [
            Color(hex: 0x7c5cff), Color(hex: 0x22d3ee), Color(hex: 0xec4899),
            Color(hex: 0x8a8560), Theme.txt
        ]
        var arr: [Piece] = []
        for _ in 0..<count {
            arr.append(Piece(
                angle: Double.random(in: 0..<(2 * .pi)),
                distance: CGFloat.random(in: 70...200),
                fall: CGFloat.random(in: 220...420),
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0..<720),
                delay: Double.random(in: 0...0.12),
                color: palette.randomElement() ?? Theme.txt,
                circle: Bool.random()
            ))
        }
        pieces = arr
    }

    var body: some View {
        ZStack {
            ForEach(pieces.indices, id: \.self) { i in
                let p = pieces[i]
                filledPiece(p)
                    .frame(width: p.size, height: p.size * (p.circle ? 1 : 0.6))
                    .offset(x: go ? cos(p.angle) * p.distance : 0,
                            y: go ? sin(p.angle) * p.distance + p.fall : 0)
                    .rotationEffect(.degrees(go ? p.rotation : 0))
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.5).delay(p.delay), value: go)
            }
        }
        .onAppear { go = true }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func filledPiece(_ p: Piece) -> some View {
        if p.circle {
            Circle().fill(p.color)
        } else {
            RoundedRectangle(cornerRadius: 2).fill(p.color)
        }
    }
}
