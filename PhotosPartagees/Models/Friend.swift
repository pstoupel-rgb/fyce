import Foundation
import Vision
import UIKit

/// Un ami : nom + une ou **plusieurs** empreintes de visage de référence
/// (matching 100 % on-device). Plusieurs références = meilleure précision : on
/// compare à chacune et on garde la meilleure correspondance. Le tagging manuel
/// d'un visage ajoute une référence (l'app apprend).
final class Friend: Identifiable {
    let id: UUID
    var name: String
    var thumbnail: UIImage?
    private(set) var referencePrints: [VNFeaturePrintObservation]

    /// Protection des mineurs : consentement parental requis avant tout usage.
    var isMinor: Bool
    var parentalConsent: Bool
    var parentContact: String?
    /// Compte serveur de cet ami (une fois qu'il a rejoint Poze) — pour cibler la
    /// « notif magique ».
    var remoteUserID: String?

    init(id: UUID = UUID(),
         name: String,
         referencePrints: [VNFeaturePrintObservation],
         thumbnail: UIImage? = nil,
         isMinor: Bool = false,
         parentalConsent: Bool = false,
         parentContact: String? = nil,
         remoteUserID: String? = nil) {
        self.id = id
        self.name = name
        self.referencePrints = referencePrints.isEmpty ? [] : referencePrints
        self.thumbnail = thumbnail
        self.isMinor = isMinor
        self.parentalConsent = parentalConsent
        self.parentContact = parentContact
        self.remoteUserID = remoteUserID
    }

    /// Convenance : ami à une seule référence.
    convenience init(id: UUID = UUID(),
                     name: String,
                     referencePrint: VNFeaturePrintObservation,
                     thumbnail: UIImage? = nil,
                     isMinor: Bool = false,
                     parentalConsent: Bool = false,
                     parentContact: String? = nil,
                     remoteUserID: String? = nil) {
        self.init(id: id, name: name, referencePrints: [referencePrint], thumbnail: thumbnail,
                  isMinor: isMinor, parentalConsent: parentalConsent,
                  parentContact: parentContact, remoteUserID: remoteUserID)
    }

    /// Première référence (compat / usage simple).
    var referencePrint: VNFeaturePrintObservation? { referencePrints.first }

    /// Ajoute une empreinte de référence (tagging manuel → apprentissage).
    func addReference(_ print: VNFeaturePrintObservation) {
        referencePrints.append(print)
    }

    var isUsable: Bool { !isMinor || parentalConsent }
}
