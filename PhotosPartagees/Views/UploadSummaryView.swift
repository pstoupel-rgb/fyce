import SwiftUI

/// Récapitulatif affiché à la fin d'un partage : succès / échecs, relance des
/// échecs et copie des liens de partage signés.
struct UploadSummaryView: View {
    let summary: UploadSummary
    /// Fourni uniquement s'il reste des échecs à relancer.
    let onRetry: (() -> Void)?
    /// Fourni si des liens de partage peuvent être générés. Renvoie le nombre copié.
    let onCopyLinks: (() async -> Int)?

    @Environment(\.dismiss) private var dismiss
    @State private var copyState: CopyState = .idle

    private enum CopyState: Equatable {
        case idle, copying, copied(Int)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: summary.hasFailures ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(summary.hasFailures ? Color(hex: 0xd9a066) : Theme.ok)
                    .padding(.top, 32)

                Text(summary.hasFailures ? "Partage terminé avec des erreurs" : "Partage réussi")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    row(icon: "checkmark.circle.fill", color: Theme.ok,
                        text: "\(summary.succeeded) photo(s) partagée(s)")
                    if summary.hasFailures {
                        row(icon: "xmark.circle.fill", color: .red,
                            text: "\(summary.failed) échec(s)")
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    if let onRetry {
                        Button {
                            onRetry()
                            dismiss()
                        } label: {
                            Label("Réessayer les échecs", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let onCopyLinks {
                        Button {
                            Task { await copyLinks(onCopyLinks) }
                        } label: {
                            Label(copyLabel, systemImage: copyIcon)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(copyState == .copying)
                    }

                    Button("Fermer") { dismiss() }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Theme.bg.ignoresSafeArea())
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var copyLabel: String {
        switch copyState {
        case .idle: return "Copier les liens de partage"
        case .copying: return "Génération des liens…"
        case .copied(let count): return "\(count) lien(s) copié(s)"
        }
    }

    private var copyIcon: String {
        if case .copied = copyState { return "checkmark" }
        return "link"
    }

    private func copyLinks(_ action: () async -> Int) async {
        copyState = .copying
        let count = await action()
        copyState = .copied(count)
    }

    private func row(icon: String, color: Color, text: String) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
    }
}
