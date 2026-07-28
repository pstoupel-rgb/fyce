import Foundation
import Vision
import UIKit

/// Un ami : nom + empreinte de visage de référence (matching 100 % on-device).
/// L'empreinte (`VNFeaturePrintObservation`) et la miniature sont archivables
/// via `NSSecureCoding`, ce qui permet la persistance locale (voir `FriendStore`).
final class Friend: Identifiable {
    let id: UUID
    var name: String
    var thumbnail: UIImage?
    let referencePrint: VNFeaturePrintObservation

    init(id: UUID = UUID(),
         name: String,
         referencePrint: VNFeaturePrintObservation,
         thumbnail: UIImage? = nil) {
        self.id = id
        self.name = name
        self.referencePrint = referencePrint
        self.thumbnail = thumbnail
    }
}
