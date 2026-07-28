import Foundation
import SwiftUI
import Photos
import Vision
import os

/// Une photo proposée à la revue pour un ami (image chargée pour l'affichage).
struct ReviewPhoto: Identifiable, Equatable {
    let id: String              // PHAsset.localIdentifier
    let asset: PHAsset
    let distance: Float
    var image: UIImage?

    static func == (lhs: ReviewPhoto, rhs: ReviewPhoto) -> Bool { lhs.id == rhs.id }
}

/// Pilote la revue « façon Tinder » des photos d'un ami :
/// scan de la pellicule → visages correspondants → file de nouvelles photos.
/// Actions : garder (partager), passer, ou supprimer réellement du téléphone.
@MainActor
final class FriendReviewViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case needsAccess
        case scanning(processed: Int, total: Int)
        case ready
        case error(String)
    }

    @Published var phase: Phase = .idle
    /// File des nouvelles photos à trier (la première de la pile est celle du dessus).
    @Published var queue: [ReviewPhoto] = []
    /// Photos déjà partagées avec cet ami (galerie).
    @Published var shared: [ReviewPhoto] = []
    /// Nombre de photos gardées pendant cette session (pour le récap).
    @Published var keptThisSession = 0

    let friend: Friend

    private let photoLibrary: PhotoLibraryProviding
    private let faceDetection: FaceDetecting
    private let store: FriendStore
    private var scanTask: Task<Void, Never>?

    init(friend: Friend,
         store: FriendStore,
         photoLibrary: PhotoLibraryProviding = PhotoLibraryService(),
         faceDetection: FaceDetecting = FaceDetectionService()) {
        self.friend = friend
        self.store = store
        self.photoLibrary = photoLibrary
        self.faceDetection = faceDetection
    }

    var topCard: ReviewPhoto? { queue.first }
    var remaining: Int { queue.count }

    // MARK: - Scan

    func start() {
        guard scanTask == nil else { return }
        scanTask = Task { await runScan() }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
    }

    private func runScan() async {
        if !photoLibrary.isAuthorized {
            let status = await photoLibrary.requestAuthorization()
            guard status == .authorized || status == .limited else {
                phase = .needsAccess
                return
            }
        }

        // Matcher dédié à cet ami (empreinte de référence = visage de l'ami).
        let matcher = FaceMatcher()
        matcher.setReference(friend.referencePrint)

        let photos = photoLibrary.fetchAllPhotos()
        let sharedIDs = store.sharedIDs(for: friend)
        let skippedIDs = store.skippedIDs(for: friend)
        phase = .scanning(processed: 0, total: photos.count)
        queue = []
        shared = []

        let scanner = FaceScanner(photoLibrary: photoLibrary,
                                  faceDetection: faceDetection, matcher: matcher)
        let batchSize = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount))
        var processed = 0
        var index = 0

        while index < photos.count {
            if Task.isCancelled { return }
            let batch = Array(photos[index..<min(index + batchSize, photos.count)])
            let found = await withTaskGroup(of: ScanMatch?.self) { group -> [ScanMatch] in
                for photo in batch { group.addTask { await scanner.analyze(photo) } }
                var results: [ScanMatch] = []
                for await r in group { if let r { results.append(r) } }
                return results
            }

            for match in found {
                guard let asset = batch.first(where: { $0.id == match.id })?.asset else { continue }
                let item = ReviewPhoto(id: match.id, asset: asset, distance: match.distance)
                if sharedIDs.contains(match.id) {
                    shared.append(item)
                } else if !skippedIDs.contains(match.id) {
                    queue.append(item)
                }
            }

            processed += batch.count
            index += batchSize
            phase = .scanning(processed: processed, total: photos.count)
        }

        if Task.isCancelled { return }
        // Trie la file par pertinence (meilleure correspondance en premier).
        queue.sort { $0.distance < $1.distance }
        await preloadThumbnails()
        Logger.scan.info("Revue \(self.friend.name, privacy: .public) : \(self.queue.count) nouvelles, \(self.shared.count) partagées")
        phase = .ready
    }

    /// Charge les images des quelques premières cartes + de la galerie partagée.
    private func preloadThumbnails() async {
        let target = CGSize(width: 900, height: 900)
        for i in queue.indices.prefix(6) {
            if let img = try? await photoLibrary.loadImage(for: queue[i].asset, targetSize: target) {
                queue[i].image = img
            }
        }
        for i in shared.indices.prefix(30) {
            if let img = try? await photoLibrary.loadImage(
                for: shared[i].asset, targetSize: CGSize(width: 400, height: 400)) {
                shared[i].image = img
            }
        }
    }

    /// Charge l'image de la carte suivante au fil des swipes (préchargement doux).
    private func loadImageIfNeeded(at index: Int) {
        guard queue.indices.contains(index), queue[index].image == nil else { return }
        let asset = queue[index].asset
        let id = queue[index].id
        Task {
            if let img = try? await photoLibrary.loadImage(
                for: asset, targetSize: CGSize(width: 900, height: 900)) {
                if let idx = queue.firstIndex(where: { $0.id == id }) { queue[idx].image = img }
            }
        }
    }

    // MARK: - Actions de swipe

    /// Swipe droite (✓) : garder pour partager avec cet ami.
    func keepTop() {
        guard let card = queue.first else { return }
        store.markShared(card.id, for: friend)
        shared.insert(card, at: 0)   // conserve l'image déjà chargée
        keptThisSession += 1
        popTop()
    }

    /// Swipe gauche (✗) : passer, on ne le repropose plus.
    func skipTop() {
        guard let card = queue.first else { return }
        store.markSkipped(card.id, for: friend)
        popTop()
    }

    /// Swipe bas (🗑️) : supprimer réellement la photo du téléphone.
    /// iOS affiche sa propre confirmation système avant suppression.
    func trashTop() async {
        guard let card = queue.first else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([card.asset] as NSArray)
            }
            store.markSkipped(card.id, for: friend)  // ne pas la reproposer
            popTop()
        } catch {
            // L'utilisateur a annulé la confirmation système, ou erreur : on garde la carte.
            Logger.app.debug("Suppression annulée/échouée : \(error.localizedDescription, privacy: .public)")
        }
    }

    private func popTop() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
        loadImageIfNeeded(at: 0)
        loadImageIfNeeded(at: 1)
    }

    func resetHistory() {
        store.resetHistory(for: friend)
        cancel()
        scanTask = nil
        phase = .idle
        keptThisSession = 0
    }
}
