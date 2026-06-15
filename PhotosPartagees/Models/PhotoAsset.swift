import Foundation
import Photos

/// Représente une photo de la photothèque candidate au scan.
struct PhotoAsset: Identifiable, Hashable {
    let id: String          // PHAsset.localIdentifier
    let asset: PHAsset

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
    }

    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
