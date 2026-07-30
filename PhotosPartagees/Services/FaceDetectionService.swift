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
final class FaceDetectionService: FaceDetecting, @unchecked Sendable {

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

    /// Détecte les visages d'une image et renvoie une **signature** par visage
    /// (Core ML si dispo, sinon Vision).
    func faceFeaturePrints(in image: UIImage) throws -> [FaceSignature] {
        guard let cgImage = image.cgImage else { throw FaceError.invalidImage }

        let orientation = cgImageOrientation(from: image.imageOrientation)
        let faceObservations = try detectFaces(in: cgImage, orientation: orientation)
        guard !faceObservations.isEmpty else { throw FaceError.noFaceFound }

        let ciImage = CIImage(cgImage: cgImage)
        var signatures: [FaceSignature] = []

        for face in faceObservations {
            guard let cropped = cropFace(face, from: ciImage, imageSize: cgImage.size) else { continue }
            if let sig = FaceEmbedder.shared.signature(for: cropped) {
                signatures.append(sig)
            }
        }
        return signatures
    }

    /// Signature d'un visage de référence (échoue si aucun visage).
    func referenceFeaturePrint(from image: UIImage) throws -> FaceSignature {
        let signatures = try faceFeaturePrints(in: image)
        guard let first = signatures.first else { throw FaceError.featurePrintFailed }
        return first
    }

    /// Détecte les visages avec leur position (pour l'écran de tagging manuel) :
    /// bounding box normalisée **origine haut-gauche** (prête pour SwiftUI),
    /// signature, et vignette recadrée.
    func detectedFaces(in image: UIImage) throws -> [DetectedFace] {
        guard let cgImage = image.cgImage else { throw FaceError.invalidImage }
        let orientation = cgImageOrientation(from: image.imageOrientation)
        let faces = try detectFaces(in: cgImage, orientation: orientation)
        let ciImage = CIImage(cgImage: cgImage)

        var results: [DetectedFace] = []
        for face in faces {
            let b = face.boundingBox   // normalisé, origine bas-gauche
            let box = CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
            guard let cropped = cropFace(face, from: ciImage, imageSize: cgImage.size),
                  let sig = FaceEmbedder.shared.signature(for: cropped) else { continue }
            var crop: UIImage?
            if let cg = ciContext.createCGImage(cropped, from: cropped.extent) {
                crop = UIImage(cgImage: cg)
            }
            results.append(DetectedFace(boundingBox: box, signature: sig, crop: crop))
        }
        return results
    }

    // MARK: - Étapes Vision

    private func detectFaces(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        return request.results ?? []
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
