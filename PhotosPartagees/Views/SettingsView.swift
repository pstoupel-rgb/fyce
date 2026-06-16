import SwiftUI

/// Réglages : sensibilité du matching et gestion de l'historique des partages.
struct SettingsView: View {
    @ObservedObject var viewModel: ScanViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Sensibilité")
                            Spacer()
                            Text(String(format: "%.2f", viewModel.threshold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(viewModel.threshold) },
                            set: { viewModel.threshold = Float($0) }
                        ), in: 0.3...1.0)
                    }
                } header: {
                    Text("Matching")
                } footer: {
                    Text("Plus la valeur est basse, plus le matching est strict.")
                }

                Section {
                    LabeledContent("Photos partagées", value: "\(viewModel.sharedCount)")
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Réinitialiser l'historique", systemImage: "trash")
                    }
                    .disabled(viewModel.sharedCount == 0)
                } header: {
                    Text("Historique des partages")
                } footer: {
                    Text("Les photos déjà partagées ne sont pas reproposées. Réinitialiser permet de les repartager.")
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .confirmationDialog(
                "Réinitialiser l'historique des partages ?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Réinitialiser", role: .destructive) { viewModel.resetSharedHistory() }
                Button("Annuler", role: .cancel) {}
            }
        }
    }
}
