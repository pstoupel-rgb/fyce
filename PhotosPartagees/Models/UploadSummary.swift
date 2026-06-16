import Foundation

/// Récapitulatif affiché à la fin d'un partage.
struct UploadSummary: Identifiable, Equatable {
    let id = UUID()
    let succeeded: Int
    let failed: Int

    var total: Int { succeeded + failed }
    var hasFailures: Bool { failed > 0 }
}
