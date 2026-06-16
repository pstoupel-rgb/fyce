import Foundation
import UIKit
import os

/// Résultat d'analyse d'une photo (type valeur transférable entre tâches).
struct ScanMatch: Sendable, Equatable {
    let id: String          // PHAsset.localIdentifier
    let distance: Float
}

/// Analyse une photo hors du main thread : chargement → détection de visages →
/// comparaison au visage de référence. Conçu pour être exécuté en parallèle.
///
/// `@unchecked Sendable` : les dépendances encapsulent des frameworks
/// thread-safe (PhotoKit, Vision) et ne sont lues qu'en lecture pendant le scan.
final class FaceScanner: @unchecked Sendable {
    private let photoLibrary: PhotoLibraryProviding
    private let faceDetection: FaceDetecting
    private let matcher: FaceMatching

    init(photoLibrary: PhotoLibraryProviding, faceDetection: FaceDetecting, matcher: FaceMatching) {
        self.photoLibrary = photoLibrary
        self.faceDetection = faceDetection
        self.matcher = matcher
    }

    func analyze(_ photo: PhotoAsset) async -> ScanMatch? {
        do {
            let image = try await photoLibrary.loadImage(for: photo.asset)
            let prints = try faceDetection.faceFeaturePrints(in: image)
            guard let result = matcher.match(against: prints), result.isMatch else { return nil }
            return ScanMatch(id: photo.id, distance: result.distance)
        } catch {
            Logger.vision.debug("Analyse ignorée pour \(photo.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
