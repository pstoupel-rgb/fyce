import Foundation
import Vision
import os

/// Persiste **ton** empreinte de visage (celle de l'onglet « Moi »), chiffrée au
/// repos. Sert au « mode event » : matcher les photos d'un event contre ton
/// visage, entièrement sur ton téléphone.
@MainActor
final class SelfFaceStore: ObservableObject {
    static let shared = SelfFaceStore()

    @Published private(set) var hasFace: Bool
    private let key = "self_face_v1"
    private let defaults = UserDefaults.standard

    init() {
        hasFace = defaults.data(forKey: key) != nil
    }

    var referencePrint: VNFeaturePrintObservation? {
        guard let sealed = defaults.data(forKey: key),
              let blob = CryptoBox.open(sealed),
              let print = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self, from: blob) else { return nil }
        return print
    }

    func setFace(_ print: VNFeaturePrintObservation) {
        guard let blob = try? NSKeyedArchiver.archivedData(
                withRootObject: print, requiringSecureCoding: true),
              let sealed = CryptoBox.seal(blob) else { return }
        defaults.set(sealed, forKey: key)
        hasFace = true
    }

    func clear() {
        defaults.removeObject(forKey: key)
        hasFace = false
    }
}
