import SwiftUI

/// Centre de confidentialité : la confiance rendue *vérifiable*. Transparence sur
/// ce qui est stocké (et où), export de portabilité, et droit à l'oubli.
struct PrivacyCenterView: View {
    @ObservedObject var store: FriendStore
    @State private var summary = FriendStore.DataSummary(friends: 0, groups: 0, events: 0, facePrints: 0, sharedRecords: 0)
    @State private var exportItems: [Any]?
    @State private var showWipeConfirm = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            List {
                Section {
                    ForEach(pledges, id: \.text) { pledge in
                        Label {
                            Text(pledge.text).font(.subheadline)
                        } icon: {
                            Image(systemName: pledge.icon).foregroundStyle(Theme.ok)
                        }
                    }
                } header: {
                    Text("Nos engagements")
                } footer: {
                    Text("La reconnaissance des visages est calculée sur ton appareil (Vision). Les empreintes sont chiffrées (AES-GCM) et ne quittent jamais ton téléphone.")
                }

                Section("Ce qui est stocké sur cet appareil") {
                    row("Amis", summary.friends)
                    row("Empreintes de visage (chiffrées)", summary.facePrints)
                    row("Groupes", summary.groups)
                    row("Events", summary.events)
                    row("Photos marquées partagées", summary.sharedRecords)
                }

                Section {
                    Button {
                        if let data = store.exportJSON() {
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("poze-export.json")
                            try? data.write(to: url)
                            exportItems = [url]
                        }
                    } label: {
                        Label("Exporter mes données (JSON)", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Export de portabilité : noms, groupes et events. Aucune empreinte de visage n'est incluse.")
                }

                Section {
                    Button(role: .destructive) {
                        showWipeConfirm = true
                    } label: {
                        Label("Tout effacer sur cet appareil", systemImage: "trash")
                    }
                } footer: {
                    Text("Supprime définitivement amis, empreintes, groupes, events, historique et clés. Irréversible.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Confidentialité")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { summary = store.dataSummary() }
        .sheet(isPresented: Binding(get: { exportItems != nil }, set: { if !$0 { exportItems = nil } })) {
            if let exportItems { ActivityView(items: exportItems) }
        }
        .confirmationDialog("Tout effacer ?", isPresented: $showWipeConfirm, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                store.wipeAll()
                summary = store.dataSummary()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
    }

    private func row(_ label: String, _ value: Int) -> some View {
        LabeledContent(label) { Text("\(value)").monospacedDigit().foregroundStyle(Theme.muted) }
    }

    private let pledges: [(icon: String, text: String)] = [
        ("iphone", "Tout reste sur ton téléphone."),
        ("lock.fill", "Les empreintes de visage sont chiffrées au repos."),
        ("antenna.radiowaves.left.and.right.slash", "Aucun tracking, aucune publicité, aucun analytics tiers."),
        ("hand.raised.fill", "Consentement parental requis pour les mineurs.")
    ]
}
