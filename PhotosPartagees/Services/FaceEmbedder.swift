import Foundation
import Vision
import CoreML
import CoreImage

/// Produit une `FaceSignature` à partir d'un visage recadré.
/// - Si un modèle Core ML de reconnaissance faciale est présent dans le bundle,
///   on l'utilise (précision ~état de l'art).
/// - Sinon, repli automatique sur l'empreinte d'image **Vision** (l'app marche
///   sans modèle, avec une précision moindre).
///
/// Pour activer Core ML : ajoute au projet un modèle nommé
/// `FaceEmbedding` (ou `FaceNet` / `ArcFace`) — un réseau qui prend une image de
/// visage et sort un vecteur d'embedding. Voir docs/coreml-face.md.
final class FaceEmbedder: @unchecked Sendable {
    static let shared = FaceEmbedder()

    private let coreML = CoreMLFaceEmbedder()

    /// Backend effectivement utilisé (pour l'affichage / le debug).
    var backendName: String { coreML.isAvailable ? "Core ML" : "Vision" }

    /// Embedding d'un visage recadré. `nil` si aucun backend n'aboutit.
    func signature(for faceCrop: CIImage) -> FaceSignature? {
        if coreML.isAvailable, let vector = coreML.vector(for: faceCrop) {
            return FaceSignature(vector: Self.l2normalize(vector))
        }
        if let vector = try? visionVector(faceCrop) {
            return FaceSignature(vector: vector)   // Vision : brut (L2 ≈ computeDistance)
        }
        return nil
    }

    private func visionVector(_ ci: CIImage) throws -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(ciImage: ci, options: [:])
        try handler.perform([request])
        guard let obs = request.results?.first else { throw VisionError.noResult }
        return Self.floats(from: obs)
    }

    enum VisionError: Error { case noResult }

    /// Extrait le vecteur `[Float]` d'une empreinte Vision.
    static func floats(from obs: VNFeaturePrintObservation) -> [Float] {
        let data = obs.data
        if obs.elementType == .float {
            return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        } else {
            return data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }.map { Float($0) }
        }
    }

    static func l2normalize(_ v: [Float]) -> [Float] {
        let norm = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }
}

/// Embedder Core ML optionnel : actif seulement si un modèle est dans le bundle.
final class CoreMLFaceEmbedder: @unchecked Sendable {
    private let vnModel: VNCoreMLModel?
    var isAvailable: Bool { vnModel != nil }

    init() {
        let names = ["FaceEmbedding", "FaceNet", "ArcFace", "facenet", "face_embedding"]
        var loaded: VNCoreMLModel?
        for name in names {
            let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: name, withExtension: "mlpackage")
            if let url, let model = try? MLModel(contentsOf: url),
               let vn = try? VNCoreMLModel(for: model) {
                loaded = vn
                break
            }
        }
        vnModel = loaded
    }

    func vector(for ci: CIImage) -> [Float]? {
        guard let vnModel else { return nil }
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop
        let handler = VNImageRequestHandler(ciImage: ci, options: [:])
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first as? VNCoreMLFeatureValueObservation,
              let array = obs.featureValue.multiArrayValue else { return nil }
        var out = [Float]()
        out.reserveCapacity(array.count)
        for i in 0..<array.count { out.append(array[i].floatValue) }
        return out
    }
}
