import Foundation

/// Compare des visages à un visage de référence via les `FaceSignature`.
final class FaceMatcher: FaceMatching, @unchecked Sendable {

    private(set) var reference: FaceSignature?

    /// Seuil de distance en dessous duquel un visage est un match. À calibrer
    /// selon le backend (Vision ≈ 0.4–0.8 ; un modèle Core ML dédié demande sa
    /// propre calibration).
    var threshold: Float = 0.6

    func setReference(_ signature: FaceSignature) {
        self.reference = signature
    }

    var hasReference: Bool { reference != nil }

    func bestDistance(against signatures: [FaceSignature]) -> Float? {
        guard let reference else { return nil }
        var best: Float?
        for sig in signatures {
            let distance = reference.distance(to: sig)
            if best == nil || distance < best! { best = distance }
        }
        return best
    }

    func match(against signatures: [FaceSignature]) -> (isMatch: Bool, distance: Float)? {
        guard let distance = bestDistance(against: signatures) else { return nil }
        return (distance <= threshold, distance)
    }
}
