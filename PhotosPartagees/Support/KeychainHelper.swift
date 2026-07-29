import Foundation
import Security

/// Petit utilitaire Keychain pour stocker les secrets (jetons d'auth) de façon
/// sûre — à la place de `UserDefaults`.
enum KeychainHelper {
    private static let service = (Bundle.main.bundleIdentifier ?? "com.photospartagees.app") + ".secrets"

    @discardableResult
    static func set(_ value: String?, for key: String) -> Bool {
        // Toujours supprimer l'ancienne valeur d'abord (upsert).
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        guard let value, let data = value.data(using: .utf8) else { return true }  // nil = suppression
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        set(nil, for: key)
    }

    /// Supprime tous les secrets de l'app (clé de chiffrement, jeton d'auth…).
    static func wipe() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
