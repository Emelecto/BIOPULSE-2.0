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

private enum AuthField: Hashable { case email, password, confirmation }

private struct AuthPasswordField: View {
    let title: String
    @Binding var text: String
    let isNew: Bool
    let field: AuthField
    let focus: FocusState<AuthField?>.Binding
    var onSubmit: () -> Void
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
            HStack(spacing: 4) {
                Group {
                    if visible { TextField(title, text: $text) }
                    else { SecureField(title, text: $text) }
                }
                .textContentType(isNew ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focus, equals: field)
                .submitLabel(field == .password && isNew ? .next : .go)
                .onSubmit(onSubmit)
                .accessibilityLabel(title)
                Button {
                    visible.toggle()
                    focus.wrappedValue = field
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(PulseStyle.secondary)
                .accessibilityLabel(visible ? "Ocultar \(title.lowercased())" : "Mostrar \(title.lowercased())")
            }
            .padding(.leading, 14).padding(.trailing, 4)
            .modifier(PulseInputSurface(focused: focus.wrappedValue == field))
        }
    }
}

private struct AuthView: View {
    // Temporary: Personal Team provisioning cannot include Sign in with Apple.
    // Re-enable after signing with a paid Apple Developer Program team.
    private static let appleSignInEnabled = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject var auth: AuthSessionStore
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var appleNonce: String?
    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?
    @State private var confirmationEmail: String?
    @State private var nextResendAt = Date.distantPast
    @State private var hasAppeared = false
    @FocusState private var focusedField: AuthField?

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header.pulseEntrance(visible: hasAppeared, reduceMotion: reduceMotion)
                if let configurationProblem = auth.configurationProblem {
                    StatusPanel(symbol: "exclamationmark.triangle", title: "Falta configurar la conexión", message: configurationProblem)
                } else if let confirmationEmail {
                    confirmationPanel(email: confirmationEmail)
                } else {
                    credentialForm.pulseEntrance(visible: hasAppeared, reduceMotion: reduceMotion, delay: 0.06)
                    providerOptions.pulseEntrance(visible: hasAppeared, reduceMotion: reduceMotion, delay: 0.1)
                }
                Label("Tu cuenta protege el acceso. Tú decides qué datos compartir.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(PulseStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 460, alignment: .leading)
            .padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { PulseBackdrop(forest: true) }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: mode)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: confirmationEmail)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: message)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: errorMessage)
        .onChange(of: mode) { _, _ in
            clearFeedback()
            passwordConfirmation = ""
        }
        .onAppear { hasAppeared = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            PulseIcon(symbol: "waveform.path.ecg")
            Text("BioPulse").font(.largeTitle.weight(.bold)).foregroundStyle(.white)
            Text(confirmationEmail != nil ? "Un paso más para entrar." : mode == .signIn ? "Tu bienestar,\nen perspectiva." : "Un espacio para conocerte.")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(mode == .signIn ? "Sueño, actividad y contexto. Empieza por tus señales." : "Crea tu cuenta para acceder a tus mediciones y tu Diario.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) {
            PulseContours().stroke(PulseStyle.mint.opacity(0.2), lineWidth: 0.7)
                .frame(width: 100, height: 130).clipped()
                .accessibilityHidden(true).allowsHitTesting(false)
        }
    }

    private var credentialForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            if typeSize.isAccessibilitySize {
                Picker("Acceso", selection: $mode) {
                    ForEach(AuthMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .disabled(isWorking)
            } else {
                Picker("Acceso", selection: $mode) {
                    ForEach(AuthMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(isWorking)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Correo electrónico").font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
                TextField("nombre@correo.com", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .padding(.horizontal, 14)
                    .modifier(PulseInputSurface(focused: focusedField == .email))
                    .accessibilityLabel("Correo electrónico")
            }
            .disabled(isWorking)

            AuthPasswordField(title: "Contraseña", text: $password, isNew: mode == .signUp, field: .password, focus: $focusedField) {
                if mode == .signUp { focusedField = .confirmation }
                else { Task { await submitCredentials() } }
            }
            .disabled(isWorking)

            if mode == .signUp {
                Text("Usa al menos 8 caracteres.").font(.caption).foregroundStyle(PulseStyle.secondary)
                AuthPasswordField(title: "Repite la contraseña", text: $passwordConfirmation, isNew: true, field: .confirmation, focus: $focusedField) {
                    Task { await submitCredentials() }
                }
                .disabled(isWorking)
                .transition(.opacity)
            } else {
                Button("Olvidé mi contraseña") { Task { await requestPasswordReset() } }
                    .font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.mint)
                    .frame(minHeight: 44).disabled(isWorking)
            }

            feedback

            Button { Task { await submitCredentials() } } label: {
                HStack(spacing: 10) {
                    if isWorking { ProgressView().tint(PulseStyle.background) }
                    Text(isWorking ? "Un momento…" : mode.rawValue)
                }
            }
            .buttonStyle(PulseActionButtonStyle())
            .disabled(isWorking || auth.configurationProblem != nil)

            if mode == .signIn {
                Button("¿Necesitas confirmar tu correo?") {
                    guard validEmail else {
                        errorMessage = "Escribe el correo con el que creaste la cuenta."
                        focusedField = .email
                        return
                    }
                    clearFeedback()
                    focusedField = nil
                    confirmationEmail = normalizedEmail
                }
                .font(.footnote).foregroundStyle(PulseStyle.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isWorking)
            }
        }
        .padding(20).pulseSurface(prominent: true)
    }

    @ViewBuilder
    private var feedback: some View {
        if let message { PulseFeedback(message: message) }
        if let errorMessage { PulseFeedback(message: errorMessage, isError: true) }
        if let callbackError = auth.callbackError { PulseFeedback(message: callbackError, isError: true) }
    }

    private func confirmationPanel(email: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            PulseIcon(symbol: "envelope.badge")
            Text("Revisa tu correo").font(.title2.weight(.semibold))
            Text(email).font(.headline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Text("Abre el enlace de confirmación en tu celular personal. Después vuelve aquí e inicia sesión con tu contraseña.")
                .font(.subheadline).foregroundStyle(PulseStyle.secondary)
            feedback
            Button("Volver a iniciar sesión") {
                clearFeedback()
                mode = .signIn
                confirmationEmail = nil
                password = ""
                passwordConfirmation = ""
                focusedField = .password
            }
            .buttonStyle(PulseActionButtonStyle()).disabled(isWorking)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(ceil(nextResendAt.timeIntervalSince(context.date))))
                Button {
                    Task { await resendConfirmation(to: email) }
                } label: {
                    HStack(spacing: 8) {
                        if isWorking { ProgressView().tint(PulseStyle.mint) }
                        Text(remaining > 0 ? "Reenviar en \(remaining) s" : "Reenviar enlace")
                    }
                }
                .buttonStyle(PulseSecondaryButtonStyle())
                .disabled(isWorking || remaining > 0)
            }
            Text("Revisa también la carpeta de correo no deseado.").font(.footnote).foregroundStyle(PulseStyle.secondary)
            Button("Usar otro correo") {
                clearFeedback()
                confirmationEmail = nil
                mode = .signUp
                password = ""
                passwordConfirmation = ""
                focusedField = .email
            }
            .font(.subheadline).foregroundStyle(PulseStyle.mint)
            .frame(minHeight: 44).disabled(isWorking)
        }
        .padding(22).pulseSurface(prominent: true)
    }

    private var validEmail: Bool {
        let parts = normalizedEmail.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
            && !normalizedEmail.contains(where: { $0.isWhitespace })
    }

    private func resendConfirmation(to email: String) async {
        guard !isWorking, Date.now >= nextResendAt else { return }
        clearFeedback()
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.resendConfirmation(to: email)
            nextResendAt = .now.addingTimeInterval(60)
            message = "Si la cuenta necesita confirmación, recibirás un nuevo enlace."
        } catch {
            errorMessage = "No se pudo reenviar el enlace. Espera un momento y vuelve a intentarlo."
        }
    }

    private var providerOptions: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
                Text(Self.appleSignInEnabled ? "o continúa con" : "Continúa con")
                    .font(.caption)
                    .foregroundStyle(PulseStyle.secondary)
                    .fixedSize()
                Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
            }

            if Self.appleSignInEnabled {
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
            }

            Button {
                Task { await signInWithGoogle() }
            } label: {
                Label("Continuar con Google", systemImage: "g.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .pulseSurface()
            }
            .buttonStyle(PulsePressButtonStyle())
            .disabled(isWorking || auth.configurationProblem != nil)
        }
    }

    private func submitCredentials() async {
        guard !isWorking else { return }
        clearFeedback()
        guard validEmail else {
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

        focusedField = nil
        isWorking = true
        defer { isWorking = false }
        do {
            if mode == .signIn {
                try await auth.signIn(email: normalizedEmail, password: password)
            } else {
                let confirmationRequired = try await auth.signUp(email: normalizedEmail, password: password)
                if confirmationRequired {
                    confirmationEmail = normalizedEmail
                    nextResendAt = .now.addingTimeInterval(60)
                    password = ""
                    passwordConfirmation = ""
                }
            }
        } catch {
            errorMessage = mode == .signIn
                ? "No se pudo iniciar sesión. Revisa tus datos e inténtalo de nuevo."
                : "No se pudo completar el registro. Revisa los datos e inténtalo de nuevo."
        }
    }

    private func requestPasswordReset() async {
        guard !isWorking else { return }
        clearFeedback()
        guard validEmail else {
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
        auth.callbackError = nil
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
    @FocusState private var focusedField: AuthField?

    var body: some View {
        ScreenShell(title: "Nueva contraseña", subtitle: "Elige una contraseña para proteger tu cuenta") {
            VStack(spacing: 18) {
                AuthPasswordField(title: "Nueva contraseña", text: $password, isNew: true, field: .password, focus: $focusedField) {
                    focusedField = .confirmation
                }
                AuthPasswordField(title: "Repite la contraseña", text: $confirmation, isNew: true, field: .confirmation, focus: $focusedField) {
                    Task { await updatePassword() }
                }
            }
            .disabled(isWorking || didUpdatePassword)
            .padding(20).pulseSurface(prominent: true)

            if let errorMessage {
                PulseFeedback(message: errorMessage, isError: true)
            }
            if didUpdatePassword {
                PulseFeedback(message: "Contraseña actualizada.")
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
        guard !isWorking, !didUpdatePassword else { return }
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
        focusedField = nil
        defer { isWorking = false }
        do {
            try await auth.updatePassword(password)
            didUpdatePassword = true
        } catch {
            errorMessage = "No se pudo actualizar la contraseña. Solicita un nuevo enlace e inténtalo otra vez."
        }
    }
}
