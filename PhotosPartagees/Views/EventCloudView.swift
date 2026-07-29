import SwiftUI
import UIKit

/// Écran « Photos de l'event » : partage tes photos gardées avec les membres, et
/// récupère celles que les autres ont partagées. Nécessite un backend configuré.
struct EventCloudView: View {
    @StateObject private var viewModel: EventCloudViewModel
    @ObservedObject private var wallet = Wallet.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []
    @State private var showPaywall = false

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
                    bottomBar
                }
            }
            .navigationTitle(viewModel.event.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .navigationBarLeading) {
                    Label("\(wallet.reveals)", systemImage: "sparkles").font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    /// Coût en reveals pour télécharger une photo en HD (l'impression est gratuite).
    private let downloadCostPerPhoto = 2

    private var chosenPhotos: [CloudPhoto] {
        viewModel.photos.filter { selection.contains($0.id) && $0.image != nil }
    }

    /// Imprimer (gratuit) : image brandée à l'event → feuille AirPrint (sharing box).
    private func printSelection() {
        let images = chosenPhotos.compactMap {
            PrintComposer.brandedImage(photo: $0.image!, event: viewModel.event)
        }
        guard !images.isEmpty else { return }
        PrintComposer.print(images, jobName: viewModel.event.name)
    }

    /// Télécharger en HD : coûte des reveals. Ouvre la boutique si le solde manque.
    private func downloadSelection() {
        let chosen = chosenPhotos
        guard !chosen.isEmpty else { return }
        let cost = chosen.count * downloadCostPerPhoto
        guard wallet.spend(cost) else { showPaywall = true; return }
        Task {
            for photo in chosen { await viewModel.saveToLibrary(photo) }
            selection.removeAll()
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
                VStack(spacing: 6) {
                    Text("Choisis les photos à imprimer (gratuit) ou télécharger en HD.")
                        .font(.caption).foregroundStyle(Theme.muted2)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 5) {
                            ForEach(viewModel.photos) { photo in
                                thumb(photo).onTapGesture { toggle(photo) }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 10)
            }
        }
        if let status = viewModel.statusText {
            Text(status).font(.footnote).foregroundStyle(Theme.muted).padding(.top, 6)
        }
    }

    private func toggle(_ photo: CloudPhoto) {
        guard photo.image != nil else { return }
        if selection.contains(photo.id) { selection.remove(photo.id) } else { selection.insert(photo.id) }
    }

    /// Barre du bas contextuelle : développer la sélection, ou (rien de sélectionné)
    /// partager ses propres photos gardées.
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Theme.line)
            if selection.isEmpty {
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
            } else {
                HStack(spacing: 10) {
                    Button(action: printSelection) {
                        VStack(spacing: 1) {
                            Text("Imprimer").font(.system(size: 15, weight: .semibold))
                            Text("gratuit").font(.caption2)
                        }
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line2, lineWidth: 1))
                    }
                    Button(action: downloadSelection) {
                        VStack(spacing: 1) {
                            Text("Télécharger HD").font(.system(size: 15, weight: .semibold))
                            Text("\(selection.count * downloadCostPerPhoto) reveals").font(.caption2)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Theme.txt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(16)
            }
        }
    }

    private func thumb(_ photo: CloudPhoto) -> some View {
        let selected = selection.contains(photo.id)
        return Group {
            if let image = photo.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.surface.overlay(ProgressView().tint(Theme.muted))
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.txt, lineWidth: selected ? 3 : 0))
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.txt, Theme.accent)
                    .padding(5)
            }
        }
        .opacity(photo.image == nil ? 0.6 : 1)
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
