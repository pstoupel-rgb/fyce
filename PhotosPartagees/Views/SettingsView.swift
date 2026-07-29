import SwiftUI

/// Réglages : sensibilité du matching et gestion de l'historique des partages.
struct SettingsView: View {
    @ObservedObject var viewModel: ScanViewModel
    @ObservedObject var auth: AuthService
    @ObservedObject var appLock: AppLockService
    @ObservedObject var store: FriendStore
    @ObservedObject private var wallet = Wallet.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false
    @State private var showPaywall = false

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

                Section("Reveals") {
                    Button { showPaywall = true } label: {
                        HStack {
                            Label("\(wallet.reveals) reveals", systemImage: "sparkles")
                            Spacer()
                            Text("Boutique").foregroundStyle(Theme.accent)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        PrivacyCenterView(store: store)
                    } label: {
                        Label("Centre de confidentialité", systemImage: "hand.raised.fill")
                    }
                    Toggle(isOn: Binding(
                        get: { appLock.isEnabled },
                        set: { appLock.isEnabled = $0 })) {
                        Label("Verrou Face ID / code", systemImage: "faceid")
                    }
                    .disabled(!appLock.biometryAvailable)
                } header: {
                    Text("Confidentialité")
                } footer: {
                    Text(appLock.biometryAvailable
                         ? "Exige Face ID, Touch ID ou ton code pour ouvrir Poze."
                         : "Aucune authentification configurée sur cet appareil.")
                }

                Section("Compte") {
                    switch auth.status {
                    case .signedIn(let label):
                        LabeledContent("Connecté", value: label)
                        Button(role: .destructive) { auth.signOut() } label: {
                            Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    case .guest:
                        LabeledContent("Compte", value: "Invité (local)")
                        Button { auth.signOut() } label: {
                            Label("Créer un compte / se connecter", systemImage: "person.crop.circle.badge.plus")
                        }
                    case .signedOut:
                        EmptyView()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Réglages")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
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
