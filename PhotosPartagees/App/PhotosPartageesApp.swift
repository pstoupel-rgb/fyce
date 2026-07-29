import SwiftUI
import UIKit

@main
struct PhotosPartageesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @AppStorage("has_onboarded_v1") private var hasOnboarded = false
    @StateObject private var auth = AuthService()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .task {
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
                        }
                } else if !hasOnboarded {
                    OnboardingView { hasOnboarded = true }.transition(.opacity)
                } else if auth.needsLogin {
                    LoginView(auth: auth).transition(.opacity)
                } else {
                    ContentView().environmentObject(auth)
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut, value: showSplash)
            .animation(.easeInOut, value: hasOnboarded)
            .animation(.easeInOut, value: auth.needsLogin)
        }
    }
}

/// AppDelegate minimal pour les notifications push (APNs).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { await PushNotificationManager.shared.requestAuthorization() }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // En simulateur, APNs échoue (normal) : la notif locale de démo reste testable.
    }
}
