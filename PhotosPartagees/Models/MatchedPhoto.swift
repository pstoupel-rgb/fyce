import Foundation

/// Statut d'upload d'une photo matchée vers Supabase.
enum UploadStatus: Equatable {
    case pending
    case uploading
    case uploaded(remotePath: String)
    /// Déjà partagée lors d'un scan précédent (persistée localement).
    case alreadyShared
    case failed(message: String)

    /// Peut être (re)tentée : en attente ou en échec.
    var isUploadable: Bool {
        switch self {
        case .pending, .failed: return true
        case .uploading, .uploaded, .alreadyShared: return false
        }
    }
}

/// Une photo dont le visage correspond au visage de référence.
struct MatchedPhoto: Identifiable {
    let id: String                 // localIdentifier du PHAsset
    let photo: PhotoAsset
    /// Distance Vision la plus faible parmi les visages détectés (plus c'est bas, mieux c'est).
    let distance: Float
    /// Sélection de l'utilisateur : la photo sera partagée uniquement si `true`.
    var isSelected: Bool = true
    var uploadStatus: UploadStatus = .pending

    init(photo: PhotoAsset, distance: Float) {
        self.id = photo.id
        self.photo = photo
        self.distance = distance
    }
}
