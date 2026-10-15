import CryptoKit
import Combine
import Foundation
import Supabase

private enum AuthSessionError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        "La conexión de BioPulse con Supabase no está configurada."
    }
}

struct AppleSignInNonce {
    let rawValue: String
    let hashedValue: String

    static func make() -> AppleSignInNonce {
        let rawValue = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let digest = SHA256.hash(data: Data(rawValue.utf8))
        let hashedValue = digest.map { String(format: "%02x", $0) }.joined()
        return AppleSignInNonce(rawValue: rawValue, hashedValue: hashedValue)
    }
}

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isReady = false
    @Published private(set) var isRecoveringPassword = false
    @Published private(set) var configurationProblem: String?
    @Published var callbackError: String?

    private let client: SupabaseClient?

    init() {
        guard
            let urlValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlValue),
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !key.isEmpty,
            url.host != nil,
            url.scheme == "https" || url.scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host ?? "")
        else {
            client = nil
            configurationProblem = "Falta configurar SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY en el proyecto iOS."
            isReady = true
            return
        }

        let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        self.client = client

        Task { [weak self, client] in
            for await (event, session) in await client.auth.authStateChanges {
                guard let self else { return }
                self.session = session
                self.isRecoveringPassword = event == .passwordRecovery
                if event == .signedOut {
                    self.isRecoveringPassword = false
                }
                self.isReady = true
            }
        }
    }

    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await configuredClient().auth.signUp(
            email: email,
            password: password,
            redirectTo: Self.emailConfirmationURL
        )
        return response.session == nil
    }

    func signIn(email: String, password: String) async throws {
        _ = try await configuredClient().auth.signIn(email: email, password: password)
    }

    func signInWithGoogle() async throws {
        _ = try await configuredClient().auth.signInWithOAuth(
            provider: .google,
            redirectTo: Self.callbackURL
        )
    }

    func signInWithApple(identityToken: String, nonce: String) async throws {
        _ = try await configuredClient().auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )
    }

    func sendPasswordReset(to email: String) async throws {
        try await configuredClient().auth.resetPasswordForEmail(email, redirectTo: Self.callbackURL)
    }

    func updatePassword(_ password: String) async throws {
        _ = try await configuredClient().auth.update(user: UserAttributes(password: password))
        isRecoveringPassword = false
    }

    func signOut() async throws {
        try await configuredClient().auth.signOut()
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == "biopulse", url.host == "auth-callback" else { return }
        do {
            try await configuredClient().auth.handle(url)
            callbackError = nil
        } catch {
            callbackError = "No se pudo completar el enlace de acceso. Solicita uno nuevo e inténtalo otra vez."
        }
    }

    private func configuredClient() throws -> SupabaseClient {
        guard let client else { throw AuthSessionError.notConfigured }
        return client
    }

    private static var callbackURL: URL? {
        URL(string: "biopulse://auth-callback")
    }

    private static var emailConfirmationURL: URL? {
        URL(string: "https://ielprdmmuocajtbimvdx.supabase.co/functions/v1/confirm-email")
    }
}
