import SwiftUI
import Photos

/// Grille des photos matchées avec indicateur d'état d'upload.
struct PhotoGridView: View {
    let matches: [MatchedPhoto]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos matchées (\(matches.count))")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(matches) { match in
                    MatchedThumbnail(match: match)
                }
            }
        }
    }
}

/// Vignette unitaire chargée de façon asynchrone depuis PhotoKit.
private struct MatchedThumbnail: View {
    let match: MatchedPhoto
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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

            uploadBadge
                .padding(4)
        }
        .task { await loadThumbnail() }
    }

    @ViewBuilder
    private var uploadBadge: some View {
        switch match.uploadStatus {
        case .pending:
            Image(systemName: "circle.dashed").foregroundStyle(.white)
        case .uploading:
            ProgressView().tint(.white)
        case .uploaded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
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
