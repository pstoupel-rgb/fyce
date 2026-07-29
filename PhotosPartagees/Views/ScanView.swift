import SwiftUI

/// Écran principal : visage de référence, lancement du scan, progression et
/// affichage / validation des photos matchées.
struct ScanView: View {
    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ReferenceFaceView(viewModel: viewModel)

                actionSection

                statusSection

                if viewModel.matches.isEmpty {
                    emptyState
                } else {
                    selectionToolbar
                    PhotoGridView(
                        matches: viewModel.matches,
                        onToggle: viewModel.toggleSelection
                    )
                }
            }
            .padding()
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $viewModel.summary) { summary in
            UploadSummaryView(
                summary: summary,
                onRetry: viewModel.hasFailedUploads ? { viewModel.retryFailed() } : nil,
                onCopyLinks: viewModel.hasSharedLinks ? { await viewModel.copyShareLinks() } : nil
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

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
        case .idle, .finished:
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
        case .error(let message):
            label(message, systemImage: "xmark.octagon", color: .red)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch viewModel.state {
        case .finished:
            placeholder(
                title: "Aucune photo avec ton visage",
                systemImage: "person.crop.circle.badge.xmark",
                message: "Essaie d'ajuster la sensibilité dans les réglages."
            )
        case .idle, .needsReferenceFace:
            placeholder(
                title: "Prêt à scanner",
                systemImage: "photo.on.rectangle.angled",
                message: "Choisis ton visage de référence puis lance le scan."
            )
        default:
            EmptyView()
        }
    }

    private func placeholder(title: String, systemImage: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func label(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
