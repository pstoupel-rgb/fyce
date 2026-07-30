import Foundation

/// Signature de visage unifiée : un vecteur de caractéristiques `[Float]`.
/// Produite soit par un modèle **Core ML** de reconnaissance faciale (précis),
/// soit par le repli **Vision** (empreinte d'image générique). Le reste de l'app
/// ne manipule que ce type — indépendant du backend.
struct FaceSignature: Codable, Equatable {
    let vector: [Float]

    /// Distance L2 (euclidienne). Plus c'est bas, plus les visages se ressemblent.
    /// (Pour les vecteurs Vision, ≈ l'ancienne `computeDistance` : les seuils
    /// existants restent valables.)
    func distance(to other: FaceSignature) -> Float {
        let n = min(vector.count, other.vector.count)
        guard n > 0 else { return .greatestFiniteMagnitude }
        var sum: Float = 0
        for i in 0..<n {
            let d = vector[i] - other.vector[i]
            sum += d * d
        }
        return sum.squareRoot()
    }

    // MARK: - Transmission (mode event, empreintes anonymes)

    func base64() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }

    static func from(base64: String) -> FaceSignature? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONDecoder().decode(FaceSignature.self, from: data)
    }
}
