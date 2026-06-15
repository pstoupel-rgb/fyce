import Foundation
import Vision
import UIKit
import CoreImage

/// Encapsule les requêtes Vision : détection des visages dans une image et
/// génération d'une empreinte (`VNFeaturePrintObservation`) par visage recadré.
///
/// Note : Vision n'expose pas d'API publique d'embedding facial. On utilise donc
/// `VNGenerateImageFeaturePrintRequest` sur le visage recadré comme empreinte
/// comparable. C'est une approximation raisonnable, remplaçable par un modèle
/// Core ML de reconnaissance faciale pour gagner en précision.
final class FaceDetectionService {

    enum FaceError: LocalizedError {
        case noFaceFound
        case invalidImage
        case featurePrintFailed

        var errorDescription: String? {
            switch self {
            case .noFaceFound: return "Aucun visage détecté."
            case .invalidImage: return "Image invalide."
            case .featurePrintFailed: return "Échec du calcul de l'empreinte du visage."
            }
        }
    }

    private let ciContext = CIContext()

    /// Détecte les visages d'une image et renvoie une empreinte par visage.
    func faceFeaturePrints(in image: UIImage) throws -> [VNFeaturePrintObservation] {
        guard let cgImage = image.cgImage else { throw FaceError.invalidImage }

        let orientation = cgImageOrientation(from: image.imageOrientation)
        let faceObservations = try detectFaces(in: cgImage, orientation: orientation)
        guard !faceObservations.isEmpty else { throw FaceError.noFaceFound }

        let ciImage = CIImage(cgImage: cgImage)
        var prints: [VNFeaturePrintObservation] = []

        for face in faceObservations {
            guard let cropped = cropFace(face, from: ciImage, imageSize: cgImage.size) else { continue }
            if let print = try? featurePrint(for: cropped) {
                prints.append(print)
            }
        }
        return prints
    }

    /// Génère l'empreinte d'un visage de référence (échoue si aucun visage).
    func referenceFeaturePrint(from image: UIImage) throws -> VNFeaturePrintObservation {
        let prints = try faceFeaturePrints(in: image)
        guard let first = prints.first else { throw FaceError.featurePrintFailed }
        return first
    }

    // MARK: - Étapes Vision

    private func detectFaces(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        return request.results ?? []
    }

    private func featurePrint(for ciImage: CIImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])
        guard let result = request.results?.first else { throw FaceError.featurePrintFailed }
        return result
    }

    // MARK: - Recadrage

    /// Recadre le visage à partir de la bounding box normalisée Vision, avec une
    /// petite marge, et renvoie une `CIImage`.
    private func cropFace(_ face: VNFaceObservation, from ciImage: CIImage, imageSize: CGSize) -> CIImage? {
        // Vision : origine en bas-gauche, coordonnées normalisées.
        let bbox = face.boundingBox
        var rect = CGRect(
            x: bbox.origin.x * imageSize.width,
            y: bbox.origin.y * imageSize.height,
            width: bbox.width * imageSize.width,
            height: bbox.height * imageSize.height
        )

        // Marge de 20 % autour du visage.
        let inset = -0.2
        rect = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)
        rect = rect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !rect.isNull, rect.width > 10, rect.height > 10 else { return nil }

        return ciImage.cropped(to: rect)
    }

    private func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

private extension CGImage {
    var size: CGSize { CGSize(width: width, height: height) }
}
