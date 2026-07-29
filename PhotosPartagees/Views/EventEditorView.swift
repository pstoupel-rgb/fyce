import SwiftUI

/// Créer ou modifier un event : nom, date, couleur, symbole et participants.
struct EventEditorView: View {
    @ObservedObject var store: FriendStore
    let event: PozeEvent?
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var date: Date
    @State private var colorway: Colorway
    @State private var symbol: String
    @State private var selected: Set<UUID>
    @State private var showShare = false

    init(store: FriendStore, event: PozeEvent?) {
        self.store = store
        self.event = event
        _name = State(initialValue: event?.name ?? "")
        _date = State(initialValue: event?.date ?? Date())
        _colorway = State(initialValue: event?.colorway ?? .sunset)
        _symbol = State(initialValue: event?.symbol ?? "party.popper.fill")
        _selected = State(initialValue: Set(event?.memberIDs ?? []))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                Form {
                    EditorFields(name: $name, colorway: $colorway, symbol: $symbol,
                                 symbols: Self.symbols, placeholder: "Nom de l'event")
                    Section("Date") {
                        DatePicker("Quand", selection: $date, displayedComponents: .date)
                    }
                    MemberPicker(friends: store.friends, selected: $selected, colorway: colorway)

                    if let event {
                        Section("Inviter") {
                            Button {
                                showShare = true
                            } label: {
                                Label("Partager via QR code", systemImage: "qrcode")
                            }
                            Text("Code : \(event.joinCode)")
                                .font(.footnote.monospaced()).foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(event == nil ? "Nouvel event" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save).disabled(!canSave).bold()
                }
            }
            .sheet(isPresented: $showShare) {
                if let event { EventShareView(event: event) }
            }
        }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let updated = PozeEvent(id: event?.id ?? UUID(),
                                name: name.trimmingCharacters(in: .whitespaces),
                                date: date,
                                colorway: colorway,
                                memberIDs: Array(selected),
                                symbol: symbol)
        store.addOrUpdate(updated)
        // Best-effort : crée aussi l'event côté serveur si Supabase est configuré.
        if EventBackendService.shared.isEnabled {
            Task { try? await EventBackendService.shared.createEvent(
                name: updated.name, joinCode: updated.joinCode, startsAt: updated.date) }
        }
        Haptics.success()
        dismiss()
    }

    static let symbols = ["party.popper.fill", "music.mic", "wineglass.fill", "birthday.cake.fill",
                          "airplane", "beach.umbrella.fill", "gift.fill", "sparkles",
                          "figure.dance", "fireworks", "camera.fill", "heart.fill"]
}
