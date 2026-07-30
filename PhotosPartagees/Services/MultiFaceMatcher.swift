import Foundation

/// Matcher multi-références : correspond si l'un des visages correspond à
/// **n'importe laquelle** des signatures de référence (membres d'un groupe/event).
final class MultiFaceMatcher: FaceMatching, @unchecked Sendable {

    private var references: [FaceSignature]
    var threshold: Float = 0.6

    init(references: [FaceSignature], threshold: Float = 0.6) {
        self.references = references
        self.threshold = threshold
    }

    var hasReference: Bool { !references.isEmpty }

    func setReference(_ signature: FaceSignature) {
        references = [signature]
    }

    func match(against signatures: [FaceSignature]) -> (isMatch: Bool, distance: Float)? {
        guard !references.isEmpty else { return nil }
        var best: Float?
        for reference in references {
            for sig in signatures {
                let distance = reference.distance(to: sig)
                if best == nil || distance < best! { best = distance }
            }
        }
        guard let best else { return nil }
        return (best <= threshold, best)
    }
}
