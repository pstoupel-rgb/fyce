import SwiftUI

/// Écran de connexion (premier lancement, après l'onboarding) : Apple, Google,
/// Facebook, compte email — ou continuer sans compte (mode local).
struct LoginView: View {
    @ObservedObject var auth: AuthService
    @State private var error: String?
    @State private var showEmail = false
    @State private var busy = false

    var body: some View {
        ZStack {
            HaloBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    ApertureMark(color: Theme.txt).frame(width: 72, height: 72)
                    Wordmark(size: 40)
                    Text("Crée ton compte pour retrouver et partager\ntes photos, où que tu sois.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                VStack(spacing: 12) {
                    providerButton("Continuer avec Apple", system: "apple.logo", filled: true) {
                        auth.signInWithApple()
                    }
                    providerButton("Continuer avec Google", asset: "G") {
                        run { try await auth.signIn(withProvider: "google") }
                    }
                    providerButton("Continuer avec Facebook", system: "f.square.fill") {
                        run { try await auth.signIn(withProvider: "facebook") }
                    }
                    providerButton("Créer un compte / email", system: "envelope") {
                        showEmail = true
                    }
                }
                Button("Continuer sans compte") { auth.continueAsGuest() }
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .padding(.top, 20)
                Text("En continuant, tu acceptes que la reconnaissance des visages\nse fasse sur ton appareil.")
                    .font(.caption2).foregroundStyle(Theme.muted2)
                    .multilineTextAlignment(.center).padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            if busy { Color.black.opacity(0.3).ignoresSafeArea(); ProgressView().tint(.white) }
        }
        .sheet(isPresented: $showEmail) { EmailAuthView(auth: auth) }
        .alert("Connexion", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        Task {
            busy = true
            defer { busy = false }
            do { try await action() }
            catch let e as AuthService.AuthError {
                if case .cancelled = e { return }
                error = e.errorDescription
            }
            catch { error = error.localizedDescription }
        }
    }

    private func providerButton(_ title: String, system: String? = nil, asset: String? = nil,
                                filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let system {
                    Image(systemName: system).font(.system(size: 17, weight: .medium))
                } else if let asset {
                    Text(asset).font(.system(size: 16, weight: .bold))
                }
                Text(title).font(.system(size: 15.5, weight: .semibold))
            }
            .foregroundStyle(filled ? Color.black : Theme.txt)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(filled ? AnyShapeStyle(Theme.txt) : AnyShapeStyle(Theme.surface),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(filled ? nil : RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.line2, lineWidth: 1))
        }
    }
}

/// Création de compte / connexion par email.
private struct EmailAuthView: View {
    @ObservedObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    Picker("", selection: $isSignUp) {
                        Text("Créer un compte").tag(true)
                        Text("Se connecter").tag(false)
                    }
                    .pickerStyle(.segmented)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("Mot de passe", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Color(hex: 0xd9a066))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        submit()
                    } label: {
                        Text(isSignUp ? "Créer mon compte" : "Se connecter")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(canSubmit ? AnyShapeStyle(Theme.txt) : AnyShapeStyle(Theme.surface2),
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSubmit || busy)

                    if !auth.backendEnabled {
                        Text("La connexion par email nécessite un backend Supabase configuré.")
                            .font(.caption).foregroundStyle(Theme.muted2).multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .padding()
                if busy { ProgressView().tint(.white) }
            }
            .navigationTitle(isSignUp ? "Créer un compte" : "Connexion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } } }
        }
    }

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    private func submit() {
        Task {
            busy = true
            defer { busy = false }
            do {
                if isSignUp { try await auth.signUpEmail(email, password: password) }
                else { try await auth.signInEmail(email, password: password) }
                dismiss()
            } catch let e as AuthService.AuthError {
                error = e.errorDescription
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
