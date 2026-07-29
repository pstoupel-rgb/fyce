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

    /// Protection des mineurs : si la personne est mineure, le consentement d'un
    /// parent/tuteur est requis avant tout usage (recherche, partage). On conserve
    /// une attestation + un contact — jamais de biométrie de l'enfant hors appareil.
    var isMinor: Bool
    var parentalConsent: Bool
    var parentContact: String?
    /// Identifiant du compte serveur de cet ami, une fois qu'il a rejoint Poze
    /// (via ton lien/QR). Permet à la « notif magique » de cibler la bonne personne.
    var remoteUserID: String?

    init(id: UUID = UUID(),
         name: String,
         referencePrint: VNFeaturePrintObservation,
         thumbnail: UIImage? = nil,
         isMinor: Bool = false,
         parentalConsent: Bool = false,
         parentContact: String? = nil,
         remoteUserID: String? = nil) {
        self.id = id
        self.name = name
        self.referencePrint = referencePrint
        self.thumbnail = thumbnail
        self.isMinor = isMinor
        self.parentalConsent = parentalConsent
        self.parentContact = parentContact
        self.remoteUserID = remoteUserID
    }

    /// Utilisable pour la recherche/partage : un mineur exige le consentement.
    var isUsable: Bool { !isMinor || parentalConsent }
}
