import Foundation
import Vision

/// Matcher multi-références : correspond si l'un des visages de la photo est
/// proche de **n'importe laquelle** des empreintes de référence (les membres d'un
/// groupe ou d'un event). On garde la meilleure (plus petite) distance trouvée.
final class MultiFaceMatcher: FaceMatching, @unchecked Sendable {

    private var references: [VNFeaturePrintObservation]
    var threshold: Float = 0.6

    init(references: [VNFeaturePrintObservation], threshold: Float = 0.6) {
        self.references = references
        self.threshold = threshold
    }

    var hasReference: Bool { !references.isEmpty }

    /// Remplace l'ensemble des références par une seule (conformité au protocole).
    func setReference(_ print: VNFeaturePrintObservation) {
        references = [print]
    }

    func match(against prints: [VNFeaturePrintObservation]) -> (isMatch: Bool, distance: Float)? {
        guard !references.isEmpty else { return nil }
        var best: Float?
        for reference in references {
            for print in prints {
                var distance: Float = 0
                guard (try? reference.computeDistance(&distance, to: print)) != nil else { continue }
                if best == nil || distance < best! { best = distance }
            }
        }
        guard let best else { return nil }
        return (best <= threshold, best)
    }
}
