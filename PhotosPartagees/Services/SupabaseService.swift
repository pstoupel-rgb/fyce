import Foundation
import UniformTypeIdentifiers
import os

/// Upload et partage de photos via l'API REST Supabase Storage (`storage/v1`).
///
/// Implémentation sans dépendance externe pour garder la base autonome. Pour un
/// usage avancé (auth, RLS, resumable uploads), bascule vers `supabase-swift`.
final class SupabaseService: PhotoUploading, @unchecked Sendable {

    enum SupabaseError: LocalizedError {
        case notConfigured
        case uploadFailed(status: Int, body: String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase n'est pas configuré (voir Config/Secrets.xcconfig)."
            case .uploadFailed(let status, let body):
                return "Upload échoué (HTTP \(status)) : \(body)"
            case .invalidResponse:
                return "Réponse Supabase invalide."
            }
        }
    }

    private let configuration: SupabaseConfiguration
    private let session: URLSession

    init(configuration: SupabaseConfiguration = .current, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    // MARK: - Upload

    @discardableResult
    func upload(data: Data, fileName: String, contentType: String) async throws -> String {
        guard configuration.isConfigured else { throw SupabaseError.notConfigured }

        let objectPath = "\(configuration.bucket)/\(fileName)"
        let endpoint = configuration.url
            .appendingPathComponent("storage/v1/object")
            .appendingPathComponent(objectPath)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        applyAuthHeaders(to: &request)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")  // évite l'erreur "Duplicate"
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            Logger.upload.error("Upload \(fileName, privacy: .public) -> HTTP \(http.statusCode)")
            throw SupabaseError.uploadFailed(status: http.statusCode, body: body)
        }
        Logger.upload.info("Upload réussi: \(objectPath, privacy: .public)")
        let sentBytes = data.count
        await MainActor.run { NetworkMonitor.shared.recordUpload(bytes: sentBytes) }
        return objectPath
    }

    // MARK: - Lien de partage

    /// Crée une URL signée temporaire pour `path` (= `bucket/objet`).
    func createSignedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        guard configuration.isConfigured else { throw SupabaseError.notConfigured }

        let endpoint = configuration.url
            .appendingPathComponent("storage/v1/object/sign")
            .appendingPathComponent(path)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        applyAuthHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["expiresIn": expiresIn])

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.invalidResponse
        }

        struct SignResponse: Decodable { let signedURL: String }
        let decoded = try JSONDecoder().decode(SignResponse.self, from: responseData)
        let full = configuration.url.absoluteString + "/storage/v1" + decoded.signedURL
        guard let url = URL(string: full) else { throw SupabaseError.invalidResponse }
        return url
    }

    // MARK: - Helpers

    private func applyAuthHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
    }

    /// Déduit l'extension et le type MIME à partir d'un UTI fourni par PhotoKit.
    static func fileMetadata(forUTI uti: String?, assetID: String) -> (fileName: String, contentType: String) {
        let safeID = assetID.replacingOccurrences(of: "/", with: "_")
        let type = uti.flatMap { UTType($0) } ?? .jpeg
        let ext = type.preferredFilenameExtension ?? "jpg"
        let mime = type.preferredMIMEType ?? "image/jpeg"
        return ("\(safeID).\(ext)", mime)
    }
}
