import SwiftUI
import UIKit

/// Compose une image d'impression **brandée** à l'event (logo ou nom + petite
/// marque Poze), et l'envoie à l'impression via AirPrint. Utilisé pour la
/// « sharing box » : impression gratuite, téléchargement HD payant.
enum PrintComposer {

    /// Rend la photo avec un bandeau brandé, prête à imprimer.
    @MainActor
    static func brandedImage(photo: UIImage, event: PozeEvent) -> UIImage? {
        let renderer = ImageRenderer(content: PrintCard(photo: photo, event: event))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Ouvre la feuille d'impression système (AirPrint) avec une ou plusieurs images.
    @MainActor
    static func print(_ images: [UIImage], jobName: String) {
        guard !images.isEmpty else { return }
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .photo
        info.jobName = jobName
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItems = images
        controller.present(animated: true, completionHandler: nil)
    }
}

/// Carte imprimable : photo + bandeau event (logo/nom) + marque Poze discrète.
private struct PrintCard: View {
    let photo: UIImage
    let event: PozeEvent

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: photo)
                .resizable().scaledToFit()
                .frame(width: 1200)
            HStack(spacing: 14) {
                if let logo = event.logoImage {
                    Image(uiImage: logo).resizable().scaledToFit().frame(height: 64)
                } else {
                    Text(event.name).font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 20)).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 6) {
                        ApertureMark(color: .white).frame(width: 22, height: 22)
                        Text("poze").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 40)
            .frame(width: 1200, height: 150)
            .background(event.colorway.primary)
        }
        .frame(width: 1200)
        .background(Color.black)
    }
}
