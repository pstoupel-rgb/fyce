import Foundation
import UIKit

/// Un ami : nom + une ou **plusieurs** signatures de visage de référence
/// (matching 100 % on-device). Plusieurs références = meilleure précision. Le
/// tagging manuel d'un visage ajoute une référence (l'app apprend).
final class Friend: Identifiable {
    let id: UUID
    var name: String
    var thumbnail: UIImage?
    private(set) var referencePrints: [FaceSignature]

    /// Protection des mineurs : consentement parental requis avant tout usage.
    var isMinor: Bool
    var parentalConsent: Bool
    var parentContact: String?
    /// Compte serveur de cet ami (une fois qu'il a rejoint Poze) — pour cibler la
    /// « notif magique ».
    var remoteUserID: String?

    init(id: UUID = UUID(),
         name: String,
         referencePrints: [FaceSignature],
         thumbnail: UIImage? = nil,
         isMinor: Bool = false,
         parentalConsent: Bool = false,
         parentContact: String? = nil,
         remoteUserID: String? = nil) {
        self.id = id
        self.name = name
        self.referencePrints = referencePrints
        self.thumbnail = thumbnail
        self.isMinor = isMinor
        self.parentalConsent = parentalConsent
        self.parentContact = parentContact
        self.remoteUserID = remoteUserID
    }

    /// Convenance : ami à une seule référence.
    convenience init(id: UUID = UUID(),
                     name: String,
                     referencePrint: FaceSignature,
                     thumbnail: UIImage? = nil,
                     isMinor: Bool = false,
                     parentalConsent: Bool = false,
                     parentContact: String? = nil,
                     remoteUserID: String? = nil) {
        self.init(id: id, name: name, referencePrints: [referencePrint], thumbnail: thumbnail,
                  isMinor: isMinor, parentalConsent: parentalConsent,
                  parentContact: parentContact, remoteUserID: remoteUserID)
    }

    var referencePrint: FaceSignature? { referencePrints.first }

    func addReference(_ signature: FaceSignature) {
        referencePrints.append(signature)
    }

    var isUsable: Bool { !isMinor || parentalConsent }
}
