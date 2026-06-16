import SwiftUI

/// Récapitulatif affiché à la fin d'un partage : nombre de succès / d'échecs,
/// avec possibilité de relancer les photos en échec.
struct UploadSummaryView: View {
    let summary: UploadSummary
    /// Fourni uniquement s'il reste des échecs à relancer.
    let onRetry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: summary.hasFailures ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(summary.hasFailures ? .orange : .green)
                    .padding(.top, 32)

                Text(summary.hasFailures ? "Partage terminé avec des erreurs" : "Partage réussi")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    row(icon: "checkmark.circle.fill", color: .green,
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

                    Button("Fermer") { dismiss() }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    private func row(icon: String, color: Color, text: String) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
    }
}
