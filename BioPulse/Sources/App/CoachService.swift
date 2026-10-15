import BioPulseDomain
import Combine
import Foundation

struct CoachContextPayload: Encodable {
    let metrics: [CoachMetricPayload]
    let trends: [CoachTrendPayload]
    let journal: [CoachJournalPayload]
}

struct CoachMetricPayload: Encodable {
    let name: String
    let value: Double
    let unit: String
    let observedAt: String
    let quality: String
    let provenance: String
    let period: String
}

struct CoachTrendPayload: Encodable {
    let name: String
    let direction: String
    let period: String
    let summary: String
    let baseline: String
    let unit: String
    let quality: String
}

struct CoachJournalPayload: Encodable {
    let category: String
    let title: String
    let notes: String
    let occurredAt: String
    let timezone: String
}

struct CoachMessagePayload: Encodable {
    let role: String
    let content: String
}

struct CoachReply: Decodable {
    let answer: String
    let memoryUpdated: Bool?
}

struct CoachConsentStatus: Decodable {
    let consented: Bool
}

private struct CoachActionRequest: Encodable {
    let action: String
}

private struct CoachSendRequest: Encodable {
    let action = "send"
    let messages: [CoachMessagePayload]
    let context: CoachContextPayload
}

private struct CoachReplyRequest: Decodable {
    let error: String?
}

enum CoachServiceError: Error {
    case notConfigured
    case unauthorized
    case consentRequired
    case dailyLimitReached
    case unavailable
    case invalidResponse
}

struct CoachService {
    func consentStatus(accessToken: String) async throws -> CoachConsentStatus {
        try await perform(CoachActionRequest(action: "consent_status"), accessToken: accessToken)
    }

    func grantConsent(accessToken: String) async throws {
        let _: CoachConsentStatusResponse = try await perform(
            CoachActionRequest(action: "grant_consent"),
            accessToken: accessToken
        )
    }

    func revokeConsent(accessToken: String) async throws {
        let _: CoachConsentStatusResponse = try await perform(
            CoachActionRequest(action: "revoke_consent"),
            accessToken: accessToken
        )
    }

    func clearMemory(accessToken: String) async throws {
        let _: CoachConsentStatusResponse = try await perform(
            CoachActionRequest(action: "clear_memory"),
            accessToken: accessToken
        )
    }

    func send(
        messages: [CoachMessagePayload],
        context: CoachContextPayload,
        accessToken: String
    ) async throws -> CoachReply {
        try await perform(
            CoachSendRequest(messages: messages, context: context),
            accessToken: accessToken
        )
    }

    private func perform<Response: Decodable, Body: Encodable>(
        _ body: Body,
        accessToken: String
    ) async throws -> Response {
        guard
            let urlValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let projectURL = URL(string: urlValue),
            projectURL.scheme == "https",
            projectURL.host != nil,
            let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty,
            let endpoint = URL(string: "functions/v1/coach", relativeTo: projectURL)?.absoluteURL
        else {
            throw CoachServiceError.notConfigured
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 55
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONDecoder().decode(CoachReplyRequest.self, from: data)
            switch payload?.error {
            case "unauthorized": throw CoachServiceError.unauthorized
            case "coach_consent_required": throw CoachServiceError.consentRequired
            case "daily_limit_reached": throw CoachServiceError.dailyLimitReached
            default: throw CoachServiceError.unavailable
            }
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw CoachServiceError.invalidResponse
        }
    }
}

private struct CoachConsentStatusResponse: Decodable {
    let ok: Bool?
    let policyVersion: String?
}

@MainActor
final class CoachViewModel: ObservableObject {
    enum Phase {
        case checkingConsent
        case consentRequired
        case conversation
        case unavailable
    }

    struct Entry: Identifiable {
        enum Role: Equatable {
            case user
            case assistant
        }

        let id = UUID()
        let role: Role
        let content: String
    }

    @Published private(set) var phase: Phase = .checkingConsent
    @Published private(set) var messages: [Entry] = []
    @Published private(set) var isSending = false
    @Published private(set) var isUpdatingConsent = false
    @Published private(set) var isUpdatingMemory = false
    @Published var draft = ""
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private let auth: AuthSessionStore
    private let health: HealthDataController
    private let journal: JournalController
    private let service = CoachService()

    init(auth: AuthSessionStore, health: HealthDataController, journal: JournalController) {
        self.auth = auth
        self.health = health
        self.journal = journal
    }

    func loadConsent() async {
        phase = .checkingConsent
        guard let accessToken = auth.session?.accessToken else {
            phase = .unavailable
            errorMessage = "Inicia sesión de nuevo para usar el Coach."
            return
        }
        do {
            let status = try await service.consentStatus(accessToken: accessToken)
            phase = status.consented ? .conversation : .consentRequired
        } catch {
            phase = .unavailable
            errorMessage = message(for: error)
        }
    }

    func authorizeCoach() async {
        guard let accessToken = auth.session?.accessToken else {
            phase = .unavailable
            errorMessage = "Inicia sesión de nuevo para autorizar el Coach."
            return
        }
        isUpdatingConsent = true
        errorMessage = nil
        defer { isUpdatingConsent = false }
        do {
            try await service.grantConsent(accessToken: accessToken)
            phase = .conversation
        } catch {
            errorMessage = message(for: error)
        }
    }

    func sendDraft() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard text.count <= 4_000 else {
            errorMessage = "La pregunta es demasiado larga. Resume el mensaje e inténtalo de nuevo."
            return
        }
        draft = ""
        messages.append(Entry(role: .user, content: text))
        await requestReply()
    }

    func sendSuggestion(_ text: String) async {
        guard !isSending else { return }
        messages.append(Entry(role: .user, content: text))
        await requestReply()
    }

    func retryLastMessage() async {
        guard messages.last?.role == .user, !isSending else { return }
        await requestReply()
    }

    func clearCoachMemory() async {
        guard let accessToken = auth.session?.accessToken else { return }
        isUpdatingMemory = true
        defer { isUpdatingMemory = false }
        do {
            try await service.clearMemory(accessToken: accessToken)
            noticeMessage = "La memoria breve del Coach se borró. La conversación actual sigue visible hasta cerrar esta pantalla."
        } catch {
            errorMessage = message(for: error)
        }
    }

    func revokeCoachConsent() async {
        guard let accessToken = auth.session?.accessToken else { return }
        isUpdatingConsent = true
        defer { isUpdatingConsent = false }
        do {
            try await service.revokeConsent(accessToken: accessToken)
            messages.removeAll()
            phase = .consentRequired
            noticeMessage = "Se revocó la autorización y se borró la memoria breve del Coach."
        } catch {
            errorMessage = message(for: error)
        }
    }

    func endConversation() {
        messages.removeAll()
        draft = ""
        errorMessage = nil
        noticeMessage = nil
    }

    private func requestReply() async {
        guard let accessToken = auth.session?.accessToken else {
            errorMessage = "Tu sesión venció. Inicia sesión de nuevo para continuar."
            return
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        await health.reload()
        await journal.load()
        let payload = makeContext()
        let chat = messages.suffix(16).map { message in
            CoachMessagePayload(
                role: message.role == .user ? "user" : "assistant",
                content: message.content
            )
        }
        do {
            let reply = try await service.send(messages: chat, context: payload, accessToken: accessToken)
            messages.append(Entry(role: .assistant, content: reply.answer))
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func makeContext() -> CoachContextPayload {
        let isoFormatter = ISO8601DateFormatter()
        let metrics = health.readings
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { metric, reading in
                CoachMetricPayload(
                    name: metric.displayName,
                    value: reading.value,
                    unit: metric.coachUnit,
                    observedAt: isoFormatter.string(from: reading.measuredAt),
                    quality: "observed",
                    provenance: "Apple Salud",
                    period: metric.coachPeriod
                )
            }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        let recentEntries = journal.entries
            .filter { $0.occurredAt >= cutoff }
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(20)
        let journalContext = recentEntries.map { entry in
            CoachJournalPayload(
                category: entry.category.rawValue,
                title: entry.title,
                notes: String(entry.notes.prefix(700)),
                occurredAt: isoFormatter.string(from: entry.occurredAt),
                timezone: entry.timeZoneIdentifier
            )
        }
        // The app currently has no historical trend store wired to this flow.
        // Keep the field explicit and empty rather than inventing a trend.
        return CoachContextPayload(metrics: metrics, trends: [], journal: journalContext)
    }

    private func message(for error: Error) -> String {
        guard let error = error as? CoachServiceError else {
            return "No se pudo conectar con el Coach. Comprueba tu conexión e inténtalo de nuevo."
        }
        switch error {
        case .notConfigured:
            return "El servicio del Coach aún no está configurado."
        case .unauthorized:
            return "Tu sesión no es válida. Inicia sesión de nuevo."
        case .consentRequired:
            phase = .consentRequired
            return "Autoriza el uso de contexto antes de enviar un mensaje al Coach."
        case .dailyLimitReached:
            return "Llegaste al límite diario del Coach. Puedes volver a intentarlo mañana."
        case .unavailable:
            return "El Coach no está disponible ahora. Inténtalo más tarde."
        case .invalidResponse:
            return "El Coach devolvió una respuesta que no pudimos leer. Inténtalo otra vez."
        }
    }
}

private extension HealthMetric {
    var coachUnit: String {
        switch self {
        case .heartRate, .restingHeartRate: "latidos/min"
        case .heartRateVariabilitySDNN: "ms"
        case .sleepAnalysis, .appleExerciseTime: "min"
        case .respiratoryRate: "respiraciones/min"
        case .oxygenSaturation: "%"
        case .stepCount: "pasos"
        case .activeEnergyBurned: "kcal"
        case .wristTemperature: "°C"
        case .walkingRunningDistance: "m"
        case .flightsClimbed: "pisos"
        case .workout: "sesiones"
        case .vo2Max: "mL/kg/min"
        case .heartRateRecoveryOneMinute: "latidos/min"
        }
    }

    var coachPeriod: String {
        switch self {
        case .stepCount, .activeEnergyBurned, .appleExerciseTime: "hoy, total diario"
        case .sleepAnalysis: "último periodo nocturno disponible"
        default: "medición más reciente disponible hoy"
        }
    }
}
