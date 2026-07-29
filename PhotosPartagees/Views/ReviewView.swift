import SwiftUI
import UIKit
import Photos

/// Écran de revue d'un sujet (ami, groupe ou event) : ses visages en haut, deux
/// onglets soulignés « Nouvelles » (deck) et « Partagées » (galerie). Sobre, la
/// photo au centre.
struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel

    enum Tab: String, CaseIterable { case new = "Nouvelles", shared = "Partagées" }
    @State private var tab: Tab = .new
    @State private var recapItems: [Any]?

    init(subject: ReviewSubject, store: ReviewHistoryStoring) {
        _viewModel = StateObject(wrappedValue: ReviewViewModel(subject: subject, store: store))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabs
                content
            }
        }
        .navigationTitle(viewModel.subject.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if viewModel.phase == .ready {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareRecap) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Partager mon récap")
                }
            }
        }
        .sheet(isPresented: Binding(get: { recapItems != nil }, set: { if !$0 { recapItems = nil } })) {
            if let recapItems { ActivityView(items: recapItems) }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancel() }
    }

    private func shareRecap() {
        let total = viewModel.remaining + viewModel.shared.count
        let card = ShareCard(bigNumber: total,
                             line1: "photos retrouvées",
                             line2: "avec \(viewModel.subject.title) sur Poze")
        if let image = ShareCardRenderer.image(card) {
            recapItems = [image, "J'ai retrouvé mes photos avec Poze 📸"]
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 7) {
            AvatarStack(images: viewModel.subject.avatars)
            Text(viewModel.subject.title).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.txt)
            Text(metaLine).font(.system(size: 12.5)).foregroundStyle(Theme.muted)
        }
        .padding(.top, 10)
    }

    private var metaLine: String {
        "\(viewModel.subject.subtitle) · \(viewModel.remaining) à trier"
    }

    private var tabs: some View {
        HStack(spacing: 26) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.easeOut(duration: 0.15)) { tab = t } } label: {
                    VStack(spacing: 9) {
                        Text(t.rawValue)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(tab == t ? Theme.txt : Theme.muted)
                        Rectangle().fill(tab == t ? Theme.txt : .clear)
                            .frame(height: 2).frame(width: 46)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .padding(.bottom, 2)
    }

    // MARK: - Contenu

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .scanning:
            scanningView
        case .needsAccess:
            message("Autorise l'accès aux photos", "Réglages → Photos → Poze", system: "photo.on.rectangle")
        case .noReference:
            message("Ajoute d'abord des membres", "Ce sujet n'a aucun visage de référence à chercher.",
                    system: "person.crop.circle.badge.questionmark")
        case .error(let msg):
            message("Oups", msg, system: "exclamationmark.triangle")
        case .ready:
            if tab == .new {
                SwipeDeckView(viewModel: viewModel)
            } else {
                SharedGalleryView(items: viewModel.shared, subjectTitle: viewModel.subject.title)
            }
        }
        Spacer(minLength: 0)
    }

    private var scanningView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Theme.txt).scaleEffect(1.2)
            if case .scanning(let processed, let total) = viewModel.phase {
                Text("Analyse de tes photos… \(processed)/\(total)")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                Text("Reconnaissance 100 % sur ton téléphone")
                    .font(.caption).foregroundStyle(Theme.muted2)
            } else {
                Text("Préparation…").font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }

    private func message(_ title: String, _ subtitle: String, system: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: system).font(.system(size: 38)).foregroundStyle(Theme.muted2)
            Text(title).font(.headline).foregroundStyle(Theme.txt)
            Text(subtitle).font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .padding()
    }
}

/// Pile d'avatars superposés à fin liseré (un ami = un cercle ; un groupe = plusieurs).
struct AvatarStack: View {
    let images: [UIImage?]
    var diameter: CGFloat = 70

    var body: some View {
        let shown = Array(images.prefix(4))
        HStack(spacing: -diameter * 0.34) {
            if shown.isEmpty {
                circle(nil, index: 0)
            } else {
                ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                    circle(pair.element, index: pair.offset)
                }
            }
        }
    }

    private func circle(_ image: UIImage?, index: Int) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.surface2.overlay(Image(systemName: "person.fill").foregroundStyle(Theme.muted2))
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.line2, lineWidth: 1))
        .background(Circle().fill(Theme.bg).padding(-2))
        .zIndex(Double(-index))
    }
}

/// Galerie des photos partagées + bouton d'envoi natif (blanc franc).
private struct SharedGalleryView: View {
    let items: [ReviewPhoto]
    let subjectTitle: String
    @State private var shareItems: [Any]?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 5)]

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.slash").font(.system(size: 38)).foregroundStyle(Theme.muted2)
                Text("Rien de partagé pour l'instant").font(.headline).foregroundStyle(Theme.txt)
                Text("Garde des photos dans l'onglet « Nouvelles ».")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            VStack(spacing: 12) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(items) { thumb($0) }
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }
                Button {
                    shareItems = items.compactMap { $0.image }
                } label: {
                    Text("Envoyer \(items.count) photo\(items.count > 1 ? "s" : "")")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.txt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
                .disabled(items.allSatisfy { $0.image == nil })
            }
            .sheet(isPresented: Binding(
                get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
                if let shareItems { ActivityView(items: shareItems) }
            }
        }
    }

    private func thumb(_ item: ReviewPhoto) -> some View {
        Group {
            if let image = item.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.surface.overlay(ProgressView().tint(Theme.muted))
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
