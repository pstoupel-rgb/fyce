import Foundation

/// Envoie le token APNs de l'appareil au backend, pour pouvoir pousser
/// « nouvelles photos de toi ». La table `device_tokens` est côté Supabase
/// (voir backend/schema.sql) ; l'envoi réel du push se fait par une edge function.
struct PushRegistrationService {
    func register(token: String) async throws {
        let cfg = SupabaseConfiguration.current
        guard cfg.isConfigured else { return }

        let endpoint = cfg.url.appendingPathComponent("rest/v1/device_tokens")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(cfg.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(cfg.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "token": token,
            "platform": "ios",
        ])

        _ = try? await URLSession.shared.data(for: request)
    }
}
