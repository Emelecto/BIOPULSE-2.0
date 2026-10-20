import CryptoKit
import Combine
import Foundation
import Supabase

private enum AuthSessionError: LocalizedError {
    case notConfigured
    case notSignedIn
    case deletionFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: "La conexión de BioPulse con Supabase no está configurada."
        case .notSignedIn: "Vuelve a iniciar sesión antes de eliminar la cuenta."
        case .deletionFailed: "No pudimos confirmar la eliminación. Vuelve a abrir BioPulse y comprueba tu cuenta antes de intentarlo otra vez."
        }
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
    @Published private(set) var accountNotice: String?

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
        accountNotice = nil
        let response = try await configuredClient().auth.signUp(
            email: email,
            password: password,
            redirectTo: Self.emailConfirmationURL
        )
        return response.session == nil
    }

    func signIn(email: String, password: String) async throws {
        accountNotice = nil
        _ = try await configuredClient().auth.signIn(email: email, password: password)
    }

    func resendConfirmation(to email: String) async throws {
        try await configuredClient().auth.resend(
            email: email,
            type: .signup,
            emailRedirectTo: Self.emailConfirmationURL
        )
    }

    func signInWithGoogle() async throws {
        accountNotice = nil
        _ = try await configuredClient().auth.signInWithOAuth(
            provider: .google,
            redirectTo: Self.callbackURL
        )
    }

    func signInWithApple(identityToken: String, nonce: String) async throws {
        accountNotice = nil
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

    /// The server derives the account ID from this session's JWT. No client-supplied
    /// account ID or privileged key is included in the request.
    func deleteAccount() async throws {
        guard let token = session?.accessToken else { throw AuthSessionError.notSignedIn }
        guard
            let base = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: "\(base)/functions/v1/account-delete"),
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        else { throw AuthSessionError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(publicKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"confirmation":"ELIMINAR"}"#.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            (response as? HTTPURLResponse)?.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Bool],
            object["deleted"] == true
        else { throw AuthSessionError.deletionFailed }
    }

    func finishDeletedAccount(localDataRemoved: Bool) async {
        do { try await configuredClient().auth.signOut(scope: .local) }
        catch { session = nil }
        isReady = true
        accountNotice = localDataRemoved ? "Tu cuenta BioPulse se eliminó." : nil
        callbackError = localDataRemoved ? nil : "Tu cuenta se eliminó del servidor, pero no pudimos borrar todos sus datos locales. Elimina la app de este iPhone para quitar esos archivos."
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
