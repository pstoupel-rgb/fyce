import Foundation
import SwiftUI
import UIKit
import AuthenticationServices
import os

/// Authentification au premier lancement : Apple, Google, Facebook, ou compte
/// email — via Supabase Auth (GoTrue). Un mode « invité » (local) reste possible
/// pour utiliser l'app sans compte.
///
/// Les fournisseurs OAuth (Google/Facebook) et l'email nécessitent un backend
/// Supabase configuré + les providers activés côté projet (voir docs/auth-setup.md).
/// « Sign in with Apple » fonctionne nativement ; l'échange avec Supabase est
/// best-effort quand le backend est configuré.
@MainActor
final class AuthService: NSObject, ObservableObject {

    enum Status: Equatable {
        case signedOut          // doit se connecter (ou continuer en invité)
        case guest              // utilise l'app sans compte
        case signedIn(String)   // libellé (email / nom)
    }

    enum AuthError: LocalizedError {
        case needsBackend, cancelled, failed(String)
        var errorDescription: String? {
            switch self {
            case .needsBackend: return "Connexion en ligne indisponible : configure Supabase (voir docs). Tu peux continuer sans compte."
            case .cancelled: return "Connexion annulée."
            case .failed(let m): return m
            }
        }
    }

    @Published private(set) var status: Status = .signedOut

    private let defaults = UserDefaults.standard
    private let config = SupabaseConfiguration.current
    private let session: URLSession = .shared
    private var webSession: ASWebAuthenticationSession?

    private let kStatus = "auth_status_v1"     // "guest" | "signed:<label>"
    private let kToken = "auth_access_token"

    override init() {
        super.init()
        restore()
    }

    var backendEnabled: Bool { config.isConfigured }

    /// L'écran de login doit-il être présenté ?
    var needsLogin: Bool { status == .signedOut }

    // MARK: - Persistance

    private func restore() {
        switch defaults.string(forKey: kStatus) {
        case "guest": status = .guest
        case let s? where s.hasPrefix("signed:"): status = .signedIn(String(s.dropFirst(7)))
        default: status = .signedOut
        }
    }

    private func persist() {
        switch status {
        case .guest: defaults.set("guest", forKey: kStatus)
        case .signedIn(let label): defaults.set("signed:\(label)", forKey: kStatus)
        case .signedOut: defaults.removeObject(forKey: kStatus)
        }
    }

    // MARK: - Actions

    func continueAsGuest() {
        status = .guest
        persist()
    }

    func signOut() {
        defaults.removeObject(forKey: kToken)
        status = .signedOut
        persist()
    }

    private func complete(label: String, token: String?) {
        if let token { defaults.set(token, forKey: kToken) }
        status = .signedIn(label)
        persist()
        Haptics.success()
    }

    // MARK: - Apple (natif)

    func signInWithApple() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - OAuth (Google / Facebook via Supabase)

    func signIn(withProvider provider: String) async throws {
        guard backendEnabled else { throw AuthError.needsBackend }
        var components = URLComponents(
            url: config.url.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: "poze://auth-callback")
        ]
        guard let url = components.url else { throw AuthError.failed("URL invalide") }
        let callback = try await authenticate(url: url, scheme: "poze")
        try parseFragmentTokens(from: callback, fallbackLabel: provider.capitalized)
    }

    private func authenticate(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let webSession = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.failed(error.localizedDescription))
                    }
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthError.failed("Réponse vide"))
                }
            }
            webSession.presentationContextProvider = self
            webSession.prefersEphemeralWebBrowserSession = false
            self.webSession = webSession
            webSession.start()
        }
    }

    /// Supabase renvoie les jetons dans le fragment de l'URL de redirection.
    private func parseFragmentTokens(from url: URL, fallbackLabel: String) throws {
        let fragment = url.fragment ?? ""
        let pairs = fragment.split(separator: "&").reduce(into: [String: String]()) { dict, part in
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { dict[String(kv[0])] = String(kv[1]).removingPercentEncoding }
        }
        guard let token = pairs["access_token"] else { throw AuthError.failed("Jeton absent") }
        complete(label: fallbackLabel, token: token)
    }

    // MARK: - Email

    func signUpEmail(_ email: String, password: String) async throws {
        try await emailAuth(path: "auth/v1/signup", email: email, password: password)
    }

    func signInEmail(_ email: String, password: String) async throws {
        try await emailAuth(path: "auth/v1/token?grant_type=password", email: email, password: password)
    }

    private func emailAuth(path: String, email: String, password: String) async throws {
        guard backendEnabled else { throw AuthError.needsBackend }
        let url = URL(string: config.url.absoluteString + "/" + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.failed("Échec (\((response as? HTTPURLResponse)?.statusCode ?? 0)) : \(body)")
        }
        struct Session: Decodable { let access_token: String? }
        let token = (try? JSONDecoder().decode(Session.self, from: data))?.access_token
        complete(label: email, token: token)
    }
}

// MARK: - Apple delegate + fenêtre de présentation

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding,
                       ASWebAuthenticationPresentationContextProviding {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let label = credential.email
            ?? [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        // Échange best-effort avec Supabase si configuré ; sinon connexion locale.
        if backendEnabled, let identityToken {
            Task { await exchangeApple(idToken: identityToken, label: label.nilIfEmpty ?? "Compte Apple") }
        } else {
            complete(label: label.nilIfEmpty ?? "Compte Apple", token: nil)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Logger.app.debug("Apple sign-in : \(error.localizedDescription, privacy: .public)")
    }

    private func exchangeApple(idToken: String, label: String) async {
        let url = URL(string: config.url.absoluteString + "/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["provider": "apple", "id_token": idToken])
        if let (data, response) = try? await session.data(for: request),
           let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            struct S: Decodable { let access_token: String? }
            let token = (try? JSONDecoder().decode(S.self, from: data))?.access_token
            complete(label: label, token: token)
        } else {
            complete(label: label, token: nil)   // fallback local
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor() }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor() }

    private func anchor() -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
