import Foundation

/// Matching d'event **sur l'appareil** (Option B) : le photographe publie des
/// signatures *anonymes* (aucune identité) ; ton téléphone les compare à ta
/// propre signature. Aucun selfie, aucune reconnaissance côté serveur.
enum EventFaceMatcher {

    /// Signature → base64 (transmise dans l'event, sans nom ni identité).
    static func encode(_ signature: FaceSignature) -> String? {
        signature.base64()
    }

    /// base64 → signature (reconstruite sur le téléphone de l'invité).
    static func decode(_ b64: String) -> FaceSignature? {
        FaceSignature.from(base64: b64)
    }

    /// La signature d'un visage de l'event correspond-elle à l'un de tes visages ?
    static func isMine(_ faceSignature: FaceSignature,
                       selfPrints: [FaceSignature],
                       threshold: Float = 0.6) -> Bool {
        for ref in selfPrints where ref.distance(to: faceSignature) <= threshold {
            return true
        }
        return false
    }
}
