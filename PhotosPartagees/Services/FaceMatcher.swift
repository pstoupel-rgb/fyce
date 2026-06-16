import Foundation
import Vision

/// Compare des visages à un visage de référence à l'aide des feature prints Vision.
final class FaceMatcher: FaceMatching, @unchecked Sendable {

    /// Empreinte du visage de référence (le tien).
    private(set) var reference: VNFeaturePrintObservation?

    /// Seuil de distance en dessous duquel un visage est considéré comme un match.
    /// Plus la valeur est basse, plus le matching est strict. À calibrer selon
    /// tes photos (typiquement entre 0.4 et 0.8 pour les feature prints d'image).
    var threshold: Float = 0.6

    func setReference(_ print: VNFeaturePrintObservation) {
        self.reference = print
    }

    var hasReference: Bool { reference != nil }

    /// Renvoie la plus petite distance entre le visage de référence et les
    /// empreintes fournies, ou `nil` si aucune empreinte n'est comparable.
    func bestDistance(against prints: [VNFeaturePrintObservation]) -> Float? {
        guard let reference else { return nil }
        var best: Float?
        for print in prints {
            var distance: Float = 0
            do {
                try reference.computeDistance(&distance, to: print)
            } catch {
                continue
            }
            if best == nil || distance < best! {
                best = distance
            }
        }
        return best
    }

    /// Indique si l'une des empreintes correspond au visage de référence et
    /// renvoie la meilleure distance le cas échéant.
    func match(against prints: [VNFeaturePrintObservation]) -> (isMatch: Bool, distance: Float)? {
        guard let distance = bestDistance(against: prints) else { return nil }
        return (distance <= threshold, distance)
    }
}
