import Foundation
import UniformTypeIdentifiers

/// Upload des photos vers Supabase Storage via l'API REST `storage/v1/object`.
///
/// Implémentation volontairement sans dépendance externe pour garder la base
/// autonome. Pour un usage avancé (auth, RLS, resumable uploads), bascule vers
/// le SDK officiel `supabase-swift` (voir `project.yml`).
final class SupabaseService {

    enum SupabaseError: LocalizedError {
        case notConfigured
        case uploadFailed(status: Int, body: String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase n'est pas configuré (voir SupabaseConfig.swift)."
            case .uploadFailed(let status, let body):
                return "Upload échoué (HTTP \(status)) : \(body)"
            case .invalidResponse:
                return "Réponse Supabase invalide."
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Upload des données d'une photo vers le bucket configuré.
    /// - Returns: le chemin distant de l'objet créé.
    @discardableResult
    func upload(data: Data, fileName: String, contentType: String) async throws -> String {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }

        let objectPath = "\(SupabaseConfig.bucket)/\(fileName)"
        let endpoint = SupabaseConfig.url
            .appendingPathComponent("storage/v1/object")
            .appendingPathComponent(objectPath)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        // Évite l'erreur "Duplicate" si la photo a déjà été uploadée.
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw SupabaseError.uploadFailed(status: http.statusCode, body: body)
        }
        return objectPath
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
