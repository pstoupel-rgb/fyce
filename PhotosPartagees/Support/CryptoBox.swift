import Foundation
import CryptoKit

/// Chiffrement local (AES-GCM) des données sensibles au repos — en particulier
/// les **empreintes de visage** (biométrie). La clé symétrique 256 bits vit dans
/// le Keychain ; rien de déchiffrable ne touche le disque en clair.
enum CryptoBox {
    private static let keyName = "poze_data_key_v1"

    private static func key() -> SymmetricKey {
        if let b64 = KeychainHelper.get(keyName), let data = Data(base64Encoded: b64) {
            return SymmetricKey(data: data)
        }
        let newKey = SymmetricKey(size: .bits256)
        let raw = newKey.withUnsafeBytes { Data($0) }
        KeychainHelper.set(raw.base64EncodedString(), for: keyName)
        return newKey
    }

    /// Chiffre des données (renvoie la boîte scellée `combined`).
    static func seal(_ plaintext: Data) -> Data? {
        try? AES.GCM.seal(plaintext, using: key()).combined
    }

    /// Déchiffre une boîte scellée.
    static func open(_ box: Data) -> Data? {
        guard let sealed = try? AES.GCM.SealedBox(combined: box) else { return nil }
        return try? AES.GCM.open(sealed, using: key())
    }
}
