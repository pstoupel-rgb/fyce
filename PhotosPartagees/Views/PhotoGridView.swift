import SwiftUI
import Photos

/// Grille des photos matchées. Chaque vignette est sélectionnable (validation par
/// l'utilisateur de ce qu'il souhaite partager) et prévisualisable en plein écran.
struct PhotoGridView: View {
    let matches: [MatchedPhoto]
    let onToggle: (String) -> Void

    @State private var previewMatch: MatchedPhoto?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Photos matchées (\(matches.count))")
                .font(.headline)

            // Regroupement par mois (du plus récent au plus ancien).
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(section.items) { match in
                            MatchedThumbnail(
                                match: match,
                                onToggle: { onToggle(match.id) },
                                onPreview: { previewMatch = match }
                            )
                        }
                    }
                }
            }
        }
        .sheet(item: $previewMatch) { match in
            PhotoPreviewView(
                match: match,
                isSelected: currentSelection(for: match.id),
                onToggle: { onToggle(match.id) }
            )
        }
    }

    private func currentSelection(for id: String) -> Bool {
        matches.first(where: { $0.id == id })?.isSelected ?? false
    }

    // MARK: - Regroupement par date

    private struct PhotoSection: Identifiable {
        let id: Date          // premier jour du mois
        let title: String
        let items: [MatchedPhoto]
    }

    private var sections: [PhotoSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: matches) { match -> Date in
            let date = match.photo.asset.creationDate ?? .distantPast
            let comps = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: comps) ?? .distantPast
        }
        return grouped.keys.sorted(by: >).map { key in
            let items = grouped[key]!.sorted {
                ($0.photo.asset.creationDate ?? .distantPast) > ($1.photo.asset.creationDate ?? .distantPast)
            }
            return PhotoSection(id: key, title: Self.monthFormatter.string(from: key), items: items)
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}

/// Vignette unitaire : tap = sélection/désélection, loupe = aperçu plein écran.
private struct MatchedThumbnail: View {
    let match: MatchedPhoto
    let onToggle: () -> Void
    let onPreview: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.secondarySystemBackground)
                        .overlay(ProgressView())
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(match.isSelected ? 1 : 0.45)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(match.isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            }
            .onTapGesture(perform: onToggle)

            selectionBadge
                .padding(4)

            VStack {
                Spacer()
                HStack {
                    uploadBadge
                    Spacer()
                    Button(action: onPreview) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                }
            }
            .frame(width: 100, height: 100)
            .padding(4)
        }
        .frame(width: 100, height: 100)
        .task { await loadThumbnail() }
    }

    private var selectionBadge: some View {
        Image(systemName: match.isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(match.isSelected ? Color.accentColor : .white, .white)
            .background(Circle().fill(.black.opacity(0.25)))
    }

    @ViewBuilder
    private var uploadBadge: some View {
        switch match.uploadStatus {
        case .pending:
            EmptyView()
        case .uploading:
            ProgressView().tint(.white).scaleEffect(0.7)
        case .uploaded:
            Image(systemName: "checkmark.icloud.fill").foregroundStyle(.green)
        case .alreadyShared:
            Image(systemName: "clock.badge.checkmark.fill").foregroundStyle(.white, .blue)
        case .failed:
            Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(.red)
        }
    }

    private func loadThumbnail() async {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        let size = CGSize(width: 200, height: 200)

        await withCheckedContinuation { continuation in
            var resumed = false
            manager.requestImage(
                for: match.photo.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image { thumbnail = image }
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
        }
    }
}

/// Aperçu plein écran d'une photo avec bouton de validation pour le partage.
private struct PhotoPreviewView: View {
    let match: MatchedPhoto
    let isSelected: Bool
    let onToggle: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onToggle()
                    } label: {
                        Label(
                            isSelected ? "Sélectionnée" : "Sélectionner",
                            systemImage: isSelected ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            }
        }
        .task { await loadFullImage() }
    }

    private func loadFullImage() async {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        await withCheckedContinuation { continuation in
            var resumed = false
            manager.requestImage(
                for: match.photo.asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { result, info in
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    if let result { image = result }   // aperçu basse résolution en attendant
                    return
                }
                if let result { image = result }
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
        }
    }
}
