import SwiftUI
import PhotosUI
import Vision

/// Ajoute un ami : on choisit une photo où son visage est net, l'app en extrait
/// l'empreinte (on-device), puis on lui donne un nom.
struct AddFriendView: View {
    @ObservedObject var store: FriendStore
    @Environment(\.dismiss) private var dismiss

    private let faceDetection: FaceDetecting = FaceDetectionService()

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var referencePrint: VNFeaturePrintObservation?
    @State private var name = ""
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle, analyzing, noFace, ready, saved
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                photoWell
                if status == .noFace {
                    Label("Aucun visage net détecté. Essaie une autre photo.",
                          systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                TextField("Prénom de l'ami", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(referencePrint == nil)
                Spacer()
                saveButton
            }
            .padding()
            .navigationTitle("Nouvel ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { newValue in
                Task { await load(newValue) }
            }
        }
    }

    private var photoWell: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.square.badge.camera")
                            .font(.system(size: 44)).foregroundStyle(.secondary)
                        Text("Choisir une photo du visage").foregroundStyle(.secondary)
                    }
                }
                if status == .analyzing {
                    Color.black.opacity(0.3)
                    ProgressView().tint(.white)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("Ajouter l'ami")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canSave
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 0.49, green: 0.36, blue: 1),
                                         Color(red: 0.13, green: 0.83, blue: 0.93)],
                                startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.gray.opacity(0.3)),
                            in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .disabled(!canSave)
    }

    private var canSave: Bool {
        referencePrint != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        status = .analyzing
        referencePrint = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            status = .noFace
            return
        }
        image = uiImage
        do {
            let print = try faceDetection.referenceFeaturePrint(from: uiImage)
            referencePrint = print
            status = .ready
        } catch {
            status = .noFace
        }
    }

    private func save() {
        guard let referencePrint else { return }
        let thumb = image.map { cropSquare($0) }
        let friend = Friend(name: name.trimmingCharacters(in: .whitespaces),
                            referencePrint: referencePrint,
                            thumbnail: thumb)
        store.add(friend)
        Haptics.success()
        dismiss()
    }

    /// Recadre au carré (centre) pour une miniature ronde propre.
    private func cropSquare(_ image: UIImage) -> UIImage {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (image.size.width - side) / 2,
                             y: (image.size.height - side) / 2)
        let rect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        guard let cg = image.cgImage?.cropping(to: CGRect(
            x: rect.origin.x * image.scale, y: rect.origin.y * image.scale,
            width: side * image.scale, height: side * image.scale)) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}
