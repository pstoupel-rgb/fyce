import SwiftUI
import PhotosUI
import Vision

/// « Tape un visage → dis qui c'est. » On détecte les visages d'une photo ; tu en
/// touches un pour l'assigner à un ami (ce qui **ajoute une référence** — l'app
/// apprend) ou pour créer un nouvel ami. Résout les ratés et améliore la précision.
struct TagFacesView: View {
    @ObservedObject var store: FriendStore
    @Environment(\.dismiss) private var dismiss
    private let faceDetection = FaceDetectionService()

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var faces: [DetectedFace] = []
    @State private var status: Status = .idle
    @State private var assignFace: DetectedFace?

    enum Status: Equatable { case idle, analyzing, ready, noFace }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    if let image {
                        imageWithBoxes(image)
                        Text(status == .noFace ? "Aucun visage détecté." : "Touche un visage pour l'identifier.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                        picker(label: "Changer de photo")
                    } else {
                        Spacer()
                        picker(label: "Choisir une photo")
                        Text("On détecte les visages ; tu tapes celui à identifier.")
                            .font(.footnote).foregroundStyle(Theme.muted2)
                        Spacer()
                    }
                }
                .padding()
                if status == .analyzing {
                    Color.black.opacity(0.3).ignoresSafeArea(); ProgressView().tint(.white)
                }
            }
            .navigationTitle("Identifier un visage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .onChange(of: pickerItem) { newValue in Task { await load(newValue) } }
            .sheet(item: $assignFace) { face in
                AssignFaceSheet(store: store, face: face, suggestion: suggestion(for: face))
            }
        }
    }

    private func picker(label: String) -> some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            Label(label, systemImage: "photo.on.rectangle")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.line2, lineWidth: 1))
        }
    }

    private func imageWithBoxes(_ img: UIImage) -> some View {
        GeometryReader { geo in
            let fit = fittedRect(imageSize: img.size, in: geo.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: img).resizable().scaledToFit()
                ForEach(faces) { face in
                    let r = pixelRect(face.boundingBox, in: fit)
                    let known = suggestion(for: face) != nil
                    Button { assignFace = face } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(known ? Theme.ok : Theme.txt, lineWidth: 2.5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.001)))
                    }
                    .frame(width: r.width, height: r.height)
                    .position(x: r.midX, y: r.midY)
                }
            }
        }
        .frame(maxHeight: 460)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Géométrie (image en scaledToFit)

    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale, h = imageSize.height * scale
        return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
    }

    private func pixelRect(_ box: CGRect, in fit: CGRect) -> CGRect {
        CGRect(x: fit.minX + box.minX * fit.width,
               y: fit.minY + box.minY * fit.height,
               width: box.width * fit.width,
               height: box.height * fit.height)
    }

    // MARK: - Suggestion (meilleure correspondance parmi les amis)

    private func suggestion(for face: DetectedFace) -> Friend? {
        var best: (friend: Friend, distance: Float)?
        for friend in store.friends {
            for ref in friend.referencePrints {
                let d = ref.distance(to: face.signature)
                if best == nil || d < best!.distance { best = (friend, d) }
            }
        }
        if let best, best.distance <= 0.6 { return best.friend }
        return nil
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        status = .analyzing
        faces = []
        guard let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else { status = .noFace; return }
        image = ui
        let detected = (try? faceDetection.detectedFaces(in: ui)) ?? []
        faces = detected
        status = detected.isEmpty ? .noFace : .ready
    }
}

/// Feuille d'assignation d'un visage à un ami (existant ou nouveau).
private struct AssignFaceSheet: View {
    @ObservedObject var store: FriendStore
    let face: DetectedFace
    let suggestion: Friend?
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Spacer()
                            if let crop = face.crop {
                                Image(uiImage: crop).resizable().scaledToFill()
                                    .frame(width: 96, height: 96).clipShape(Circle())
                                    .overlay(Circle().strokeBorder(Theme.line2, lineWidth: 1))
                            }
                            Spacer()
                        }
                    }

                    if let suggestion {
                        Section("Suggestion") {
                            Button { assign(to: suggestion) } label: {
                                Label("C'est \(suggestion.name)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.ok)
                            }
                        }
                    }

                    if !store.friends.isEmpty {
                        Section("Assigner à un ami") {
                            ForEach(store.friends) { friend in
                                Button { assign(to: friend) } label: {
                                    HStack {
                                        Text(friend.name).foregroundStyle(Theme.txt)
                                        Spacer()
                                        Text("\(friend.referencePrints.count) réf.")
                                            .font(.caption).foregroundStyle(Theme.muted2)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        TextField("Prénom", text: $newName)
                        Button("Créer cet ami") { createNew() }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    } header: {
                        Text("Nouvel ami")
                    } footer: {
                        Text("Pour un mineur, ajoute-le depuis « Ajouter un ami » (consentement parental requis).")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Qui est-ce ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } } }
        }
    }

    private func assign(to friend: Friend) {
        store.addReference(face.signature, to: friend)
        Haptics.success()
        dismiss()
    }

    private func createNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.add(Friend(name: name, referencePrint: face.signature, thumbnail: face.crop))
        Haptics.success()
        dismiss()
    }
}
