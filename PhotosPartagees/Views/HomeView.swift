import SwiftUI

/// L'écran d'accueil-vitrine : fond aurora vivant, tuiles en verre pour tes
/// groupes et events personnalisés, et tes amis en accès rapide. Tout est
/// configurable — c'est ta page à toi.
struct HomeView: View {
    @EnvironmentObject private var store: FriendStore
    @State private var sheet: HomeSheet?

    private let gridColumns = [GridItem(.flexible(), spacing: 14),
                               GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        hero
                        groupsSection
                        eventsSection
                        friendsSection
                        Color.clear.frame(height: 16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sheet, content: sheetContent)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Poze")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.brandGradient)
            Text("Retrouve tes photos, avec les bonnes personnes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Groupes

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Mes groupes", systemAdd: "plus") { sheet = .newGroup }
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(store.groups) { group in
                    let members = store.members(ofIDs: group.memberIDs)
                    NavigationLink {
                        ReviewView(subject: .group(group, members: members), store: store)
                    } label: {
                        GroupTile(group: group, members: members)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { sheet = .editGroup(group) } label: { Label("Modifier", systemImage: "pencil") }
                        Button(role: .destructive) { store.remove(group) } label: { Label("Supprimer", systemImage: "trash") }
                    }
                }
                AddTile(title: "Nouveau groupe") { sheet = .newGroup }
            }
            if store.groups.isEmpty {
                hint("Crée un groupe (Famille, Potes, Boulot…) pour scanner d'un coup toutes tes photos de ses membres.")
            }
        }
    }

    // MARK: - Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Events", systemAdd: "plus") { sheet = .newEvent }
            if store.events.isEmpty {
                hint("Ajoute un event (soirée, mariage, vacances) pour retrouver qui était là.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(store.events) { event in
                            let members = store.members(ofIDs: event.memberIDs)
                            NavigationLink {
                                ReviewView(subject: .event(event, members: members), store: store)
                            } label: {
                                EventCard(event: event, members: members)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { sheet = .editEvent(event) } label: { Label("Modifier", systemImage: "pencil") }
                                Button(role: .destructive) { store.remove(event) } label: { Label("Supprimer", systemImage: "trash") }
                            }
                        }
                        AddTile(title: "Nouvel event", compact: true) { sheet = .newEvent }
                            .frame(width: 150)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Amis

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Amis", systemAdd: "plus") { sheet = .addFriend }
            if store.friends.isEmpty {
                hint("Ajoute un ami depuis une photo : l'app retrouvera ensuite toutes tes photos de lui.")
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
                        addFriendChip
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var addFriendChip: some View {
        Button { sheet = .addFriend } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 64, height: 64)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                    .foregroundStyle(.secondary)
                Text("Ajouter").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Briques

    private func sectionHeader(_ title: String, systemAdd: String, add: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.title3.bold())
            Spacer()
            Button(action: add) {
                Image(systemName: systemAdd).font(.subheadline.weight(.bold))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func sheetContent(_ sheet: HomeSheet) -> some View {
        switch sheet {
        case .newGroup:            GroupEditorView(store: store, group: nil)
        case .editGroup(let g):    GroupEditorView(store: store, group: g)
        case .newEvent:            EventEditorView(store: store, event: nil)
        case .editEvent(let e):    EventEditorView(store: store, event: e)
        case .addFriend:           AddFriendView(store: store)
        }
    }
}

/// Les feuilles présentables depuis l'accueil.
enum HomeSheet: Identifiable {
    case newGroup, editGroup(FriendGroup), newEvent, editEvent(PozeEvent), addFriend

    var id: String {
        switch self {
        case .newGroup: return "newGroup"
        case .editGroup(let g): return "editGroup-\(g.id)"
        case .newEvent: return "newEvent"
        case .editEvent(let e): return "editEvent-\(e.id)"
        case .addFriend: return "addFriend"
        }
    }
}

// MARK: - Tuiles

private struct GroupTile: View {
    let group: FriendGroup
    let members: [Friend]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: group.symbol)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(group.colorway.gradient,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                    MiniAvatars(members: members)
                }
                Spacer(minLength: 6)
                Text(group.name).font(.headline).lineLimit(1)
                Text("\(members.count) membre\(members.count > 1 ? "s" : "")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(height: 150, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shadow(color: group.colorway.primary.opacity(0.30), radius: 16, y: 8)
    }
}

private struct EventCard: View {
    let event: PozeEvent
    let members: [Friend]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(event.colorway.gradient)
                .opacity(0.85)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial).opacity(0.25)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: event.symbol).font(.headline)
                    Spacer()
                    MiniAvatars(members: members)
                }
                Spacer()
                Text(event.name).font(.headline).lineLimit(1)
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(14)
        }
        .frame(width: 200, height: 150)
        .shadow(color: event.colorway.primary.opacity(0.35), radius: 16, y: 8)
    }
}

private struct FriendChip: View {
    let friend: Friend

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let thumb = friend.thumbnail {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFit().foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.brandGradient, lineWidth: 2.5))
            Text(friend.name).font(.caption2).lineLimit(1).frame(width: 72)
        }
    }
}

/// Petites pastilles de visages superposées pour les tuiles.
private struct MiniAvatars: View {
    let members: [Friend]
    var diameter: CGFloat = 26

    var body: some View {
        let shown = Array(members.prefix(3))
        HStack(spacing: -diameter * 0.4) {
            ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                Group {
                    if let thumb = pair.element.thumbnail {
                        Image(uiImage: thumb).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit().foregroundStyle(.secondary)
                    }
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            }
            if members.count > 3 {
                Text("+\(members.count - 3)")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: diameter, height: diameter)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
}

private struct AddTile: View {
    let title: String
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus").font(.title2.weight(.semibold))
                Text(title).font(.footnote.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(.ultraThinMaterial.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.white.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }
}
