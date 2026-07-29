import Foundation
import SwiftUI
import LocalAuthentication

/// Verrou biométrique optionnel : « tes photos de proches derrière Face ID ».
/// Utilise `deviceOwnerAuthentication` (Face ID / Touch ID, avec repli sur le code).
@MainActor
final class AppLockService: ObservableObject {

    @Published private(set) var isLocked: Bool
    private let key = "app_lock_enabled"

    init() {
        isLocked = UserDefaults.standard.bool(forKey: key)
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            // Activer le verrou ne doit pas verrouiller la session en cours ; il
            // s'appliquera au prochain passage en arrière-plan. Le désactiver lève
            // immédiatement un éventuel verrou.
            if !newValue { isLocked = false }
            objectWillChange.send()
        }
    }

    /// Le matériel permet-il l'authentification (Face ID / Touch ID / code) ?
    var biometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Re-verrouille quand l'app passe en arrière-plan (si activé).
    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    /// Tente le déverrouillage biométrique.
    func unlock() async {
        let context = LAContext()
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Déverrouiller Poze")
            isLocked = !ok
        } catch {
            // L'utilisateur a annulé : on reste verrouillé.
        }
    }
}

/// Écran de verrouillage — reprend le halo + diaphragme.
struct LockView: View {
    @ObservedObject var lock: AppLockService

    var body: some View {
        ZStack {
            HaloBackground()
            VStack(spacing: 22) {
                ApertureMark(color: Theme.txt).frame(width: 96, height: 96)
                Text("Poze est verrouillé").font(.headline).foregroundStyle(Theme.txt)
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Déverrouiller", systemImage: "faceid")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 22).padding(.vertical, 13)
                        .background(Theme.txt, in: Capsule())
                }
            }
        }
        .task { await lock.unlock() }
    }
}
