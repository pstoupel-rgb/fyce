import Foundation
import SwiftUI
import UIKit
import Photos
import os

/// Une photo partagée de l'event, telle qu'affichée (téléchargée depuis le cloud).
struct CloudPhoto: Identifiable, Equatable {
    let id: String
    let storagePath: String
    var image: UIImage?

    static func == (lhs: CloudPhoto, rhs: CloudPhoto) -> Bool { lhs.id == rhs.id }
}

/// Partage des photos d'un event entre membres, via le backend :
/// - « push » : envoie tes photos gardées pour l'event vers le cloud ;
/// - « pull » : liste et télécharge les photos partagées par les autres.
@MainActor
final class EventCloudViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case unavailable(String)
    }

    @Published var phase: Phase = .idle
    @Published var photos: [CloudPhoto] = []
    @Published var pushing = false
    @Published var statusText: String?
    /// Si non nil, on n'affiche que les photos où **tu** apparais (mode event,
    /// matching on-device). Nil = toutes les photos.
    @Published var matchedPaths: Set<String>?
    @Published var matching = false

    let event: PozeEvent
    private let store: FriendStore
    private let photoLibrary = PhotoLibraryService()
    private let backend = EventBackendService.shared

    init(event: PozeEvent, store: FriendStore) {
        self.event = event
        self.store = store
    }

    /// Nombre de photos gardées localement pour cet event (candidates au partage).
    var localSharedCount: Int { store.sharedIDs(forKey: event.id.uuidString).count }

    /// Photos à afficher : toutes, ou seulement les tiennes si un filtre est actif.
    var displayPhotos: [CloudPhoto] {
        guard let matchedPaths else { return photos }
        return photos.filter { matchedPaths.contains($0.storagePath) }
    }

    // MARK: - « Trouve mes photos » (matching on-device, Option B)

    func showAll() { matchedPaths = nil }

    /// Récupère les empreintes anonymes de l'event et garde les photos où l'un de
    /// tes visages correspond — **entièrement sur ton téléphone**.
    func findMyPhotos() async {
        guard let remoteID = event.remoteID, backend.isEnabled else {
            statusText = "Event non synchronisé."
            return
        }
        guard let selfPrint = SelfFaceStore.shared.referencePrint else {
            statusText = "Ajoute d'abord ton visage dans l'onglet « Moi »."
            return
        }
        matching = true
        defer { matching = false }
        do {
            let faces = try await backend.listEventFacePrints(remoteEventID: remoteID)
            var mine = Set<String>()
            for face in faces {
                guard let print = EventFaceMatcher.decode(face.print_b64) else { continue }
                if EventFaceMatcher.isMine(print, selfPrints: [selfPrint]) {
                    mine.insert(face.storage_path)
                }
            }
            matchedPaths = mine
            statusText = mine.isEmpty ? "Aucune photo de toi trouvée." : "\(mine.count) photo(s) de toi."
        } catch {
            statusText = "Recherche impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - Pull

    func load() async {
        guard backend.isEnabled else {
            phase = .unavailable("Le partage cloud nécessite un backend Supabase configuré.")
            return
        }
        guard let remoteID = event.remoteID else {
            phase = .unavailable("Event pas encore synchronisé. Rouvre-le une fois en ligne.")
            return
        }
        phase = .loading
        do {
            let remote = try await backend.listEventPhotos(remoteEventID: remoteID)
            photos = remote.map { CloudPhoto(id: $0.id, storagePath: $0.storage_path, image: nil) }
            phase = .ready
            await downloadImages()
        } catch {
            phase = .unavailable("Impossible de charger les photos : \(error.localizedDescription)")
        }
    }

    private func downloadImages() async {
        for index in photos.indices {
            let path = photos[index].storagePath
            guard let url = try? await backend.signedURL(for: path),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { continue }
            if let i = photos.firstIndex(where: { $0.storagePath == path }) {
                photos[i].image = image
            }
        }
    }

    // MARK: - Push

    /// Envoie vers le cloud les photos gardées localement pour cet event.
    func pushLocalShared() async {
        guard backend.isEnabled, let remoteID = event.remoteID else { return }
        let ids = Array(store.sharedIDs(forKey: event.id.uuidString))
        guard !ids.isEmpty else { statusText = "Aucune photo gardée à partager."; return }

        pushing = true
        defer { pushing = false }

        let assets = fetchAssets(withIDs: ids)
        var sent = 0
        for asset in assets {
            do {
                let (data, uti) = try await photoLibrary.loadOriginalData(for: asset)
                let meta = SupabaseService.fileMetadata(forUTI: uti, assetID: asset.localIdentifier)
                try await backend.uploadEventPhoto(
                    remoteEventID: remoteID, data: data,
                    fileName: meta.fileName, contentType: meta.contentType)
                sent += 1
                statusText = "Envoi… \(sent)/\(assets.count)"
            } catch {
                Logger.upload.error("Push event photo échoué : \(error.localizedDescription, privacy: .public)")
            }
        }
        statusText = "\(sent) photo\(sent > 1 ? "s" : "") partagée\(sent > 1 ? "s" : "") avec l'event."
        Haptics.success()
        await load()
    }

    // MARK: - Enregistrer dans la pellicule

    func saveToLibrary(_ photo: CloudPhoto) async {
        guard let image = photo.image else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            statusText = "Photo enregistrée dans ta pellicule."
            Haptics.success()
        } catch {
            statusText = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    private func fetchAssets(withIDs ids: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }
}
