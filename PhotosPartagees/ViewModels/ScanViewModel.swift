import Foundation
import SwiftUI
import Photos
import os

/// Orchestre le flux complet : référence → scan photothèque → matching Vision → upload Supabase.
@MainActor
final class ScanViewModel: ObservableObject {

    @Published var state: ScanState = .idle
    @Published var hasReferenceFace = false
    @Published var matches: [MatchedPhoto] = []
    /// Récap affiché à la fin d'un partage (succès / échecs).
    @Published var summary: UploadSummary?

    // MARK: Dépendances injectées

    private let photoLibrary: PhotoLibraryProviding
    private let faceDetection: FaceDetecting
    private let matcher: FaceMatching
    private let uploader: PhotoUploading
    private let sharedStore: SharedPhotosStoring

    private var scanTask: Task<Void, Never>?
    private var photosByID: [String: PhotoAsset] = [:]
    private var lastUploadedPaths: [String] = []

    init(
        photoLibrary: PhotoLibraryProviding = PhotoLibraryService(),
        faceDetection: FaceDetecting = FaceDetectionService(),
        matcher: FaceMatching = FaceMatcher(),
        uploader: PhotoUploading = SupabaseService(),
        sharedStore: SharedPhotosStoring = SharedPhotosStore()
    ) {
        self.photoLibrary = photoLibrary
        self.faceDetection = faceDetection
        self.matcher = matcher
        self.uploader = uploader
        self.sharedStore = sharedStore
    }

    var threshold: Float {
        get { matcher.threshold }
        set { matcher.threshold = newValue }
    }

    var sharedCount: Int { sharedStore.sharedIDs.count }

    // MARK: - Visage de référence

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
        if !photoLibrary.isAuthorized {
            let status = await photoLibrary.requestAuthorization()
            guard status == .authorized || status == .limited else {
                state = .error(PhotoLibraryService.PhotoLibraryError.accessDenied.localizedDescription)
                return
            }
        }

        let photos = photoLibrary.fetchAllPhotos()
        photosByID = Dictionary(photos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        matches = []
        state = .scanning(processed: 0, total: photos.count)

        let sharedIDs = sharedStore.sharedIDs
        let scanner = FaceScanner(photoLibrary: photoLibrary, faceDetection: faceDetection, matcher: matcher)
        let batchSize = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount))
        Logger.scan.info("Scan de \(photos.count) photos (concurrence: \(batchSize))")

        var processed = 0
        var index = 0
        while index < photos.count {
            if Task.isCancelled { return }
            let batch = Array(photos[index..<min(index + batchSize, photos.count)])

            // Analyse parallèle du lot hors du main thread.
            let found = await withTaskGroup(of: ScanMatch?.self) { group -> [ScanMatch] in
                for photo in batch { group.addTask { await scanner.analyze(photo) } }
                var results: [ScanMatch] = []
                for await result in group {
                    if let result { results.append(result) }
                }
                return results
            }

            for match in found { appendMatch(match, sharedIDs: sharedIDs) }
            processed += batch.count
            index += batchSize
            state = .scanning(processed: processed, total: photos.count)
        }

        if Task.isCancelled { return }
        Logger.scan.info("Scan terminé : \(self.matches.count) match(s)")
        state = .finished(matches: matches.count)
    }

    private func appendMatch(_ match: ScanMatch, sharedIDs: Set<String>) {
        guard let photo = photosByID[match.id] else { return }
        var matched = MatchedPhoto(photo: photo, distance: match.distance)
        if sharedIDs.contains(match.id) {
            matched.uploadStatus = .alreadyShared
            matched.isSelected = false
        }
        matches.append(matched)
    }

    // MARK: - Sélection

    var selectedCount: Int { matches.filter(\.isSelected).count }

    var hasUploadableSelection: Bool {
        matches.contains { $0.isSelected && $0.uploadStatus.isUploadable }
    }

    var hasFailedUploads: Bool {
        matches.contains { if case .failed = $0.uploadStatus { return true } else { return false } }
    }

    var hasSharedLinks: Bool { !lastUploadedPaths.isEmpty }

    func toggleSelection(_ id: String) {
        guard let idx = matches.firstIndex(where: { $0.id == id }) else { return }
        guard matches[idx].uploadStatus.isUploadable else { return }
        matches[idx].isSelected.toggle()
    }

    func selectAll() {
        for idx in matches.indices where matches[idx].uploadStatus.isUploadable {
            matches[idx].isSelected = true
        }
    }

    func deselectAll() {
        for idx in matches.indices { matches[idx].isSelected = false }
    }

    // MARK: - Réglages

    func resetSharedHistory() {
        sharedStore.reset()
        lastUploadedPaths.removeAll()
        for idx in matches.indices where matches[idx].uploadStatus == .alreadyShared {
            matches[idx].uploadStatus = .pending
        }
        objectWillChange.send()
    }

    // MARK: - Upload

    func uploadSelected() {
        let ids = matches
            .filter { $0.isSelected && $0.uploadStatus.isUploadable }
            .map(\.id)
        Task { await runUpload(of: ids) }
    }

    func retryFailed() {
        let ids = matches
            .filter { if case .failed = $0.uploadStatus { return true } else { return false } }
            .map(\.id)
        Task { await runUpload(of: ids) }
    }

    private func runUpload(of ids: [String]) async {
        guard !ids.isEmpty else { return }
        var succeeded = 0
        var failed = 0
        for id in ids {
            guard let matched = matches.first(where: { $0.id == id }) else { continue }
            if let path = await upload(matched) {
                succeeded += 1
                lastUploadedPaths.append(path)
            } else {
                failed += 1
            }
        }
        summary = UploadSummary(succeeded: succeeded, failed: failed)
    }

    private func upload(_ matched: MatchedPhoto) async -> String? {
        updateStatus(for: matched.id, to: .uploading)
        do {
            let (data, uti) = try await photoLibrary.loadOriginalData(for: matched.photo.asset)
            let meta = SupabaseService.fileMetadata(forUTI: uti, assetID: matched.id)
            let remotePath = try await uploader.upload(
                data: data,
                fileName: meta.fileName,
                contentType: meta.contentType
            )
            updateStatus(for: matched.id, to: .uploaded(remotePath: remotePath))
            sharedStore.markShared(matched.id)
            return remotePath
        } catch {
            updateStatus(for: matched.id, to: .failed(message: error.localizedDescription))
            return nil
        }
    }

    /// Génère des liens signés pour les photos partagées et les copie dans le presse-papiers.
    /// - Returns: le nombre de liens copiés.
    @discardableResult
    func copyShareLinks(expiresIn: Int = 60 * 60 * 24 * 7) async -> Int {
        var links: [String] = []
        for path in lastUploadedPaths {
            if let url = try? await uploader.createSignedURL(path: path, expiresIn: expiresIn) {
                links.append(url.absoluteString)
            }
        }
        if !links.isEmpty {
            UIPasteboard.general.string = links.joined(separator: "\n")
        }
        return links.count
    }

    private func updateStatus(for id: String, to status: UploadStatus) {
        guard let idx = matches.firstIndex(where: { $0.id == id }) else { return }
        matches[idx].uploadStatus = status
    }
}
