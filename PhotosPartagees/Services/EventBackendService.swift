import Foundation
import os

/// Client REST minimal pour les events partagés via Supabase (PostgREST + GoTrue).
///
/// Entièrement **optionnel** : si Supabase n'est pas configuré (clés absentes),
/// `isEnabled` est faux et l'app fonctionne 100 % en local. Chaque appel est
/// « best-effort » : en cas d'erreur réseau/backend, on ne casse jamais le flux
/// local. Ce code n'a pas été testé contre un projet live — voir
/// `docs/backend-events.md` pour le déploiement du schéma et l'activation de
/// l'auth anonyme.
actor EventBackendService {
    static let shared = EventBackendService()

    private let config = SupabaseConfiguration.current
    private let session: URLSession = .shared
    private var accessToken: String?

    /// Le backend est-il utilisable (clés présentes) ?
    nonisolated var isEnabled: Bool { config.isConfigured }

    enum BackendError: LocalizedError {
        case notConfigured, auth, http(Int, String), decode
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Supabase non configuré."
            case .auth: return "Auth anonyme échouée."
            case .http(let s, let b): return "HTTP \(s) : \(b)"
            case .decode: return "Réponse illisible."
            }
        }
    }

    struct RemoteEvent: Decodable { let id: String; let name: String; let join_code: String? }
    struct RemotePhoto: Decodable, Identifiable { let id: String; let storage_path: String; let created_at: String? }
    struct RemoteNotification: Decodable, Identifiable {
        let id: Int
        let kind: String
        let body: String?
        let created_at: String?
        let seen_at: String?
    }

    /// Les notifications de l'utilisateur (« X a de nouvelles photos de toi »).
    /// Lecture seule ; RLS limite déjà aux siennes.
    func listNotifications() async throws -> [RemoteNotification] {
        guard isEnabled else { throw BackendError.notConfigured }
        let token = try await ensureSession()
        var request = restRequest(
            path: "rest/v1/notifications?select=id,kind,body,created_at,seen_at&order=created_at.desc&limit=50",
            token: token)
        request.httpMethod = "GET"
        return try await send(request)
    }

    private let storage = SupabaseService()

    // MARK: - Photos d'event

    /// Envoie une photo au stockage et l'enregistre pour l'event distant.
    func uploadEventPhoto(remoteEventID: String, data: Data,
                          fileName: String, contentType: String) async throws {
        guard isEnabled else { throw BackendError.notConfigured }
        let token = try await ensureSession()

        // 1) upload binaire dans le bucket Storage
        let storagePath = try await storage.upload(
            data: data, fileName: "events/\(remoteEventID)/\(fileName)", contentType: contentType)

        // 2) enregistre la ligne photos (event_id, storage_path)
        var request = restRequest(path: "rest/v1/photos", token: token)
        request.httpMethod = "POST"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "event_id": remoteEventID, "storage_path": storagePath])
        let (respData, response) = try await session.data(for: request)
        try Self.check(response, respData)
    }

    /// Liste les photos partagées d'un event.
    func listEventPhotos(remoteEventID: String) async throws -> [RemotePhoto] {
        guard isEnabled else { throw BackendError.notConfigured }
        let token = try await ensureSession()
        let path = "rest/v1/photos?event_id=eq.\(remoteEventID)&select=id,storage_path,created_at&order=created_at.desc"
        var request = restRequest(path: path, token: token)
        request.httpMethod = "GET"
        return try await send(request)
    }

    /// URL signée temporaire pour télécharger une photo (`bucket/objet`).
    func signedURL(for storagePath: String) async throws -> URL {
        guard isEnabled else { throw BackendError.notConfigured }
        return try await storage.createSignedURL(path: storagePath, expiresIn: 3600)
    }

    // MARK: - API publique

    /// Crée l'event côté serveur (idempotent sur `join_code`). Renvoie l'id distant.
    @discardableResult
    func createEvent(name: String, joinCode: String, startsAt: Date) async throws -> String {
        guard isEnabled else { throw BackendError.notConfigured }
        let token = try await ensureSession()

        let body: [String: Any] = [
            "name": name,
            "join_code": joinCode,
            "starts_at": ISO8601DateFormatter().string(from: startsAt)
        ]
        var request = restRequest(path: "rest/v1/events", token: token)
        request.httpMethod = "POST"
        request.setValue("resolution=merge-duplicates,return=representation",
                         forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let rows: [RemoteEvent] = try await send(request)
        guard let id = rows.first?.id else { throw BackendError.decode }
        Logger.upload.info("Event distant créé : \(id, privacy: .public)")
        return id
    }

    /// Rejoint un event par son code (RPC `join_event`). Renvoie l'id distant.
    @discardableResult
    func joinEvent(code: String) async throws -> String {
        guard isEnabled else { throw BackendError.notConfigured }
        let token = try await ensureSession()

        var request = restRequest(path: "rest/v1/rpc/join_event", token: token)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["p_code": code])

        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        // La fonction renvoie un uuid (chaîne JSON).
        if let id = try? JSONDecoder().decode(String.self, from: data) { return id }
        throw BackendError.decode
    }

    // MARK: - Auth anonyme (GoTrue)

    private func ensureSession() async throws -> String {
        if let accessToken { return accessToken }
        let url = config.url.appendingPathComponent("auth/v1/signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Sign-in anonyme : signup sans identifiant (à activer côté projet).
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["data": [:], "gotrue_meta_security": [:]])

        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        struct Session: Decodable { let access_token: String? }
        guard let token = (try? JSONDecoder().decode(Session.self, from: data))?.access_token else {
            throw BackendError.auth
        }
        accessToken = token
        return token
    }

    // MARK: - Helpers

    private func restRequest(path: String, token: String) -> URLRequest {
        // Construit l'URL par concaténation pour préserver les query strings
        // (appendingPathComponent encoderait `?`/`=`).
        let base = config.url.absoluteString
        let url = URL(string: base + "/" + path) ?? config.url
        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw BackendError.decode
        }
        return decoded
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw BackendError.decode }
        guard (200...299).contains(http.statusCode) else {
            throw BackendError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
