import Foundation
import UIKit
import Photos
import Vision

/// Abstractions des services pour permettre l'injection de dépendances et les
/// tests unitaires (chaque service concret est remplaçable par un mock).

protocol PhotoLibraryProviding: Sendable {
    var isAuthorized: Bool { get }
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchAllPhotos() -> [PhotoAsset]
    func loadImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage
    func loadOriginalData(for asset: PHAsset) async throws -> (data: Data, uti: String?)
}

extension PhotoLibraryProviding {
    /// Charge une image à une taille adaptée à l'analyse Vision.
    func loadImage(for asset: PHAsset) async throws -> UIImage {
        try await loadImage(for: asset, targetSize: CGSize(width: 1024, height: 1024))
    }
}

protocol FaceDetecting: Sendable {
    func faceFeaturePrints(in image: UIImage) throws -> [VNFeaturePrintObservation]
    func referenceFeaturePrint(from image: UIImage) throws -> VNFeaturePrintObservation
}

protocol FaceMatching: AnyObject, Sendable {
    var threshold: Float { get set }
    var hasReference: Bool { get }
    func setReference(_ print: VNFeaturePrintObservation)
    func match(against prints: [VNFeaturePrintObservation]) -> (isMatch: Bool, distance: Float)?
}

protocol PhotoUploading: Sendable {
    /// Upload les données vers le stockage. Renvoie le chemin distant `bucket/objet`.
    func upload(data: Data, fileName: String, contentType: String) async throws -> String
    /// Génère une URL signée temporaire pour partager l'objet `bucket/objet`.
    func createSignedURL(path: String, expiresIn: Int) async throws -> URL
}

protocol SharedPhotosStoring: AnyObject {
    var sharedIDs: Set<String> { get }
    func contains(_ id: String) -> Bool
    func markShared(_ id: String)
    func reset()
}
