import SwiftUI

/// Pile de cartes « façon Tinder » : glisser à droite pour garder, à gauche pour
/// passer, vers le bas pour supprimer du téléphone. Les boutons ✓ ✗ 🗑️ dupliquent
/// ces gestes pour l'accessibilité.
struct SwipeDeckView: View {
    @ObservedObject var viewModel: ReviewViewModel

    /// Décalage de la carte du dessus pendant le glissé.
    @State private var drag: CGSize = .zero
    /// Direction verrouillée d'une animation de sortie en cours.
    @State private var flyingOut: SwipeDirection?

    enum SwipeDirection { case keep, skip, trash }

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 22) {
            deck
            controls
        }
    }

    // MARK: - Pile

    private var deck: some View {
        ZStack {
            if viewModel.queue.isEmpty {
                emptyState
            } else {
                // On dessine jusqu'à 3 cartes, la première étant celle du dessus.
                // Ordre inversé pour que la carte du dessus (index 0) soit dessinée en dernier.
                ForEach(Array(viewModel.queue.prefix(3).enumerated()).reversed(), id: \.element.id) { pair in
                    cardView(pair.element, index: pair.offset)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 440)
    }

    private func cardView(_ card: ReviewPhoto, index: Int) -> some View {
        let isTop = index == 0
        let scale = 1 - CGFloat(index) * 0.04
        let yOffset = CGFloat(index) * 14
        return SwipeCard(card: card, dragForTop: isTop ? drag : .zero)
            .scaleEffect(isTop ? 1 : scale)
            .offset(x: isTop ? drag.width : 0,
                    y: (isTop ? drag.height : yOffset))
            .rotationEffect(.degrees(isTop ? Double(drag.width / 18) : 0))
            .gesture(isTop ? dragGesture : nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: drag)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.queue.count)
            .allowsHitTesting(isTop)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                if v > threshold && abs(v) > abs(h) {
                    fly(.trash)
                } else if h > threshold {
                    fly(.keep)
                } else if h < -threshold {
                    fly(.skip)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drag = .zero }
                }
            }
    }

    // MARK: - Boutons

    private var controls: some View {
        HStack(spacing: 26) {
            circleButton(system: "xmark", tint: .pink, label: "Passer") { fly(.skip) }
            circleButton(system: "trash", tint: .red, label: "Supprimer du téléphone",
                         size: 56) { fly(.trash) }
            circleButton(system: "checkmark", tint: .green, label: "Garder") { fly(.keep) }
        }
        .opacity(viewModel.queue.isEmpty ? 0.35 : 1)
        .disabled(viewModel.queue.isEmpty)
    }

    private func circleButton(system: String, tint: Color, label: String,
                              size: CGFloat = 64,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(tint.opacity(0.35), lineWidth: 1))
                .shadow(color: tint.opacity(0.25), radius: 10, y: 4)
        }
        .accessibilityLabel(label)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Tout est trié 🎉")
                .font(.headline)
            if viewModel.keptThisSession > 0 {
                Text("\(viewModel.keptThisSession) photo\(viewModel.keptThisSession > 1 ? "s" : "") gardée\(viewModel.keptThisSession > 1 ? "s" : "") pour \(viewModel.subject.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Animation de sortie

    private func fly(_ direction: SwipeDirection) {
        guard flyingOut == nil, !viewModel.queue.isEmpty else { return }
        flyingOut = direction
        let off: CGSize
        switch direction {
        case .keep:  off = CGSize(width: 700, height: 0)
        case .skip:  off = CGSize(width: -700, height: 0)
        case .trash: off = CGSize(width: 0, height: 900)
        }
        Haptics.tap(direction == .trash ? .heavy : .light)
        withAnimation(.easeIn(duration: 0.28)) { drag = off }

        // Applique l'action après la sortie visuelle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            switch direction {
            case .keep:  viewModel.keepTop()
            case .skip:  viewModel.skipTop()
            case .trash: Task { await viewModel.trashTop() }
            }
            drag = .zero
            flyingOut = nil
        }
    }
}

/// Rendu d'une carte : photo + overlays « GARDER / PASSER / SUPPRIMER » selon le glissé.
private struct SwipeCard: View {
    let card: ReviewPhoto
    let dragForTop: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
            if let image = card.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
            overlays
        }
        .frame(width: 320, height: 430)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
    }

    private var overlays: some View {
        ZStack {
            badge("GARDER", .green, angle: -14, align: .topLeading,
                  opacity: max(0, dragForTop.width / 120))
            badge("PASSER", .pink, angle: 14, align: .topTrailing,
                  opacity: max(0, -dragForTop.width / 120))
            badge("SUPPRIMER", .red, angle: 0, align: .bottom,
                  opacity: max(0, dragForTop.height / 120))
        }
        .padding(18)
    }

    private func badge(_ text: String, _ color: Color, angle: Double,
                       align: Alignment, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
            .opacity(min(1, opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
    }
}
