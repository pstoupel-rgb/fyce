import SwiftUI
import PhotosUI

/// Sélection de la photo de référence (le visage à matcher) via PhotosPicker.
struct ReferenceFaceView: View {
    @ObservedObject var viewModel: ScanViewModel
    @State private var selection: PhotosPickerItem?
    @State private var previewImage: UIImage?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 96, height: 96)
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.hasReferenceFace {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .background(Circle().fill(.white))
                }
            }

            PhotosPicker(
                selection: $selection,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    viewModel.hasReferenceFace ? "Changer mon visage de référence" : "Choisir mon visage de référence",
                    systemImage: "face.smiling"
                )
            }
            .buttonStyle(.bordered)
        }
        .onChange(of: selection) { newValue in
            Task { await loadSelection(newValue) }
        }
    }

    private func loadSelection(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        previewImage = image
        viewModel.setReferenceFace(image)
    }
}
