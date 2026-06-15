import Foundation

/// Configuration de connexion à Supabase.
///
/// ⚠️ Ne committe jamais une clé `service_role` dans une app cliente.
/// Pour la production, utilise la clé `anon` + des règles RLS, ou un endpoint
/// d'upload signé côté serveur.
enum SupabaseConfig {
    /// URL du projet, ex. `https://abcdxyz.supabase.co`
    static let url = URL(string: "https://YOUR-PROJECT-REF.supabase.co")!

    /// Clé publique `anon` du projet.
    static let anonKey = "YOUR-ANON-KEY"

    /// Nom du bucket Storage dans lequel uploader les photos matchées.
    static let bucket = "shared-photos"

    /// Indique si la configuration a été renseignée.
    static var isConfigured: Bool {
        !anonKey.contains("YOUR-") && !url.absoluteString.contains("YOUR-")
    }
}
