import SwiftUI

struct CoachPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var model: CoachViewModel
    @State private var showingMemoryConfirmation = false
    @State private var showingRevokeConfirmation = false

    init(auth: AuthSessionStore, health: HealthDataController, journal: JournalController) {
        _model = StateObject(wrappedValue: CoachViewModel(auth: auth, health: health, journal: journal))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .checkingConsent:
                statusScreen(title: "Comprobando autorización…", symbol: "lock.shield") {
                    ProgressView().tint(PulseStyle.mint)
                }
            case .consentRequired:
                consentScreen
            case .conversation:
                conversationScreen
            case .unavailable:
                statusScreen(title: "Coach no disponible", symbol: "exclamationmark.triangle") {
                    Text(model.errorMessage ?? "Inténtalo de nuevo.")
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.secondary)
                    Button("Volver a intentar") { Task { await model.loadConsent() } }
                        .buttonStyle(PulseActionButtonStyle())
                }
            }
        }
        .background { PulseBackdrop() }
        .preferredColorScheme(.dark)
        .task { await model.loadConsent() }
        .onDisappear { model.endConversation() }
        .confirmationDialog(
            "Control de la memoria del Coach",
            isPresented: $showingMemoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Borrar memoria de siete días", role: .destructive) {
                Task { await model.clearCoachMemory() }
            }
            Button("Revocar autorización", role: .destructive) {
                showingRevokeConfirmation = true
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("La conversación actual se mantiene hasta cerrar el Coach. Al revocar, también se borra la memoria guardada.")
        }
        .confirmationDialog(
            "¿Revocar el acceso del Coach a tus datos?",
            isPresented: $showingRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Revocar y borrar memoria", role: .destructive) {
                Task { await model.revokeCoachConsent() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se enviará más contexto a Groq. Podrás autorizarlo otra vez cuando quieras.")
        }
    }

    private var consentScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(title: "Coach BioPulse", subtitle: "Antes de conversar, decide si quieres compartir contexto")

                VStack(alignment: .leading, spacing: 15) {
                    consentPoint("waveform.path.ecg", title: "Qué se envía", detail: "Tus mensajes, métricas agregadas disponibles de Apple Salud y hasta 20 entradas recientes del Diario cuando envíes una pregunta.")
                    consentPoint("chart.xyaxis.line", title: "Qué no se envía", detail: "No se envían muestras originales ni series crudas de HealthKit. Las tendencias solo se incluirán cuando haya historial conectado y disponible.")
                    consentPoint("clock.arrow.circlepath", title: "Memoria breve", detail: "BioPulse guarda un resumen breve por hasta siete días para dar continuidad. No se guarda el historial de la conversación y puedes borrar la memoria o revocar el permiso.")
                    consentPoint("externaldrive", title: "Proveedor externo", detail: "Groq procesa las solicitudes. Por defecto no conserva entradas ni respuestas, aunque puede retenerlas temporalmente hasta 30 días para investigar problemas de fiabilidad o abuso. Si se retienen, los datos se procesan en EE. UU. No escribas información que no quieras compartir.")
                }
                .padding(19)
                .pulseSurface()

                Text("El Coach ofrece información de bienestar y entrenamiento; no diagnostica ni prescribe tratamientos. Si describes síntomas graves, buscará orientarte hacia atención médica urgente.")
                    .font(.footnote)
                    .foregroundStyle(PulseStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let noticeMessage = model.noticeMessage {
                    Text(noticeMessage)
                        .font(.subheadline)
                        .foregroundStyle(PulseStyle.mint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await model.authorizeCoach() }
                } label: {
                    HStack(spacing: 10) {
                        if model.isUpdatingConsent { ProgressView().tint(PulseStyle.background) }
                        Text(model.isUpdatingConsent ? "Guardando autorización…" : "Autorizar y continuar")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PulseActionButtonStyle())
                .disabled(model.isUpdatingConsent)

                Button("Ahora no") { dismiss() }
                    .buttonStyle(PulseSecondaryButtonStyle())
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 30)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var conversationScreen: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if !typeSize.isAccessibilitySize { PulseIcon(symbol: "sparkles") }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Coach BioPulse")
                        .font(.headline)
                    Text("Bienestar, sueño y entrenamiento")
                        .font(.caption)
                        .foregroundStyle(PulseStyle.secondary)
                }
                Spacer(minLength: 8)
                Menu {
                    Button("Borrar memoria de siete días", systemImage: "eraser") {
                        showingMemoryConfirmation = true
                    }
                    Button("Revocar autorización…", systemImage: "hand.raised.slash", role: .destructive) {
                        showingRevokeConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(PulseStyle.mint)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Opciones de privacidad del Coach")
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(PulseStyle.secondary)
                .accessibilityLabel("Cerrar Coach")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            Divider().overlay(PulseStyle.elevated)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if model.messages.isEmpty {
                            welcomeContent
                        } else {
                            ForEach(model.messages) { entry in
                                messageRow(entry)
                                    .id(entry.id)
                            }
                        }

                        if model.isSending {
                            HStack(spacing: 10) {
                                ProgressView().tint(PulseStyle.mint)
                                Text("Analizando el contexto autorizado…")
                                    .font(.subheadline)
                                    .foregroundStyle(PulseStyle.secondary)
                            }
                            .padding(.horizontal, 20)
                            .id("coach-loading")
                        }
                        if let errorMessage = model.errorMessage {
                            errorBlock(errorMessage)
                                .id("coach-error")
                        }
                        if let noticeMessage = model.noticeMessage {
                            Text(noticeMessage)
                                .font(.footnote)
                                .foregroundStyle(PulseStyle.mint)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: model.messages.count) { _, _ in
                    guard let lastID = model.messages.last?.id else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composer
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("¿Qué te gustaría entender hoy?")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("Puedo ayudarte a interpretar las señales y el contexto que compartiste. No sustituyo a un profesional de salud.")
                .font(.subheadline)
                .foregroundStyle(PulseStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                suggestion("¿Qué significa mi HRV más reciente?")
                suggestion("¿Qué factores pueden influir en mi sueño?")
                suggestion("¿Cómo puedo ajustar el esfuerzo de mi entrenamiento?")
            }

            Label("Memoria breve hasta siete días · la conversación se borra al cerrar", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(PulseStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Pregunta sobre tus métricas o bienestar…", text: $model.draft, axis: .vertical)
                .font(.body)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .pulseSurface()
                .accessibilityLabel("Escribe una pregunta para el Coach")

            Button {
                Task { await model.sendDraft() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseStyle.background)
                    .frame(width: 48, height: 48)
                    .background(PulseStyle.mint, in: Circle())
            }
            .buttonStyle(PulsePressButtonStyle())
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending)
            .opacity(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending ? 0.5 : 1)
            .accessibilityLabel("Enviar pregunta")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(PulseStyle.background)
    }

    private func statusScreen<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            header(title: title, subtitle: "Asistente de bienestar de BioPulse")
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(PulseStyle.mint)
            content()
            Button("Cerrar") { dismiss() }
                .buttonStyle(PulseSecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: 620, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.largeTitle.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(PulseStyle.secondary)
        }
        .foregroundStyle(.white)
    }

    private func consentPoint(_ symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PulseStyle.mint)
                .frame(width: 23)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(PulseStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            Task { await model.sendSuggestion(text) }
        } label: {
            HStack(spacing: 12) {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseStyle.mint)
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 50)
            .background(PulseStyle.surface, in: RoundedRectangle(cornerRadius: 15))
            .contentShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(PulsePressButtonStyle())
        .disabled(model.isSending)
    }

    private func messageRow(_ entry: CoachViewModel.Entry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if entry.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseStyle.mint)
                    .frame(width: 28, height: 28)
                    .background(PulseStyle.surface, in: Circle())
                    .accessibilityHidden(true)
            } else {
                Spacer(minLength: 32)
            }

            Text(entry.content)
                .font(.body)
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(entry.role == .user ? PulseStyle.elevated : PulseStyle.surface,
                            in: RoundedRectangle(cornerRadius: 17))
                .frame(maxWidth: 560, alignment: entry.role == .user ? .trailing : .leading)

            if entry.role == .user {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: entry.role == .user ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.role == .user ? "Tú" : "Coach"): \(entry.content)")
    }

    private func errorBlock(_ errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(errorMessage)
                .font(.subheadline)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            Button("Reintentar") { Task { await model.retryLastMessage() } }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseStyle.mint)
                .frame(minHeight: 44)
                .disabled(model.isSending || model.messages.last?.role != .user)
        }
        .padding(.horizontal, 20)
    }
}
