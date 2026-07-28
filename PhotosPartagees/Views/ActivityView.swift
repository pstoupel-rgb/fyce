import SwiftUI
import UIKit

/// Enveloppe `UIActivityViewController` pour partager images/liens depuis SwiftUI
/// (la feuille de partage native iOS : Messages, WhatsApp, AirDrop, Mail…).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
