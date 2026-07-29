import SwiftUI
import Photos

/// Écran de revue d'un sujet (ami, groupe ou event) : ses visages en haut, puis
/// deux onglets « Nouvelles » (deck façon Tinder) et « Partagées » (galerie).
struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel
    private let colorway: Colorway

    enum Tab: String, CaseIterable { case new = "Nouvelles", shared = "Partagées" }
    @State private var tab: Tab = .new

    init(subject: ReviewSubject, store: ReviewHistoryStoring) {
        _viewModel = StateObject(wrappedValue: ReviewViewModel(subject: subject, store: store))
        self.colorway = subject.colorway
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 16) {
                header
                picker
                content
            }
            .padding(.top, 8)
        }
        .navigationTitle(viewModel.subject.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancel() }
    }

    // MARK: - En-tête : visages du sujet + compteurs

    private var header: some View {
        VStack(spacing: 10) {
            AvatarStack(images: viewModel.subject.avatars, colorway: colorway)
            Text(viewModel.subject.title).font(.title3.bold())
            Text(viewModel.subject.subtitle).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 18) {
                counter(viewModel.remaining, "à trier")
                counter(viewModel.shared.count, "partagées")
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
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

    // MARK: - Contenu selon la phase + l'onglet

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .scanning:
            scanningView
        case .needsAccess:
            message("Autorise l'accès aux photos", "Réglages → Photos → Poze",
                    system: "photo.on.rectangle")
        case .noReference:
            message("Ajoute d'abord des membres",
                    "Ce sujet n'a aucun visage de référence à chercher.",
                    system: "person.crop.circle.badge.questionmark")
        case .error(let msg):
            message("Oups", msg, system: "exclamationmark.triangle")
        case .ready:
            if tab == .new {
                SwipeDeckView(viewModel: viewModel)
            } else {
                SharedGalleryView(items: viewModel.shared,
                                  subjectTitle: viewModel.subject.title,
                                  colorway: colorway)
            }
        }
        Spacer(minLength: 0)
    }

    private var scanningView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.3).tint(colorway.primary)
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

/// Pile d'avatars superposés (un ami = un cercle ; un groupe = plusieurs).
struct AvatarStack: View {
    let images: [UIImage?]
    let colorway: Colorway
    var diameter: CGFloat = 88

    var body: some View {
        let shown = Array(images.prefix(4))
        return HStack(spacing: -diameter * 0.32) {
            if shown.isEmpty {
                circle(nil, index: 0)
            } else {
                ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                    circle(pair.element, index: pair.offset)
                }
            }
            if images.count > 4 {
                Text("+\(images.count - 4)")
                    .font(.subheadline.bold())
                    .frame(width: diameter * 0.62, height: diameter * 0.62)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(colorway.gradient, lineWidth: 2))
            }
        }
        .shadow(color: colorway.primary.opacity(0.4), radius: 14, y: 5)
    }

    private func circle(_ image: UIImage?, index: Int) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(colorway.gradient, lineWidth: 3))
        .zIndex(Double(-index))
    }
}

/// Galerie des photos déjà partagées avec le sujet + bouton d'envoi natif.
private struct SharedGalleryView: View {
    let items: [ReviewPhoto]
    let subjectTitle: String
    let colorway: Colorway
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
                        ForEach(items) { thumb($0) }
                    }
                    .padding(.horizontal)
                }
                Button {
                    shareItems = items.compactMap { $0.image }
                } label: {
                    Label("Envoyer \(items.count) photo\(items.count > 1 ? "s" : "")",
                          systemImage: "square.and.arrow.up")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(colorway.gradient, in: RoundedRectangle(cornerRadius: 16))
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
