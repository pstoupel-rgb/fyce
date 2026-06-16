import Foundation

/// Valeurs de connexion Supabase, lues depuis l'Info.plist (alimenté par
/// `Config/Secrets.xcconfig`, non commité). Voir `Config/Secrets.example.xcconfig`.
///
/// ⚠️ Ne committe jamais une clé `service_role` dans une app cliente. Utilise la
/// clé `anon` + des règles RLS, ou un endpoint d'upload signé côté serveur.
enum SupabaseConfig {
    /// URL du projet, ex. `https://abcdxyz.supabase.co` (construite depuis l'hôte
    /// pour contourner la gestion des `//` en commentaire dans les xcconfig).
    static let url: URL = {
        if let host = infoValue("SUPABASE_HOST"), let url = URL(string: "https://\(host)") {
            return url
        }
        return URL(string: "https://YOUR-PROJECT-REF.supabase.co")!
    }()

    static let anonKey = infoValue("SUPABASE_ANON_KEY") ?? "YOUR-ANON-KEY"
    static let bucket = infoValue("SUPABASE_BUCKET") ?? "shared-photos"

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Configuration injectable (facilite les tests du `SupabaseService`).
struct SupabaseConfiguration: Sendable {
    let url: URL
    let anonKey: String
    let bucket: String

    var isConfigured: Bool {
        !anonKey.contains("YOUR-") && !url.absoluteString.contains("YOUR-")
    }

    static var current: SupabaseConfiguration {
        SupabaseConfiguration(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey, bucket: SupabaseConfig.bucket)
    }
}
