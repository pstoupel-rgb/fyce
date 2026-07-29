import Foundation

/// Transparence réseau : compte ce que l'app a réellement envoyé pendant la
/// session. Sert la preuve « 0 photo envoyée » — la confiance rendue vérifiable.
///
/// Seules **nos** requêtes d'upload sont comptées (les seules qui envoient des
/// photos, et uniquement celles que tu as choisi de partager).
///
/// Non isolé à un acteur : les mutations passent par `MainActor.run` côté
/// appelant (voir `SupabaseService`), et l'UI l'observe sur le main thread.
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var photosSent = 0
    @Published private(set) var bytesSent = 0

    /// Le backend est-il seulement configuré ? Sinon, l'app ne fait aucune requête.
    var isBackendConfigured: Bool { SupabaseConfiguration.current.isConfigured }

    func recordUpload(bytes: Int) {
        photosSent += 1
        bytesSent += bytes
    }

    /// Résumé lisible (ex. « 0 photo envoyée · mode local »).
    var summary: String {
        guard isBackendConfigured else { return "Aucune connexion réseau — mode 100 % local." }
        if photosSent == 0 { return "0 photo envoyée cette session." }
        let kb = Double(bytesSent) / 1024
        let size = kb > 1024 ? String(format: "%.1f Mo", kb / 1024) : String(format: "%.0f Ko", kb)
        return "\(photosSent) photo\(photosSent > 1 ? "s" : "") envoyée\(photosSent > 1 ? "s" : "") · \(size)"
    }
}
