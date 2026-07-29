import SwiftUI

/// Pile de cartes « façon Tinder » : glisser à droite pour garder, à gauche pour
/// passer, vers le bas pour supprimer du téléphone. Les boutons ✕ 🗑 ✓ dupliquent
/// ces gestes. C'est le seul endroit où l'on se permet du mouvement.
struct SwipeDeckView: View {
    @ObservedObject var viewModel: ReviewViewModel

    @State private var drag: CGSize = .zero
    @State private var flyingOut: SwipeDirection?

    enum SwipeDirection { case keep, skip, trash }
    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 24) {
            deck
            controls
        }
        .padding(.top, 12)
    }

    private var deck: some View {
        ZStack {
            if viewModel.queue.isEmpty {
                emptyState
            } else {
                ForEach(Array(viewModel.queue.prefix(3).enumerated()).reversed(), id: \.element.id) { pair in
                    cardView(pair.element, index: pair.offset)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 430)
    }

    private func cardView(_ card: ReviewPhoto, index: Int) -> some View {
        let isTop = index == 0
        let scale = 1 - CGFloat(index) * 0.04
        let yOffset = CGFloat(index) * 12
        return SwipeCard(card: card, dragForTop: isTop ? drag : .zero)
            .scaleEffect(isTop ? 1 : scale)
            .offset(x: isTop ? drag.width : 0, y: (isTop ? drag.height : yOffset))
            .rotationEffect(.degrees(isTop ? Double(drag.width / 20) : 0))
            .brightness(isTop ? 0 : -0.12 * Double(index))
            .gesture(dragGesture, including: isTop ? .all : .subviews)
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
                if v > threshold && abs(v) > abs(h) { fly(.trash) }
                else if h > threshold { fly(.keep) }
                else if h < -threshold { fly(.skip) }
                else { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drag = .zero } }
            }
    }

    // MARK: - Boutons

    private var controls: some View {
        HStack(spacing: 22) {
            circleButton(system: "xmark", label: "Passer", filled: false, size: 56) { fly(.skip) }
            circleButton(system: "trash", label: "Supprimer du téléphone", filled: false, size: 50, muted: true) { fly(.trash) }
            circleButton(system: "checkmark", label: "Garder", filled: true, size: 56) { fly(.keep) }
        }
        .opacity(viewModel.queue.isEmpty ? 0.3 : 1)
        .disabled(viewModel.queue.isEmpty)
    }

    private func circleButton(system: String, label: String, filled: Bool,
                              size: CGFloat, muted: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(filled ? Color.black : (muted ? Theme.muted : Theme.txt))
                .frame(width: size, height: size)
                .background(
                    Circle().fill(filled ? Theme.txt : Theme.surface)
                )
                .overlay(filled ? nil : Circle().strokeBorder(Theme.line2, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle").font(.system(size: 42)).foregroundStyle(Theme.ok)
            Text("Tout est trié").font(.headline).foregroundStyle(Theme.txt)
            if viewModel.keptThisSession > 0 {
                Text("\(viewModel.keptThisSession) photo\(viewModel.keptThisSession > 1 ? "s" : "") gardée\(viewModel.keptThisSession > 1 ? "s" : "") pour \(viewModel.subject.title)")
                    .font(.subheadline).foregroundStyle(Theme.muted)
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

/// Rendu d'une carte : la photo domine, filet fin, overlays sobres selon le glissé.
private struct SwipeCard: View {
    let card: ReviewPhoto
    let dragForTop: CGSize

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface)
            if let image = card.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView().tint(Theme.muted)
            }
            overlays
        }
        .frame(width: 300, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
    }

    private var overlays: some View {
        ZStack {
            stamp("GARDER", Theme.ok, angle: -6, align: .topLeading, opacity: max(0, dragForTop.width / 120))
            stamp("PASSER", Theme.txt, angle: 6, align: .topTrailing, opacity: max(0, -dragForTop.width / 120))
            stamp("SUPPRIMER", Color(hex: 0xd97066), angle: 0, align: .bottom, opacity: max(0, dragForTop.height / 120))
        }
        .padding(18)
    }

    private func stamp(_ text: String, _ color: Color, angle: Double, align: Alignment, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold)).tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(color, lineWidth: 2))
            .rotationEffect(.degrees(angle))
            .opacity(min(1, opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align)
    }
}
