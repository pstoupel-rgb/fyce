import Foundation
import Vision

/// Matching d'event **sur l'appareil** (Option B) : le photographe publie des
/// empreintes *anonymes* (aucune identité) ; ton téléphone les compare à ton
/// propre visage. Aucun selfie, aucune reconnaissance côté serveur.
enum EventFaceMatcher {

    /// Empreinte → base64 (transmise dans l'event, sans nom ni identité).
    static func encode(_ print: VNFeaturePrintObservation) -> String? {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: print, requiringSecureCoding: true) else { return nil }
        return data.base64EncodedString()
    }

    /// base64 → empreinte (reconstruite sur le téléphone de l'invité).
    static func decode(_ b64: String) -> VNFeaturePrintObservation? {
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: VNFeaturePrintObservation.self, from: data)
    }

    /// L'empreinte d'un visage de l'event correspond-elle à l'un de tes visages ?
    static func isMine(_ facePrint: VNFeaturePrintObservation,
                       selfPrints: [VNFeaturePrintObservation],
                       threshold: Float = 0.6) -> Bool {
        for ref in selfPrints {
            var distance: Float = 0
            if (try? ref.computeDistance(&distance, to: facePrint)) != nil, distance <= threshold {
                return true
            }
        }
        return false
    }
}
