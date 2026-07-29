import SwiftUI
import AVFoundation

/// Côté invité : scanne le QR d'un event pour le rejoindre (utile quand tu n'es
/// pas l'organisateur). L'event apparaît alors sur ton accueil.
struct EventJoinView: View {
    @ObservedObject var store: FriendStore
    @Environment(\.dismiss) private var dismiss

    @State private var access: Access = .unknown
    @State private var errorText: String?
    @State private var joined: PozeEvent?

    enum Access { case unknown, granted, denied }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch access {
                case .granted: scanner
                case .denied:  denied
                case .unknown: ProgressView().tint(.white)
                }
            }
            .navigationTitle("Scanner un event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .onAppear(perform: requestCamera)
            .alert("QR non reconnu", isPresented: Binding(
                get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Réessayer", role: .cancel) {}
            } message: { Text(errorText ?? "") }
            .alert("Event rejoint 🎉", isPresented: Binding(
                get: { joined != nil }, set: { if !$0 { joined = nil } })) {
                Button("Super") { dismiss() }
            } message: {
                Text("« \(joined?.name ?? "") » est ajouté à ton accueil. Ajoute tes membres pour scanner tes photos.")
            }
        }
    }

    private var scanner: some View {
        ZStack {
            QRScannerView(onFound: handle).ignoresSafeArea()
            // Cadre de visée.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.4), radius: 12)
            VStack {
                Spacer()
                Text("Vise le QR code de l'event")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 50)
            }
        }
    }

    private var denied: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Accès caméra refusé").font(.headline).foregroundStyle(.white)
            Text("Autorise la caméra dans Réglages → Poze pour scanner un QR.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    private func handle(_ code: String) {
        guard let invite = EventInvite.decode(from: code) else {
            errorText = "Ce QR ne correspond pas à un event Poze."
            return
        }
        let event = invite.toEvent()
        store.addOrUpdate(event)
        // Best-effort : enregistre l'adhésion côté serveur si Supabase est configuré.
        if EventBackendService.shared.isEnabled {
            Task { try? await EventBackendService.shared.joinEvent(code: invite.code) }
        }
        joined = event
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: access = .granted
        case .denied, .restricted: access = .denied
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { access = granted ? .granted : .denied }
            }
        @unknown default: access = .denied
        }
    }
}
