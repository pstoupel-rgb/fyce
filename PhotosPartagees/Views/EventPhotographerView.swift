import SwiftUI
import PhotosUI

/// Mode photographe (Option B) : importe en masse les photos de la soirée. L'app
/// détecte les visages, **uploade les photos** et **publie des empreintes anonymes**
/// (aucune identité). Les invités matcheront ensuite sur *leur* téléphone.
struct EventPhotographerView: View {
    @StateObject private var viewModel: EventPhotographerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []

    init(event: PozeEvent) {
        _viewModel = StateObject(wrappedValue: EventPhotographerViewModel(event: event))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 18) {
                    header
                    content
                    Spacer()
                    if case .working = viewModel.phase {} else {
                        PhotosPicker(selection: $items, matching: .images) {
                            Label(items.isEmpty ? "Choisir les photos" : "\(items.count) photos sélectionnées",
                                  systemImage: "photo.stack")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line2, lineWidth: 1))
                        }
                        Button {
                            Task { await viewModel.publish(items) }
                        } label: {
                            Text("Publier \(items.count) photo\(items.count > 1 ? "s" : "")")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Theme.txt, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(items.isEmpty)
                        .opacity(items.isEmpty ? 0.4 : 1)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Mode photographe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.on.rectangle").font(.system(size: 40)).foregroundStyle(Theme.txt)
            Text(viewModel.event.name).font(.title3.bold()).foregroundStyle(Theme.txt)
            Text("Les invités retrouveront leurs photos sur leur téléphone. Aucun visage n'est identifié côté serveur — seulement des empreintes anonymes.")
                .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            EmptyView()
        case .working(let done, let total, let faces):
            VStack(spacing: 10) {
                ProgressView(value: Double(done), total: Double(max(total, 1))).tint(Theme.txt)
                Text("Publication… \(done)/\(total) · \(faces) visages").font(.subheadline).foregroundStyle(Theme.muted)
            }
        case .done(let photos, let faces):
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 40)).foregroundStyle(Theme.ok)
                Text("\(photos) photos publiées · \(faces) visages").font(.headline).foregroundStyle(Theme.txt)
                Text("Partage le QR de l'event : chacun retrouvera les siennes.")
                    .font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
        case .unavailable(let msg):
            Text(msg).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
    }
}

@MainActor
final class EventPhotographerViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case working(done: Int, total: Int, faces: Int)
        case done(photos: Int, faces: Int)
        case unavailable(String)
    }

    @Published var phase: Phase = .idle
    let event: PozeEvent

    private let faceDetection = FaceDetectionService()
    private let backend = EventBackendService.shared

    init(event: PozeEvent) { self.event = event }

    func publish(_ items: [PhotosPickerItem]) async {
        guard backend.isEnabled, let remoteID = event.remoteID else {
            phase = .unavailable("Le mode photographe nécessite un event synchronisé (backend configuré).")
            return
        }
        guard !items.isEmpty else { return }

        var attempted = 0
        var published = 0        // photos réellement uploadées
        var faceCount = 0
        phase = .working(done: 0, total: items.count, faces: 0)

        for item in items {
            defer { attempted += 1; phase = .working(done: attempted, total: items.count, faces: faceCount) }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data) else { continue }

            let prints = (try? faceDetection.faceFeaturePrints(in: ui)) ?? []
            let meta = SupabaseService.fileMetadata(forUTI: nil, assetID: UUID().uuidString)
            guard let path = try? await backend.uploadEventPhoto(
                remoteEventID: remoteID, data: data,
                fileName: meta.fileName, contentType: meta.contentType) else { continue }
            published += 1

            for print in prints {
                if let b64 = EventFaceMatcher.encode(print) {
                    try? await backend.publishEventFace(remoteEventID: remoteID, storagePath: path, printB64: b64)
                    faceCount += 1
                }
            }
        }
        phase = .done(photos: published, faces: faceCount)
    }
}
