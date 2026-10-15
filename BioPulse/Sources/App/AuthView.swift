import AuthenticationServices
import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn = "Iniciar sesión"
    case signUp = "Crear cuenta"

    var id: String { rawValue }
}

struct AuthGateView: View {
    @ObservedObject var auth: AuthSessionStore

    var body: some View {
        Group {
            if !auth.isReady {
                ProgressView("Comprobando tu sesión…")
                    .tint(PulseStyle.mint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PulseStyle.background.ignoresSafeArea())
            } else if auth.isRecoveringPassword, auth.session != nil {
                PasswordRecoveryView(auth: auth)
            } else if let userID = auth.session?.user.id {
                RootView(userID: userID, auth: auth)
                    .id(userID)
            } else {
                AuthView(auth: auth)
            }
        }
        .preferredColorScheme(.dark)
        .tint(PulseStyle.mint)
        .onOpenURL { url in
            Task { await auth.handleAuthCallback(url) }
        }
    }
}

private struct AuthView: View {
    @ObservedObject var auth: AuthSessionStore
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var appleNonce: String?
    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ZStack {
            Image("ForestNight")
                .resizable()
                .scaledToFill()
                .overlay(PulseStyle.background.opacity(0.72))
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    header

                    if let configurationProblem = auth.configurationProblem {
                        StatusPanel(
                            symbol: "exclamationmark.triangle",
                            title: "Falta configurar la conexión",
                            message: configurationProblem
                        )
                    } else {
                        credentialForm
                        providerOptions
                    }

                    Text("Iniciar sesión es necesario para usar BioPulse. La sincronización de tus datos sigue siendo opcional y requiere tu consentimiento.")
                        .font(.footnote)
                        .foregroundStyle(PulseStyle.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 460, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 54)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(PulseStyle.mint)
                .accessibilityHidden(true)

            Text("BioPulse")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white)

            Text(mode == .signIn ? "Tu bienestar, en contexto." : "Crea tu espacio personal.")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))

            Text(mode == .signIn
                 ? "Entra para consultar tu experiencia BioPulse."
                 : "Usaremos tu cuenta para proteger tu acceso y separar tus datos en este dispositivo.")
                .font(.subheadline)
                .foregroundStyle(PulseStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var credentialForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Acceso", selection: $mode) {
                ForEach(AuthMode.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Elige iniciar sesión o crear una cuenta")

            VStack(spacing: 12) {
                TextField("Correo electrónico", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Correo electrónico")

                SecureField("Contraseña", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Contraseña")

                if mode == .signUp {
                    SecureField("Repite la contraseña", text: $passwordConfirmation)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Repite la contraseña")
                }
            }

            if mode == .signIn {
                Button("Olvidé mi contraseña") {
                    Task { await requestPasswordReset() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PulseStyle.mint)
                .disabled(isWorking)
            }

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PulseStyle.mint)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if let callbackError = auth.callbackError {
                Text(callbackError)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await submitCredentials() }
            } label: {
                HStack(spacing: 10) {
                    if isWorking { ProgressView().tint(PulseStyle.background) }
                    Text(isWorking ? "Un momento…" : mode.rawValue)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PulseActionButtonStyle())
            .disabled(isWorking || auth.configurationProblem != nil)
        }
        .padding(19)
        .background(PulseStyle.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
    }

    private var providerOptions: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
                Text("o continúa con")
                    .font(.caption)
                    .foregroundStyle(PulseStyle.secondary)
                    .fixedSize()
                Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
            }

            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.make()
                appleNonce = nonce.rawValue
                request.nonce = nonce.hashedValue
                request.requestedScopes = [.email]
            } onCompletion: { result in
                Task { await completeAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .disabled(isWorking || auth.configurationProblem != nil)
            .accessibilityLabel("Continuar con Apple")

            Button {
                Task { await signInWithGoogle() }
            } label: {
                Label("Continuar con Google", systemImage: "g.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(PulsePressButtonStyle())
            .disabled(isWorking || auth.configurationProblem != nil)
        }
    }

    private func submitCredentials() async {
        clearFeedback()
        guard normalizedEmail.contains("@") else {
            errorMessage = "Escribe un correo electrónico válido."
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Escribe tu contraseña."
            return
        }
        if mode == .signUp {
            guard password.count >= 8 else {
                errorMessage = "La contraseña debe tener al menos 8 caracteres."
                return
            }
            guard password == passwordConfirmation else {
                errorMessage = "Las contraseñas no coinciden."
                return
            }
        }

        isWorking = true
        defer { isWorking = false }
        do {
            if mode == .signIn {
                try await auth.signIn(email: normalizedEmail, password: password)
            } else {
                let confirmationRequired = try await auth.signUp(email: normalizedEmail, password: password)
                if confirmationRequired {
                    message = "Si el registro fue aceptado, recibirás un correo para confirmar la cuenta antes de entrar."
                }
            }
        } catch {
            errorMessage = mode == .signIn
                ? "No se pudo iniciar sesión. Revisa tus datos e inténtalo de nuevo."
                : "No se pudo completar el registro. Revisa los datos e inténtalo de nuevo."
        }
    }

    private func requestPasswordReset() async {
        clearFeedback()
        guard normalizedEmail.contains("@") else {
            errorMessage = "Escribe el correo de tu cuenta para solicitar el enlace."
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.sendPasswordReset(to: normalizedEmail)
            message = "Si existe una cuenta con ese correo, recibirás instrucciones para restablecer la contraseña."
        } catch {
            errorMessage = "No se pudo solicitar el enlace ahora. Inténtalo de nuevo más tarde."
        }
    }

    private func signInWithGoogle() async {
        clearFeedback()
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.signInWithGoogle()
        } catch {
            errorMessage = "No se pudo continuar con Google. Comprueba que el proveedor esté habilitado e inténtalo de nuevo."
        }
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        clearFeedback()
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let appleNonce
            else {
                errorMessage = "Apple no devolvió una credencial válida. Inténtalo otra vez."
                return
            }

            isWorking = true
            defer { isWorking = false }
            do {
                try await auth.signInWithApple(identityToken: identityToken, nonce: appleNonce)
            } catch {
                errorMessage = "No se pudo continuar con Apple. Comprueba que el proveedor esté configurado e inténtalo de nuevo."
            }
        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            break
        case .failure:
            errorMessage = "Apple no pudo completar el acceso. Inténtalo de nuevo."
        }
    }

    private func clearFeedback() {
        message = nil
        errorMessage = nil
    }
}

private struct PasswordRecoveryView: View {
    @ObservedObject var auth: AuthSessionStore
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didUpdatePassword = false

    var body: some View {
        ScreenShell(title: "Nueva contraseña", subtitle: "Elige una contraseña para proteger tu cuenta") {
            SecureField("Nueva contraseña", text: $password)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)
            SecureField("Repite la contraseña", text: $confirmation)
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            if didUpdatePassword {
                Text("Contraseña actualizada.")
                    .font(.subheadline)
                    .foregroundStyle(PulseStyle.mint)
            }

            Button {
                Task { await updatePassword() }
            } label: {
                HStack(spacing: 10) {
                    if isWorking { ProgressView().tint(PulseStyle.background) }
                    Text("Guardar contraseña")
                }
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PulseActionButtonStyle())
            .disabled(isWorking || didUpdatePassword)
        }
    }

    private func updatePassword() async {
        errorMessage = nil
        guard password.count >= 8 else {
            errorMessage = "La contraseña debe tener al menos 8 caracteres."
            return
        }
        guard password == confirmation else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.updatePassword(password)
            didUpdatePassword = true
        } catch {
            errorMessage = "No se pudo actualizar la contraseña. Solicita un nuevo enlace e inténtalo otra vez."
        }
    }
}
