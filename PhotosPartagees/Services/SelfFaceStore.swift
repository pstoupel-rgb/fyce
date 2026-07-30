import Foundation
import os

/// Persiste **ta** signature de visage (celle de l'onglet « Moi »), chiffrée au
/// repos. Sert au « mode event » : matcher les photos d'un event contre ton
/// visage, entièrement sur ton téléphone.
@MainActor
final class SelfFaceStore: ObservableObject {
    static let shared = SelfFaceStore()

    @Published private(set) var hasFace: Bool
    private let key = "self_face_v2"   // v2 : FaceSignature (Codable)
    private let defaults = UserDefaults.standard

    init() {
        hasFace = defaults.data(forKey: key) != nil
    }

    var referencePrint: FaceSignature? {
        guard let sealed = defaults.data(forKey: key),
              let blob = CryptoBox.open(sealed) else { return nil }
        return try? JSONDecoder().decode(FaceSignature.self, from: blob)
    }

    func setFace(_ signature: FaceSignature) {
        guard let blob = try? JSONEncoder().encode(signature),
              let sealed = CryptoBox.seal(blob) else { return }
        defaults.set(sealed, forKey: key)
        hasFace = true
    }

    func clear() {
        defaults.removeObject(forKey: key)
        hasFace = false
    }
}
