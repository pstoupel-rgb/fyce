import SwiftUI
import Photos

/// Écran de revue d'un ami : son visage en haut (comme une icône), puis deux
/// onglets « Nouvelles photos » (deck façon Tinder) et « Partagées » (galerie).
struct FriendReviewView: View {
    @StateObject private var viewModel: FriendReviewViewModel

    enum Tab: String, CaseIterable { case new = "Nouvelles", shared = "Partagées" }
    @State private var tab: Tab = .new

    init(friend: Friend, store: FriendStore) {
        _viewModel = StateObject(wrappedValue: FriendReviewViewModel(friend: friend, store: store))
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            picker
            content
        }
        .padding(.top, 8)
        .navigationTitle(viewModel.friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancel() }
    }

    // MARK: - En-tête : visage de l'ami + compteurs

    private var header: some View {
        VStack(spacing: 10) {
            avatar
            Text(viewModel.friend.name).font(.title3.bold())
            HStack(spacing: 18) {
                counter(viewModel.remaining, "à trier")
                counter(viewModel.shared.count, "partagées")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var avatar: some View {
        Group {
            if let thumb = viewModel.friend.thumbnail {
                Image(uiImage: thumb).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(
            LinearGradient(colors: [Color(red: 0.49, green: 0.36, blue: 1),
                                    Color(red: 0.13, green: 0.83, blue: 0.93)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 3))
        .shadow(color: .purple.opacity(0.4), radius: 12, y: 4)
    }

    private func counter(_ value: Int, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").font(.footnote.bold()).foregroundStyle(.primary)
            Text(label)
        }
    }

    private var picker: some View {
        Picker("Vue", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Contenu selon l'onglet + la phase

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .scanning:
            scanningView
        case .needsAccess:
            message("Autorise l'accès aux photos", "Réglages → Photos → Poze",
                    system: "photo.on.rectangle")
        case .error(let msg):
            message("Oups", msg, system: "exclamationmark.triangle")
        case .ready:
            if tab == .new {
                SwipeDeckView(viewModel: viewModel)
            } else {
                SharedGalleryView(items: viewModel.shared, friendName: viewModel.friend.name)
            }
        }
        Spacer(minLength: 0)
    }

    private var scanningView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.3)
            if case .scanning(let processed, let total) = viewModel.phase {
                Text("Analyse de tes photos… \(processed)/\(total)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Reconnaissance 100 % sur ton téléphone")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                Text("Préparation du scan…").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func message(_ title: String, _ subtitle: String, system: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: system).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
}

/// Galerie des photos déjà partagées avec l'ami + bouton pour les envoyer.
private struct SharedGalleryView: View {
    let items: [ReviewPhoto]
    let friendName: String
    @State private var shareItems: [Any]?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 6)]

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 40)).foregroundStyle(.secondary)
                Text("Rien de partagé pour l'instant").font(.headline)
                Text("Garde des photos dans l'onglet « Nouvelles ».")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        } else {
            VStack(spacing: 12) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(items) { item in
                            thumb(item)
                        }
                    }
                    .padding(.horizontal)
                }
                Button {
                    shareItems = items.compactMap { $0.image }
                } label: {
                    Label("Envoyer à \(friendName)", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(
                            colors: [Color(red: 0.49, green: 0.36, blue: 1),
                                     Color(red: 0.13, green: 0.83, blue: 0.93)],
                            startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .disabled(items.allSatisfy { $0.image == nil })
            }
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } })) {
                if let shareItems { ActivityView(items: shareItems) }
            }
        }
    }

    private func thumb(_ item: ReviewPhoto) -> some View {
        Group {
            if let image = item.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(.ultraThinMaterial).overlay(ProgressView())
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
