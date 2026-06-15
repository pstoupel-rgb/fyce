import Foundation
import SwiftUI
import Photos

/// Orchestre le flux complet : référence → scan photothèque → matching Vision → upload Supabase.
@MainActor
final class ScanViewModel: ObservableObject {

    @Published var state: ScanState = .idle
    @Published var hasReferenceFace = false
    @Published var matches: [MatchedPhoto] = []

    private let photoLibrary = PhotoLibraryService()
    private let faceDetection = FaceDetectionService()
    private let matcher = FaceMatcher()
    private let supabase = SupabaseService()

    private var scanTask: Task<Void, Never>?

    var threshold: Float {
        get { matcher.threshold }
        set { matcher.threshold = newValue }
    }

    // MARK: - Visage de référence

    /// Définit le visage de référence à partir d'une image choisie par l'utilisateur.
    func setReferenceFace(_ image: UIImage) {
        do {
            let print = try faceDetection.referenceFeaturePrint(from: image)
            matcher.setReference(print)
            hasReferenceFace = true
            if case .needsReferenceFace = state { state = .idle }
        } catch {
            state = .error("Visage de référence invalide : \(error.localizedDescription)")
        }
    }

    // MARK: - Scan

    func startScan() {
        guard matcher.hasReference else {
            state = .needsReferenceFace
            return
        }
        scanTask?.cancel()
        scanTask = Task { await runScan() }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    private func runScan() async {
        // 1. Autorisation
        if !photoLibrary.isAuthorized {
            let status = await photoLibrary.requestAuthorization()
            guard status == .authorized || status == .limited else {
                state = .error(PhotoLibraryService.PhotoLibraryError.accessDenied.localizedDescription)
                return
            }
        }

        // 2. Énumération
        let photos = photoLibrary.fetchAllPhotos()
        matches = []
        state = .scanning(processed: 0, total: photos.count)

        // 3. Détection + matching, photo par photo
        for (index, photo) in photos.enumerated() {
            if Task.isCancelled { return }

            await process(photo: photo)
            state = .scanning(processed: index + 1, total: photos.count)
        }

        state = .finished(matches: matches.count)
    }

    private func process(photo: PhotoAsset) async {
        do {
            let image = try await photoLibrary.loadImage(for: photo.asset)
            let prints = try faceDetection.faceFeaturePrints(in: image)
            guard let result = matcher.match(against: prints), result.isMatch else { return }

            // On collecte le match : l'utilisateur validera ensuite ce qu'il partage.
            matches.append(MatchedPhoto(photo: photo, distance: result.distance))
        } catch {
            // Photo sans visage ou illisible : on ignore silencieusement.
        }
    }

    // MARK: - Sélection (validation utilisateur)

    var selectedCount: Int { matches.filter(\.isSelected).count }

    var hasUploadableSelection: Bool {
        matches.contains { $0.isSelected && $0.uploadStatus.isUploadable }
    }

    func toggleSelection(_ id: String) {
        guard let idx = matches.firstIndex(where: { $0.id == id }) else { return }
        matches[idx].isSelected.toggle()
    }

    func selectAll() {
        for idx in matches.indices { matches[idx].isSelected = true }
    }

    func deselectAll() {
        for idx in matches.indices { matches[idx].isSelected = false }
    }

    // MARK: - Upload

    /// Partage uniquement les photos validées par l'utilisateur.
    func uploadSelected() {
        Task {
            for matched in matches where matched.isSelected && matched.uploadStatus.isUploadable {
                await upload(matched)
            }
        }
    }

    private func upload(_ matched: MatchedPhoto) async {
        updateStatus(for: matched.id, to: .uploading)
        do {
            let (data, uti) = try await photoLibrary.loadOriginalData(for: matched.photo.asset)
            let meta = SupabaseService.fileMetadata(forUTI: uti, assetID: matched.id)
            let remotePath = try await supabase.upload(
                data: data,
                fileName: meta.fileName,
                contentType: meta.contentType
            )
            updateStatus(for: matched.id, to: .uploaded(remotePath: remotePath))
        } catch {
            updateStatus(for: matched.id, to: .failed(message: error.localizedDescription))
        }
    }

    private func updateStatus(for id: String, to status: UploadStatus) {
        guard let idx = matches.firstIndex(where: { $0.id == id }) else { return }
        matches[idx].uploadStatus = status
    }
}
