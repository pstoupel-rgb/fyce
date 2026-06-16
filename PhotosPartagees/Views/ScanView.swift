import SwiftUI

/// Écran principal : configuration du visage de référence, lancement du scan,
/// suivi de la progression et affichage des photos matchées.
struct ScanView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ReferenceFaceView(viewModel: viewModel)

                settingsSection

                actionSection

                statusSection

                if !viewModel.matches.isEmpty {
                    selectionToolbar
                    PhotoGridView(
                        matches: viewModel.matches,
                        onToggle: viewModel.toggleSelection
                    )
                }
            }
            .padding()
        }
        .sheet(item: $viewModel.summary) { summary in
            UploadSummaryView(
                summary: summary,
                onRetry: viewModel.hasFailedUploads ? { viewModel.retryFailed() } : nil
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sensibilité")
                Slider(value: Binding(
                    get: { Double(viewModel.threshold) },
                    set: { viewModel.threshold = Float($0) }
                ), in: 0.3...1.0)
                Text(String(format: "%.2f", viewModel.threshold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if case .scanning = viewModel.state {
                Button(role: .destructive) {
                    viewModel.cancelScan()
                } label: {
                    Label("Annuler le scan", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    viewModel.startScan()
                } label: {
                    Label("Scanner ma photothèque", systemImage: "sparkles.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasReferenceFace)
            }

            if !viewModel.matches.isEmpty {
                Button {
                    viewModel.uploadSelected()
                } label: {
                    Label(
                        "Partager la sélection (\(viewModel.selectedCount))",
                        systemImage: "icloud.and.arrow.up"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasUploadableSelection)
            }
        }
    }

    private var selectionToolbar: some View {
        HStack {
            Text("\(viewModel.selectedCount) sélectionnée(s) sur \(viewModel.matches.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Tout") { viewModel.selectAll() }
                .font(.subheadline)
            Button("Aucune") { viewModel.deselectAll() }
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .needsReferenceFace:
            label("Choisis d'abord un visage de référence.", systemImage: "exclamationmark.triangle", color: .orange)
        case .scanning(let processed, let total):
            VStack(spacing: 8) {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                Text("Analyse \(processed)/\(total) — \(viewModel.matches.count) match(s)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .finished(let count):
            label("Terminé : \(count) photo(s) avec ton visage.", systemImage: "checkmark.circle", color: .green)
        case .error(let message):
            label(message, systemImage: "xmark.octagon", color: .red)
        }
    }

    private func label(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
