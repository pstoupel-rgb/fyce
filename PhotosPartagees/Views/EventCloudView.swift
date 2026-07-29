import SwiftUI
import UIKit

/// Écran « Photos de l'event » : partage tes photos gardées avec les membres, et
/// récupère celles que les autres ont partagées. Nécessite un backend configuré.
struct EventCloudView: View {
    @StateObject private var viewModel: EventCloudViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var preview: CloudPhoto?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 5)]

    init(event: PozeEvent, store: FriendStore) {
        _viewModel = StateObject(wrappedValue: EventCloudViewModel(event: event, store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    content
                    pushBar
                }
            }
            .navigationTitle(viewModel.event.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .task { await viewModel.load() }
            .sheet(item: $preview) { photo in
                CloudPreview(photo: photo) { Task { await viewModel.saveToLibrary(photo) } }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            spinner
        case .unavailable(let msg):
            message("Partage indisponible", msg, system: "icloud.slash")
        case .ready:
            if viewModel.photos.isEmpty {
                message("Aucune photo partagée", "Sois le premier à partager tes photos de l'event.",
                        system: "photo.stack")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(viewModel.photos) { photo in
                            thumb(photo).onTapGesture { if photo.image != nil { preview = photo } }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }
            }
        }
        if let status = viewModel.statusText {
            Text(status).font(.footnote).foregroundStyle(Theme.muted).padding(.top, 6)
        }
    }

    private var pushBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.line)
            Button {
                Task { await viewModel.pushLocalShared() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.pushing { ProgressView().tint(.black) }
                    Text(viewModel.pushing ? "Envoi…" : "Partager mes \(viewModel.localSharedCount) photo\(viewModel.localSharedCount > 1 ? "s" : "") gardée\(viewModel.localSharedCount > 1 ? "s" : "")")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Theme.txt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(viewModel.pushing || viewModel.localSharedCount == 0)
            .opacity(viewModel.localSharedCount == 0 ? 0.4 : 1)
            .padding(16)
        }
    }

    private func thumb(_ photo: CloudPhoto) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.surface.overlay(ProgressView().tint(Theme.muted))
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var spinner: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.txt)
            Text("Chargement des photos de l'event…").font(.subheadline).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func message(_ title: String, _ subtitle: String, system: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: system).font(.system(size: 38)).foregroundStyle(Theme.muted2)
            Text(title).font(.headline).foregroundStyle(Theme.txt)
            Text(subtitle).font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Aperçu plein écran d'une photo cloud + bouton d'enregistrement.
private struct CloudPreview: View {
    let photo: CloudPhoto
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = photo.image {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { onSave() } label: { Label("Enregistrer", systemImage: "square.and.arrow.down") }
                }
            }
        }
    }
}
