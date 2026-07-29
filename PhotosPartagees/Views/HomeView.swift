import SwiftUI
import UIKit

/// Écran d'accueil « éditorial » : wordmark discret, groupes en lignes avec
/// vignette réelle et pastille de couleur sobre, events en couverture photo,
/// amis en accès rapide. Calme, lisible, la photo au centre.
struct HomeView: View {
    @EnvironmentObject private var store: FriendStore
    @State private var sheet: HomeSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        header
                        groupsSection
                        eventsSection
                        friendsSection
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet, content: sheetContent)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Wordmark()
                Text("Retrouve tes photos, avec les bonnes personnes.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { sheet = .activity } label: {
                Image(systemName: "bell").font(.body.weight(.medium)).foregroundStyle(Theme.txt)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Activité — nouvelles photos de toi")
        }
        .padding(.top, 8)
    }

    // MARK: - Groupes

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Groupes") {
                Button { sheet = .newGroup } label: { addGlyph }
            }
            if store.groups.isEmpty {
                EmptyLine(text: "Crée un groupe (Famille, Potes…) pour scanner d'un coup toutes tes photos de ses membres.") { sheet = .newGroup }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.groups.enumerated()), id: \.element.id) { pair in
                        let group = pair.element
                        let members = store.members(ofIDs: group.memberIDs)
                        NavigationLink {
                            ReviewView(subject: .group(group, members: members), store: store)
                        } label: {
                            GroupRow(group: group, members: members, showDivider: pair.offset > 0)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { sheet = .editGroup(group) } label: { Label("Modifier", systemImage: "pencil") }
                            Button(role: .destructive) { store.remove(group) } label: { Label("Supprimer", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Events") {
                HStack(spacing: 14) {
                    Button { sheet = .joinEvent } label: {
                        Image(systemName: "qrcode.viewfinder").font(.body).foregroundStyle(Theme.muted)
                    }
                    .accessibilityLabel("Rejoindre un event en scannant un QR")
                    Button { sheet = .newEvent } label: { addGlyph }
                }
            }
            if store.events.isEmpty {
                EmptyLine(text: "Ajoute un event (soirée, mariage, vacances) pour retrouver qui était là.") { sheet = .newEvent }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.events) { event in
                            let members = store.members(ofIDs: event.memberIDs)
                            NavigationLink {
                                ReviewView(subject: .event(event, members: members), store: store)
                            } label: {
                                EventCoverCard(event: event, members: members)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { sheet = .shareEvent(event) } label: { Label("Partager (QR code)", systemImage: "qrcode") }
                                if EventBackendService.shared.isEnabled {
                                    Button { sheet = .eventCloud(event) } label: { Label("Photos de l'event", systemImage: "icloud") }
                                }
                                Button { sheet = .editEvent(event) } label: { Label("Modifier", systemImage: "pencil") }
                                Button(role: .destructive) { store.remove(event) } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -20)
                .padding(.leading, 20)
            }
        }
    }

    // MARK: - Amis

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Amis") {
                Button { sheet = .addFriend } label: { addGlyph }
            }
            if store.friends.isEmpty {
                EmptyLine(text: "Ajoute un ami depuis une photo : l'app retrouvera ensuite toutes tes photos de lui.") { sheet = .addFriend }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(store.friends) { friend in
                            NavigationLink {
                                ReviewView(subject: .friend(friend), store: store)
                            } label: {
                                FriendChip(friend: friend)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { store.remove(friend) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                        Button { sheet = .addFriend } label: { AddChip() }
                            .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -20)
                .padding(.leading, 20)
            }
        }
    }

    private var addGlyph: some View {
        Image(systemName: "plus").font(.body.weight(.medium)).foregroundStyle(Theme.muted)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .newGroup:            GroupEditorView(store: store, group: nil)
        case .editGroup(let g):    GroupEditorView(store: store, group: g)
        case .newEvent:            EventEditorView(store: store, event: nil)
        case .editEvent(let e):    EventEditorView(store: store, event: e)
        case .shareEvent(let e):   EventShareView(event: e)
        case .eventCloud(let e):   EventCloudView(event: e, store: store)
        case .joinEvent:           EventJoinView(store: store)
        case .addFriend:           AddFriendView(store: store)
        case .activity:            ActivityFeedView()
        }
    }
}

/// Les feuilles présentables depuis l'accueil.
enum HomeSheet: Identifiable {
    case newGroup, editGroup(FriendGroup)
    case newEvent, editEvent(PozeEvent), shareEvent(PozeEvent), eventCloud(PozeEvent), joinEvent
    case addFriend, activity

    var id: String {
        switch self {
        case .newGroup: return "newGroup"
        case .editGroup(let g): return "editGroup-\(g.id)"
        case .newEvent: return "newEvent"
        case .editEvent(let e): return "editEvent-\(e.id)"
        case .shareEvent(let e): return "shareEvent-\(e.id)"
        case .eventCloud(let e): return "eventCloud-\(e.id)"
        case .joinEvent: return "joinEvent"
        case .addFriend: return "addFriend"
        case .activity: return "activity"
        }
    }
}

// MARK: - Wordmark

/// « poze » sobre, avec le « o » traité comme un objectif (anneau).
struct Wordmark: View {
    var size: CGFloat = 30
    var body: some View {
        HStack(spacing: 0) {
            Text("p").font(.system(size: size, weight: .semibold))
            ApertureO(size: size * 0.82)
            Text("ze").font(.system(size: size, weight: .semibold))
        }
        .tracking(-0.5)
        .foregroundStyle(Theme.txt)
    }
}

/// Le « o » = un diaphragme stylisé (deux anneaux fins).
struct ApertureO: View {
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.txt, lineWidth: size * 0.14)
            Circle().strokeBorder(Theme.txt.opacity(0.35), lineWidth: 1)
                .padding(size * 0.26)
        }
        .frame(width: size, height: size)
        .padding(.horizontal, 1)
    }
}

// MARK: - Briques d'accueil

private struct SectionLabel<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption).fontWeight(.semibold)
                .tracking(1.6).foregroundStyle(Theme.muted)
            Spacer()
            trailing
        }
        .padding(.top, 26).padding(.bottom, 12)
    }
}

private struct GroupRow: View {
    let group: FriendGroup
    let members: [Friend]
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            if showDivider { Divider().overlay(Theme.line) }
            HStack(spacing: 14) {
                Circle().fill(group.colorway.primary).frame(width: 9, height: 9)
                Cover(image: members.first?.thumbnail, tint: group.colorway.primary, size: 46, corner: 13)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt)
                    Text(memberLine).font(.system(size: 12.5)).foregroundStyle(Theme.muted)
                }
                Spacer()
                MiniAvatars(members: members)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted2)
            }
            .padding(.vertical, 15)
        }
    }

    private var memberLine: String {
        let n = members.count
        return "\(n) personne\(n > 1 ? "s" : "")"
    }
}

private struct EventCoverCard: View {
    let event: PozeEvent
    let members: [Friend]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Cover(image: members.first?.thumbnail, tint: event.colorway.primary, size: nil, corner: 16)
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .center, endPoint: .bottom)
            Circle().fill(event.colorway.primary).frame(width: 7, height: 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.white)
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.72))
            }
            .padding(12)
        }
        .frame(width: 168, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }
}

private struct FriendChip: View {
    let friend: Friend
    var body: some View {
        VStack(spacing: 7) {
            Cover(image: friend.thumbnail, tint: Theme.surface2, size: 56, corner: 28)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.line2, lineWidth: 1))
            Text(friend.name).font(.system(size: 11)).foregroundStyle(Theme.muted)
                .lineLimit(1).frame(width: 62)
        }
    }
}

private struct AddChip: View {
    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "plus").font(.title3).foregroundStyle(Theme.muted)
                .frame(width: 56, height: 56)
                .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(Theme.line2))
            Text("Ajouter").font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
    }
}

/// Vignette : photo réelle si disponible, sinon un aplat teinté sobre.
private struct Cover: View {
    let image: UIImage?
    let tint: Color
    let size: CGFloat?
    let corner: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [tint.opacity(0.5), Theme.surface],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(Theme.muted2))
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: size == nil ? .infinity : nil, maxHeight: size == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

private struct MiniAvatars: View {
    let members: [Friend]
    var body: some View {
        let shown = Array(members.prefix(3))
        HStack(spacing: -8) {
            ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                Cover(image: pair.element.thumbnail, tint: Theme.surface2, size: 22, corner: 11)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 1.5))
            }
        }
    }
}

private struct EmptyLine: View {
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(text).font(.footnote).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
