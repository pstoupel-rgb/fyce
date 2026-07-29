import SwiftUI

/// Le fil d'activité — « nouvelles photos de toi ». C'est le côté réception de la
/// notif magique : quand un ami garde des photos où tu apparais, ça remonte ici
/// (et, backend + APNs branchés, ça t'envoie un push).
struct ActivityFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var items: [EventBackendService.RemoteNotification] = []
    @State private var pushOn = false

    enum Phase: Equatable { case loading, ready, unavailable(String) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                content
            }
            .navigationTitle("Activité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().tint(Theme.txt)
        case .unavailable(let msg):
            emptyState(msg)
        case .ready:
            if items.isEmpty { emptyState(nil) } else { list }
        }
    }

    private var list: some View {
        List {
            ForEach(items) { note in
                HStack(spacing: 12) {
                    Image(systemName: icon(for: note.kind))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Theme.surface, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.body ?? "Nouvelle activité").font(.subheadline).foregroundStyle(Theme.txt)
                        if let d = note.created_at {
                            Text(d).font(.caption2).foregroundStyle(Theme.muted2)
                        }
                    }
                    Spacer()
                    if note.seen_at == nil { Circle().fill(Theme.accent).frame(width: 8, height: 8) }
                }
                .listRowBackground(Theme.surface.opacity(0.4))
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func emptyState(_ overrideMessage: String?) -> some View {
        VStack(spacing: 14) {
            ApertureMark(color: Theme.txt).frame(width: 72, height: 72)
            Text("Nouvelles photos de toi").font(.headline).foregroundStyle(Theme.txt)
            Text(overrideMessage ?? "Quand un ami gardera des photos où tu apparais, tu le verras ici — et tu recevras une notification.")
                .font(.subheadline).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 34)

            Button {
                Task { await PushNotificationManager.shared.requestAuthorization(); pushOn = true }
            } label: {
                Label(pushOn ? "Notifications activées" : "Activer les notifications", systemImage: "bell.badge")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Theme.txt, in: Capsule())
            }
            .disabled(pushOn)

            Button("Voir la démo") {
                PushNotificationManager.shared.scheduleMagicNotificationDemo()
            }
            .font(.footnote).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "new_photos": return "photo.on.rectangle.angled"
        case "invite_joined": return "person.badge.plus"
        case "tagged": return "face.smiling"
        default: return "bell.fill"
        }
    }

    private func load() async {
        guard EventBackendService.shared.isEnabled else {
            phase = .unavailable("Le fil d'activité se remplira une fois le backend branché. En attendant, tu peux tester la notif.")
            return
        }
        do {
            items = try await EventBackendService.shared.listNotifications()
            phase = .ready
        } catch {
            phase = .unavailable("Impossible de charger l'activité pour l'instant.")
        }
    }
}
