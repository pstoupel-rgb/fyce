import Foundation

/// Statut d'upload d'une photo matchée vers Supabase.
enum UploadStatus: Equatable {
    case pending
    case uploading
    case uploaded(remotePath: String)
    case failed(message: String)
}

/// Une photo dont le visage correspond au visage de référence.
struct MatchedPhoto: Identifiable {
    let id: String                 // localIdentifier du PHAsset
    let photo: PhotoAsset
    /// Distance Vision la plus faible parmi les visages détectés (plus c'est bas, mieux c'est).
    let distance: Float
    var uploadStatus: UploadStatus = .pending

    init(photo: PhotoAsset, distance: Float) {
        self.id = photo.id
        self.photo = photo
        self.distance = distance
    }
}
