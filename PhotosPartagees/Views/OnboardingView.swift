import SwiftUI

/// Premier lancement : présentation sobre en quelques pages. Insiste sur ce qui
/// fait la confiance — tout reste sur le téléphone — avant de demander l'accès.
struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    private let pages: [Page] = [
        Page(symbol: "camera.aperture",
             title: "Bienvenue sur Poze",
             body: "Retrouve tes photos, et celles de tes proches, sans fouiller ta pellicule à la main."),
        Page(symbol: "lock.shield",
             title: "Rien ne quitte ton téléphone",
             body: "La reconnaissance des visages se fait entièrement sur ton appareil. Aucune photo, aucun visage n'est envoyé sans ton accord."),
        Page(symbol: "rectangle.stack",
             title: "Trie d'un swipe",
             body: "Garde, passe ou supprime d'un geste. Partage ce que tu veux, avec qui tu veux — un ami, un groupe, un event."),
        Page(symbol: "hand.raised.fill",
             title: "On protège les mineurs",
             body: "Ajouter un mineur exige le consentement d'un parent ou tuteur. C'est une règle, pas une option.")
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots
                controls
            }
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: p.symbol)
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(Theme.txt)
                .frame(width: 120, height: 120)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line2, lineWidth: 1))
            VStack(spacing: 12) {
                Text(p.title)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.txt)
                    .multilineTextAlignment(.center)
                Text(p.body)
                    .font(.system(size: 15.5))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 34)
            }
            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.txt : Theme.line2)
                    .frame(width: i == page ? 20 : 7, height: 7)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
        .padding(.bottom, 24)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    Haptics.success()
                    onDone()
                }
            } label: {
                Text(page < pages.count - 1 ? "Continuer" : "Commencer")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Theme.txt, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            Button("Passer") { onDone() }
                .font(.subheadline).foregroundStyle(Theme.muted)
                .opacity(page < pages.count - 1 ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private struct Page {
        let symbol: String
        let title: String
        let body: String
    }
}
