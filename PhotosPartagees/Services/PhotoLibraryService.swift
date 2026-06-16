import Foundation
import Photos
import UIKit

/// Accès à la photothèque via PhotoKit : autorisation, énumération et
/// chargement des images.
final class PhotoLibraryService: PhotoLibraryProviding, @unchecked Sendable {

    enum PhotoLibraryError: LocalizedError {
        case accessDenied
        case imageLoadFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Accès à la photothèque refusé. Autorisez-le dans Réglages."
            case .imageLoadFailed:
                return "Impossible de charger l'image."
            }
        }
    }

    private let imageManager = PHImageManager.default()

    /// Demande l'autorisation de lecture de la photothèque.
    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Récupère tous les assets image, triés du plus récent au plus ancien.
    func fetchAllPhotos() -> [PhotoAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var photos: [PhotoAsset] = []
        photos.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            photos.append(PhotoAsset(asset: asset))
        }
        return photos
    }

    /// Charge une image à une taille cible, optimisée pour l'analyse Vision.
    /// On évite le plein format pour limiter la mémoire pendant le scan.
    func loadImage(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 1024, height: 1024)
    ) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Le callback peut être appelé deux fois (low-res puis high-res).
                // On ne reprend qu'avec une image définitive.
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PhotoLibraryError.imageLoadFailed)
                }
            }
        }
    }

    /// Charge les données image originales (pleine résolution) pour l'upload.
    func loadOriginalData(for asset: PHAsset) async throws -> (data: Data, uti: String?) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                if let data {
                    continuation.resume(returning: (data, uti))
                } else {
                    continuation.resume(throwing: PhotoLibraryError.imageLoadFailed)
                }
            }
        }
    }
}
