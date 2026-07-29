import SwiftUI
import PhotosUI

/// Sélection de la photo de référence (le visage à matcher) via PhotosPicker.
struct ReferenceFaceView: View {
    @ObservedObject var viewModel: ScanViewModel
    @State private var selection: PhotosPickerItem?
    @State private var previewImage: UIImage?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.surface).frame(width: 104, height: 104)
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable().scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 42)).foregroundStyle(Theme.muted2)
                }
            }
            .overlay(Circle().strokeBorder(Theme.line2, lineWidth: 1))
            .overlay(alignment: .bottomTrailing) {
                if viewModel.hasReferenceFace {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.bg, Theme.ok)
                }
            }

            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Text(viewModel.hasReferenceFace ? "Changer mon visage" : "Choisir mon visage")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.txt)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(Theme.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.line2, lineWidth: 1))
            }

            Text("Reconnaissance 100 % sur ton téléphone")
                .font(.caption).foregroundStyle(Theme.muted2)
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
