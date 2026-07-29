import Foundation
import SwiftUI
import Photos
import Vision
import os

/// Stockage de l'historique « gardé / passé » d'un sujet de revue, keyé par une
/// chaîne stable (id d'ami, de groupe ou d'event).
@MainActor
protocol ReviewHistoryStoring: AnyObject {
    func sharedIDs(forKey key: String) -> Set<String>
    func skippedIDs(forKey key: String) -> Set<String>
    func markShared(_ photoID: String, forKey key: String)
    func markSkipped(_ photoID: String, forKey key: String)
    func resetHistory(forKey key: String)
}

/// Ce que l'on passe en revue : un ami, un groupe ou un event. On le décrit par
/// ses empreintes de référence (un ou plusieurs visages), un titre et des avatars.
struct ReviewSubject {
    let historyKey: String
    let title: String
    let subtitle: String
    let colorway: Colorway
    let references: [VNFeaturePrintObservation]
    let avatars: [UIImage?]

    static func friend(_ f: Friend) -> ReviewSubject {
        ReviewSubject(historyKey: f.id.uuidString,
                      title: f.name,
                      subtitle: "Tes photos de \(f.name)",
                      colorway: .aurora,
                      references: [f.referencePrint],
                      avatars: [f.thumbnail])
    }

    static func group(_ g: FriendGroup, members: [Friend]) -> ReviewSubject {
        ReviewSubject(historyKey: g.id.uuidString,
                      title: g.name,
                      subtitle: "\(members.count) membre\(members.count > 1 ? "s" : "")",
                      colorway: g.colorway,
                      references: members.map(\.referencePrint),
                      avatars: members.map(\.thumbnail))
    }

    static func event(_ e: PozeEvent, members: [Friend]) -> ReviewSubject {
        ReviewSubject(historyKey: e.id.uuidString,
                      title: e.name,
                      subtitle: e.date.formatted(date: .abbreviated, time: .omitted),
                      colorway: e.colorway,
                      references: members.map(\.referencePrint),
                      avatars: members.map(\.thumbnail))
    }
}

/// Une photo proposée à la revue (image chargée pour l'affichage).
struct ReviewPhoto: Identifiable, Equatable {
    let id: String              // PHAsset.localIdentifier
    let asset: PHAsset
    let distance: Float
    var image: UIImage?

    static func == (lhs: ReviewPhoto, rhs: ReviewPhoto) -> Bool { lhs.id == rhs.id }
}

/// Moteur de revue « façon Tinder » : scan de la pellicule (on-device) pour le
/// sujet, file de nouvelles photos à trier, actions garder / passer / supprimer.
@MainActor
final class ReviewViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case needsAccess
        case noReference
        case scanning(processed: Int, total: Int)
        case ready
        case error(String)
    }

    @Published var phase: Phase = .idle
    @Published var queue: [ReviewPhoto] = []
    @Published var shared: [ReviewPhoto] = []
    @Published var keptThisSession = 0

    let subject: ReviewSubject

    private let store: ReviewHistoryStoring
    private let photoLibrary: PhotoLibraryProviding
    private let faceDetection: FaceDetecting
    private var scanTask: Task<Void, Never>?

    init(subject: ReviewSubject,
         store: ReviewHistoryStoring,
         photoLibrary: PhotoLibraryProviding = PhotoLibraryService(),
         faceDetection: FaceDetecting = FaceDetectionService()) {
        self.subject = subject
        self.store = store
        self.photoLibrary = photoLibrary
        self.faceDetection = faceDetection
    }

    var remaining: Int { queue.count }

    // MARK: - Scan

    func start() {
        guard scanTask == nil else { return }
        guard !subject.references.isEmpty else { phase = .noReference; return }
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

        let matcher = MultiFaceMatcher(references: subject.references)
        let photos = photoLibrary.fetchAllPhotos()
        let sharedIDs = store.sharedIDs(forKey: subject.historyKey)
        let skippedIDs = store.skippedIDs(forKey: subject.historyKey)
        phase = .scanning(processed: 0, total: photos.count)
        queue = []; shared = []

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
        queue.sort { $0.distance < $1.distance }
        await preloadThumbnails()
        Logger.scan.info("Revue \(self.subject.title, privacy: .public) : \(self.queue.count) nouvelles, \(self.shared.count) partagées")
        phase = .ready
    }

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

    /// Swipe droite (✓) : garder pour partager.
    func keepTop() {
        guard let card = queue.first else { return }
        store.markShared(card.id, forKey: subject.historyKey)
        shared.insert(card, at: 0)
        keptThisSession += 1
        popTop()
    }

    /// Swipe gauche (✗) : passer, on ne le repropose plus.
    func skipTop() {
        guard let card = queue.first else { return }
        store.markSkipped(card.id, forKey: subject.historyKey)
        popTop()
    }

    /// Swipe bas (🗑️) : supprimer réellement la photo du téléphone (confirmation système iOS).
    func trashTop() async {
        guard let card = queue.first else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([card.asset] as NSArray)
            }
            store.markSkipped(card.id, forKey: subject.historyKey)
            popTop()
        } catch {
            Logger.app.debug("Suppression annulée/échouée : \(error.localizedDescription, privacy: .public)")
        }
    }

    private func popTop() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
        loadImageIfNeeded(at: 0)
        loadImageIfNeeded(at: 1)
    }
}
