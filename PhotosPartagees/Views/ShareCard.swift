import SwiftUI
import UIKit

/// Carte de partage (récap) — un visuel de marque à poster pour faire connaître
/// Poze. **Aucune vraie photo** : que la marque, un chiffre, la promesse. Cohérent
/// avec la confidentialité, et parfait pour une story.
struct ShareCard: View {
    let bigNumber: Int
    let line1: String
    let line2: String

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.bg)
            RadialGradient(
                colors: [Color(hex: 0x7c5cff).opacity(0.5), Color(hex: 0x5b46b0).opacity(0.14), .clear],
                center: UnitPoint(x: 0.76, y: 0.12), startRadius: 0, endRadius: 380)

            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    ApertureMark(color: Theme.txt).frame(width: 26, height: 26)
                    Wordmark(size: 22)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 30).padding(.horizontal, 30)

                Spacer()

                Text("\(bigNumber)")
                    .font(.system(size: 116, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.txt)
                Text(line1)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .multilineTextAlignment(.center)
                Text(line2)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 5)

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: "lock.fill").font(.system(size: 12))
                    Text("100 % sur ton téléphone · poze")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 360, height: 450)
    }
}

/// Rend une `ShareCard` en image partageable (ImageRenderer, iOS 16+).
enum ShareCardRenderer {
    @MainActor
    static func image(_ card: ShareCard) -> UIImage? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
