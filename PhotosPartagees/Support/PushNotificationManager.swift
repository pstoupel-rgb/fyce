import Foundation
import UserNotifications
import UIKit

/// Gère les notifications : demande d'autorisation, enregistrement APNs (token),
/// affichage au premier plan, et une notif locale « magique » de démo.
@MainActor
final class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published private(set) var authorized = false
    @Published private(set) var deviceToken: String?

    /// Demande la permission d'envoyer des notifications, puis s'enregistre à APNs.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorized = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            authorized = false
        }
    }

    /// Appelé par l'AppDelegate quand APNs renvoie le token de l'appareil.
    func didRegister(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        Task { try? await PushRegistrationService().register(token: token) }
    }

    /// Démo testable **au simulateur** (sans compte Apple) : planifie la « notif magique ».
    func scheduleMagicNotificationDemo(count: Int = 3, eventName: String = "Le Duplex") {
        let content = UNMutableNotificationContent()
        content.title = "Poze"
        content.body = "📸 \(count) new photos of you at \(eventName)"
        content.sound = .default
        content.badge = NSNumber(value: count)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Affiche la notif même quand l'app est au premier plan.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
