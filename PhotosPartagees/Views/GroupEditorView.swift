import SwiftUI

/// Créer ou modifier un groupe : nom, couleur, symbole et membres.
struct GroupEditorView: View {
    @ObservedObject var store: FriendStore
    let group: FriendGroup?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var colorway: Colorway
    @State private var symbol: String
    @State private var selected: Set<UUID>

    init(store: FriendStore, group: FriendGroup?) {
        self.store = store
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _colorway = State(initialValue: group?.colorway ?? .aurora)
        _symbol = State(initialValue: group?.symbol ?? "person.2.fill")
        _selected = State(initialValue: Set(group?.memberIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                Form {
                    EditorFields(name: $name, colorway: $colorway, symbol: $symbol,
                                 symbols: Self.symbols, placeholder: "Nom du groupe")
                    MemberPicker(friends: store.friends, selected: $selected, colorway: colorway)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(group == nil ? "Nouveau groupe" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save).disabled(!canSave).bold()
                }
            }
        }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let updated = FriendGroup(id: group?.id ?? UUID(),
                                  name: name.trimmingCharacters(in: .whitespaces),
                                  colorway: colorway,
                                  memberIDs: Array(selected),
                                  symbol: symbol)
        store.addOrUpdate(updated)
        Haptics.success()
        dismiss()
    }

    static let symbols = ["person.2.fill", "house.fill", "heart.fill", "briefcase.fill",
                          "graduationcap.fill", "figure.2", "sportscourt.fill", "music.note",
                          "airplane", "star.fill", "gamecontroller.fill", "cup.and.saucer.fill"]
}

/// Champs communs aux éditeurs de groupe et d'event.
struct EditorFields: View {
    @Binding var name: String
    @Binding var colorway: Colorway
    @Binding var symbol: String
    let symbols: [String]
    let placeholder: String

    private let symbolCols = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    var body: some View {
        Section {
            TextField(placeholder, text: $name)
        }
        Section("Couleur") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Colorway.allCases) { c in
                        Circle()
                            .fill(c.gradient)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().strokeBorder(.white,
                                        lineWidth: colorway == c ? 3 : 0))
                            .onTapGesture { colorway = c }
                            .accessibilityLabel(c.label)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        Section("Symbole") {
            LazyVGrid(columns: symbolCols, spacing: 10) {
                ForEach(symbols, id: \.self) { s in
                    Image(systemName: s)
                        .font(.title3)
                        .frame(width: 52, height: 52)
                        .background(symbol == s ? AnyShapeStyle(colorway.gradient)
                                                : AnyShapeStyle(Color.white.opacity(0.08)),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(symbol == s ? .white : .primary)
                        .onTapGesture { symbol = s }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Sélection multiple des membres parmi les amis existants.
struct MemberPicker: View {
    let friends: [Friend]
    @Binding var selected: Set<UUID>
    let colorway: Colorway

    var body: some View {
        Section("Membres") {
            if friends.isEmpty {
                Text("Ajoute d'abord des amis pour les inclure ici.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(friends) { friend in
                    Button {
                        if selected.contains(friend.id) { selected.remove(friend.id) }
                        else { selected.insert(friend.id) }
                    } label: {
                        HStack(spacing: 12) {
                            avatar(friend)
                            Text(friend.name).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: selected.contains(friend.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(friend.id)
                                                 ? colorway.primary : Color.secondary)
                        }
                    }
                }
            }
        }
    }

    private func avatar(_ friend: Friend) -> some View {
        Group {
            if let thumb = friend.thumbnail {
                Image(uiImage: thumb).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }
}
