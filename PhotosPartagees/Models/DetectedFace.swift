import Foundation
import UIKit

/// Un visage détecté dans une photo, pour le tagging manuel.
/// `boundingBox` est normalisé, origine **haut-gauche** (prêt pour un overlay SwiftUI).
struct DetectedFace: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let signature: FaceSignature
    let crop: UIImage?
}
