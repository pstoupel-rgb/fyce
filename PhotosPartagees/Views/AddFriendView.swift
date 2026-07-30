import SwiftUI
import PhotosUI

/// Ajoute un ami : on choisit une photo où son visage est net, l'app en extrait
/// l'empreinte (on-device), puis on lui donne un nom.
struct AddFriendView: View {
    @ObservedObject var store: FriendStore
    @Environment(\.dismiss) private var dismiss

    private let faceDetection: FaceDetecting = FaceDetectionService()

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var referencePrint: FaceSignature?
    @State private var name = ""
    @State private var status: Status = .idle

    // Protection des mineurs
    @State private var isMinor = false
    @State private var consent = false
    @State private var parentContact = ""

    enum Status: Equatable {
        case idle, analyzing, noFace, ready, saved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 20) {
                    photoWell
                    if status == .noFace {
                        Label("Aucun visage net détecté. Essaie une autre photo.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(Color(hex: 0xd9a066))
                    } else if status == .ready {
                        Label("Visage détecté · empreinte créée sur l'appareil", systemImage: "checkmark.circle")
                            .font(.footnote).foregroundStyle(Theme.ok)
                    }
                    TextField("Prénom de l'ami", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(referencePrint == nil)
                    minorSection
                    Spacer()
                    saveButton
                }
                .padding()
            }
            .navigationTitle("Nouvel ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                RoundedRectangle(cornerRadius: 20).fill(Theme.surface)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.square")
                            .font(.system(size: 44)).foregroundStyle(Theme.muted2)
                        Text("Choisir une photo du visage").foregroundStyle(Theme.muted)
                    }
                }
                if status == .analyzing {
                    Color.black.opacity(0.3)
                    ProgressView().tint(.white)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    /// Protection des mineurs : bascule + consentement parental obligatoire.
    private var minorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isMinor) {
                Text("Cette personne est mineure").font(.system(size: 15))
            }
            .tint(Theme.ok)

            if isMinor {
                VStack(alignment: .leading, spacing: 12) {
                    Text("La loi l'exige : sans l'accord d'un parent ou tuteur, on ne peut pas rechercher ni partager les photos d'un mineur.")
                        .font(.footnote).foregroundStyle(Theme.muted)

                    TextField("Email du parent / tuteur", text: $parentContact)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    Button {
                        consent.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: consent ? "checkmark.square.fill" : "square")
                                .foregroundStyle(consent ? Theme.ok : Theme.muted)
                            Text("J'atteste avoir l'autorisation du parent ou tuteur légal.")
                                .font(.footnote).foregroundStyle(Theme.txt)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(isMinor && !consent ? "Consentement requis" : "Ajouter l'ami")
                .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canSave ? AnyShapeStyle(Theme.txt) : AnyShapeStyle(Theme.surface2),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(canSave ? Color.black : Theme.muted2)
        }
        .disabled(!canSave)
    }

    private var canSave: Bool {
        guard referencePrint != nil, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isMinor { return consent }   // un mineur exige le consentement
        return true
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
                            thumbnail: thumb,
                            isMinor: isMinor,
                            parentalConsent: isMinor ? consent : false,
                            parentContact: isMinor ? parentContact.trimmingCharacters(in: .whitespaces).nilIfEmpty : nil)
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
