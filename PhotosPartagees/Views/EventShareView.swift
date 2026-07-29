import SwiftUI

/// Côté organisateur : affiche le QR code de l'event + le code court, avec un
/// bouton pour partager l'image (Messages, WhatsApp, AirDrop…).
struct EventShareView: View {
    let event: PozeEvent
    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any]?

    private var qrImage: UIImage? {
        QRCode.image(from: EventInvite(event: event).encoded())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                VStack(spacing: 18) {
                    Image(systemName: event.symbol)
                        .font(.title)
                        .foregroundStyle(Theme.txt)
                        .frame(width: 54, height: 54)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                        .overlay(Circle().fill(event.colorway.primary).frame(width: 8, height: 8)
                                 .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(7))
                    Text(event.name).font(.title2.bold())
                    Text(event.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline).foregroundStyle(.secondary)

                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 230, height: 230)
                            .padding(16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: event.colorway.primary.opacity(0.3), radius: 20, y: 8)
                    }

                    Text(event.joinCode)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .tracking(4).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))

                    Text("Fais scanner ce QR à tes amis pour qu'ils rejoignent l'event.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)

                    Spacer()

                    Button {
                        var items: [Any] = ["Rejoins « \(event.name) » sur Poze — code \(event.joinCode)"]
                        if let qrImage { items.insert(qrImage, at: 0) }
                        shareItems = items
                    } label: {
                        Label("Partager l'invitation", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.txt, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.black)
                    }
                    .disabled(qrImage == nil)
                }
                .padding()
            }
            .navigationTitle("Partager l'event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
            .sheet(isPresented: Binding(
                get: { shareItems != nil },
                set: { if !$0 { shareItems = nil } })) {
                if let shareItems { ActivityView(items: shareItems) }
            }
        }
    }
}
