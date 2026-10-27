import Combine
import Foundation
import UserNotifications
import BioPulseDomain

struct SleepReminderPreferences: Codable, Equatable {
    var enabled = false
    var hour = 9
    var minute = 0
}

enum PersonalFocus: String, CaseIterable, Codable, Identifiable {
    case sleep
    case activity
    case journal
    case understanding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: "Comprender mi sueño"
        case .activity: "Observar mi actividad"
        case .journal: "Dar contexto en mi Diario"
        case .understanding: "Aprender sobre mis señales"
        }
    }

    var symbol: String {
        switch self {
        case .sleep: "moon.stars"
        case .activity: "figure.walk"
        case .journal: "square.and.pencil"
        case .understanding: "book.closed"
        }
    }
}

enum PersonalReadingLevel: String, CaseIterable, Codable, Identifiable {
    case simple
    case technical

    var id: String { rawValue }
    var title: String { self == .simple ? "Sencilla" : "Técnica" }
}

enum CheckInEnergy: String, CaseIterable, Codable, Identifiable {
    case low
    case steady
    case energized

    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: "Con poca energía"
        case .steady: "Intermedia"
        case .energized: "Con energía"
        }
    }
    var symbol: String {
        switch self {
        case .low: "battery.25percent"
        case .steady: "battery.50percent"
        case .energized: "battery.100percent"
        }
    }
}

enum AnnotationKind: String, CaseIterable, Codable, Identifiable {
    case travel
    case training
    case lateCaffeine
    case illness
    case scheduleChange
    case other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .travel: "Viaje"
        case .training: "Entrenamiento"
        case .lateCaffeine: "Café tarde"
        case .illness: "Me sentí mal"
        case .scheduleChange: "Cambio de horario"
        case .other: "Otro contexto"
        }
    }
    var symbol: String {
        switch self {
        case .travel: "airplane"
        case .training: "figure.run"
        case .lateCaffeine: "cup.and.saucer"
        case .illness: "cross.case"
        case .scheduleChange: "clock"
        case .other: "bookmark"
        }
    }
}

struct PersonalCheckIn: Codable, Equatable, Identifiable {
    let id: UUID
    let energy: CheckInEnergy
    let note: String
    let recordedAt: Date

    init(id: UUID = UUID(), energy: CheckInEnergy, note: String, recordedAt: Date = .now) {
        self.id = id
        self.energy = energy
        self.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        self.recordedAt = recordedAt
    }
}

struct PersonalAnnotation: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: AnnotationKind
    let title: String
    let note: String
    let occurredAt: Date

    init(id: UUID = UUID(), kind: AnnotationKind, title: String, note: String, occurredAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        self.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        self.occurredAt = occurredAt
    }
}

struct PersonalExperiment: Codable, Equatable, Identifiable {
    let id: UUID
    let question: String
    let habit: String
    let startedAt: Date
    let plannedDays: Int
    var reflection: String
    var completedAt: Date?

    init(id: UUID = UUID(), question: String, habit: String, startedAt: Date = .now, plannedDays: Int) {
        self.id = id
        self.question = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180))
        self.habit = String(habit.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        self.startedAt = startedAt
        self.plannedDays = min(max(plannedDays, 3), 28)
        self.reflection = ""
        self.completedAt = nil
    }
}

struct PersonalizationPreferences: Codable, Equatable {
    var focus: PersonalFocus = .understanding
    var readingLevel: PersonalReadingLevel = .simple
    var weeklySummaryWeekday = 2
    var dailyReminderEnabled = false
    var dailyReminderHour = 9
    var weeklySummaryReminderEnabled = false
    var weeklySummaryHour = 10
    var quietStartHour = 22
    var quietEndHour = 7
}

@MainActor
final class PersonalContextStore: ObservableObject {
    @Published private(set) var checkIns: [PersonalCheckIn] = []
    @Published private(set) var annotations: [PersonalAnnotation] = []
    @Published private(set) var experiments: [PersonalExperiment] = []
    @Published private(set) var preferences = PersonalizationPreferences()
    @Published private(set) var persistenceMessage: String?
    @Published private(set) var sleepTargetMinutes = 480
    @Published private(set) var sleepReports: [SleepReport] = []
    @Published private(set) var sleepReminder = SleepReminderPreferences()

    private static let schemaVersion = 1
    private let fileURL: URL
    private let sleepTargetKey: String
    let userID: UUID
    let isPresentationMode: Bool
    private var allowsWrites = true

    init(userID: UUID, presentationMode: Bool = false) {
        self.userID = userID
        isPresentationMode = presentationMode
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support must be available on iOS.")
        }
        fileURL = baseURL
            .appendingPathComponent("BioPulse", isDirectory: true)
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("personal-context-v1.json", isDirectory: false)
        sleepTargetKey = "BioPulse.sleepTarget.\(userID.uuidString.lowercased())"
        if presentationMode {
            seedPresentationData()
            return
        }
        let storedTarget = UserDefaults.standard.integer(forKey: sleepTargetKey)
        if (360...600).contains(storedTarget) { sleepTargetMinutes = storedTarget }
        load()
    }

    func updateSleepTarget(_ minutes: Int) {
        guard (360...600).contains(minutes), minutes.isMultiple(of: 30) else { return }
        sleepTargetMinutes = minutes
        if !isPresentationMode { UserDefaults.standard.set(minutes, forKey: sleepTargetKey) }
    }

    func sleepReport(on date: Date = .now) -> SleepReport? {
        let day = LocalDay(date: date, timeZone: .current)
        return sleepReports.first { $0.wakeDay.year == day.year && $0.wakeDay.month == day.month && $0.wakeDay.day == day.day }
    }

    @discardableResult
    func saveSleepReport(_ report: SleepReport) -> Bool {
        guard report.isValid, let day = report.date(), Calendar.current.startOfDay(for: day) <= Calendar.current.startOfDay(for: .now) else { return false }
        let previous = sleepReports
        sleepReports.removeAll { $0.wakeDay.year == report.wakeDay.year && $0.wakeDay.month == report.wakeDay.month && $0.wakeDay.day == report.wakeDay.day }
        sleepReports.append(report)
        sleepReports.sort { $0.wakeDay > $1.wakeDay }
        guard persist() else { sleepReports = previous; return false }
        return true
    }

    @discardableResult
    func deleteSleepReport(_ report: SleepReport) -> Bool {
        let previous = sleepReports
        sleepReports.removeAll { $0.id == report.id }
        guard persist() else { sleepReports = previous; return false }
        return true
    }

    @discardableResult
    func updateSleepReminder(_ update: (inout SleepReminderPreferences) -> Void) -> Bool {
        let previous = sleepReminder
        update(&sleepReminder)
        guard persist() else { sleepReminder = previous; return false }
        return true
    }

    func scheduleSleepReminder() async -> String? {
        guard !isPresentationMode else { return nil }
        await SleepReminderNotifications.schedule(userID: userID, reminder: sleepReminder,
                                                 quietStart: preferences.quietStartHour, quietEnd: preferences.quietEndHour)
    }

    var activeExperiments: [PersonalExperiment] {
        experiments.filter { $0.completedAt == nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var completedExperiments: [PersonalExperiment] {
        experiments
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    func checkIn(on date: Date = .now) -> PersonalCheckIn? {
        checkIns.first { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
    }

    func saveCheckIn(energy: CheckInEnergy, note: String, on date: Date = .now) {
        let entry = PersonalCheckIn(energy: energy, note: note, recordedAt: date)
        checkIns.removeAll { Calendar.current.isDate($0.recordedAt, inSameDayAs: date) }
        checkIns.append(entry)
        checkIns.sort { $0.recordedAt > $1.recordedAt }
        persist()
    }

    func addAnnotation(kind: AnnotationKind, title: String, note: String, at date: Date) {
        let annotation = PersonalAnnotation(kind: kind, title: title, note: note, occurredAt: date)
        guard !annotation.title.isEmpty else { return }
        annotations.append(annotation)
        annotations.sort { $0.occurredAt > $1.occurredAt }
        persist()
    }

    func deleteAnnotation(_ annotation: PersonalAnnotation) {
        annotations.removeAll { $0.id == annotation.id }
        persist()
    }

    func startExperiment(question: String, habit: String, plannedDays: Int) {
        let experiment = PersonalExperiment(question: question, habit: habit, plannedDays: plannedDays)
        guard !experiment.question.isEmpty, !experiment.habit.isEmpty else { return }
        experiments.insert(experiment, at: 0)
        persist()
    }

    func finishExperiment(_ experiment: PersonalExperiment, reflection: String) {
        guard let index = experiments.firstIndex(where: { $0.id == experiment.id }) else { return }
        experiments[index].reflection = String(reflection.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000))
        experiments[index].completedAt = .now
        persist()
    }

    func updatePreferences(_ update: (inout PersonalizationPreferences) -> Void) {
        update(&preferences)
        persist()
    }

    func deleteLocalAccountData() throws {
        if isPresentationMode {
            checkIns = []
            annotations = []
            experiments = []
            sleepReports = []
            sleepReminder = SleepReminderPreferences()
            return
        }
        allowsWrites = false
        SleepReminderNotifications.cancel(for: userID)
        let reminders = ["biopulse.daily.checkin", "biopulse.weekly.summary"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminders)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: reminders)
        let directory = fileURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        UserDefaults.standard.removeObject(forKey: sleepTargetKey)
        checkIns = []
        annotations = []
        experiments = []
        sleepReports = []
        sleepReminder = SleepReminderPreferences()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let envelope = try decoder.decode(PersonalContextEnvelope.self, from: data)
            guard envelope.schemaVersion == Self.schemaVersion else {
                allowsWrites = false
                persistenceMessage = "Tus ajustes y registros locales usan una versión distinta; no se sobrescribirán."
                return
            }
            checkIns = envelope.checkIns.sorted { $0.recordedAt > $1.recordedAt }
            annotations = envelope.annotations.sorted { $0.occurredAt > $1.occurredAt }
            experiments = envelope.experiments
            preferences = envelope.preferences
            sleepReports = (envelope.sleepReports ?? []).filter(\.isValid).sorted { $0.wakeDay > $1.wakeDay }
            sleepReminder = envelope.sleepReminder ?? SleepReminderPreferences()
        } catch {
            allowsWrites = false
            persistenceMessage = "No se pudieron leer tus datos locales. BioPulse no los sobrescribirá."
        }
    }

    @discardableResult
    private func persist() -> Bool {
        if isPresentationMode { return true }
        guard allowsWrites else { return false }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let envelope = PersonalContextEnvelope(
                schemaVersion: Self.schemaVersion,
                checkIns: checkIns,
                annotations: annotations,
                experiments: experiments,
                preferences: preferences,
                sleepReports: sleepReports,
                sleepReminder: sleepReminder
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(envelope).write(to: fileURL, options: [.atomic, .completeFileProtection])
            persistenceMessage = nil
            return true
        } catch {
            persistenceMessage = "No se pudo guardar en este dispositivo. Comprueba el espacio disponible e inténtalo otra vez."
            return false
        }
    }

    func resetPresentationData() {
        guard isPresentationMode else { return }
        seedPresentationData()
    }

    private func seedPresentationData() {
        sleepTargetMinutes = 480
        preferences = PersonalizationPreferences()
        preferences.focus = .sleep
        preferences.readingLevel = .simple
        sleepReminder = SleepReminderPreferences()
        let calendar = Calendar.current
        checkIns = (0..<12).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset * 2, to: .now) else { return nil }
            let energy: CheckInEnergy = offset.isMultiple(of: 4) ? .energized : offset.isMultiple(of: 3) ? .steady : .energized
            return PersonalCheckIn(energy: energy, note: offset.isMultiple(of: 3) ? "Un día con buen ritmo y una pausa para recuperarme." : "Me sentí con energía durante la mañana.", recordedAt: date)
        }
        annotations = (0..<6).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset * 5 - 1, to: .now) else { return nil }
            let kind: AnnotationKind = offset.isMultiple(of: 2) ? .training : .lateCaffeine
            return PersonalAnnotation(kind: kind, title: kind == .training ? "Entrenamiento" : "Café por la tarde", note: kind == .training ? "Sesión de fuerza y movilidad." : "Un cambio de rutina para tener en cuenta.", occurredAt: date)
        }
        experiments = [PersonalExperiment(question: "¿Qué cambia cuando mantengo una rutina de sueño?", habit: "Apagar pantallas antes de dormir", startedAt: calendar.date(byAdding: .day, value: -9, to: .now) ?? .now, plannedDays: 14)]
        sleepReports = (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { return nil }
            return try? SleepReport(wakeDate: date, durationMinutes: 420 + ((offset * 17) % 70), restfulness: 3 + (offset % 3 == 0 ? 1 : 0), quality: 4, awakenings: offset % 4, factors: offset % 5 == 0 ? [.caffeine] : [], note: "Rutina nocturna registrada.", recordedAt: .now, calendar: calendar)
        }
    }
}

private struct PersonalContextEnvelope: Codable {
    let schemaVersion: Int
    let checkIns: [PersonalCheckIn]
    let annotations: [PersonalAnnotation]
    let experiments: [PersonalExperiment]
    let preferences: PersonalizationPreferences
    // Optional keys preserve existing v1 files without discarding older personal data.
    let sleepReports: [SleepReport]?
    let sleepReminder: SleepReminderPreferences?
}

@MainActor
enum SleepReminderNotifications {
    private static var revision = UUID()
    private static let prefix = "biopulse.sleep."
    private static var activeRequest: String?

    static func cancel(for userID: UUID) {
        revision = UUID()
        let accountPrefix = prefix + userID.uuidString.lowercased() + "."
        let center = UNUserNotificationCenter.current()
        if let activeRequest, activeRequest.hasPrefix(accountPrefix) {
            center.removePendingNotificationRequests(withIdentifiers: [activeRequest])
            Self.activeRequest = nil
        }
        Task {
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(accountPrefix) })
            center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(accountPrefix) })
        }
    }

    static func cancelActive() {
        revision = UUID()
        if let activeRequest {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [activeRequest])
            center.removeDeliveredNotifications(withIdentifiers: [activeRequest])
        }
        activeRequest = nil
    }

    static func cancelAll() async {
        cancelActive()
        let token = revision
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard revision == token else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        let delivered = await center.deliveredNotifications()
        guard revision == token else { return }
        center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) })
    }

    static func schedule(userID: UUID, reminder: SleepReminderPreferences, quietStart: Int, quietEnd: Int) async -> String? {
        let token = UUID()
        revision = token
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard revision == token else { return nil }
        let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        activeRequest = nil
        guard reminder.enabled else { return nil }
        let settings = await center.notificationSettings()
        guard revision == token else { return nil }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return "Permite las notificaciones de BioPulse en Ajustes para recibir el recordatorio."
        }
        let hour = min(23, max(0, reminder.hour))
        let quiet = quietStart == quietEnd ? false
            : quietStart < quietEnd ? (hour >= quietStart && hour < quietEnd) : (hour >= quietStart || hour < quietEnd)
        guard !quiet else { return "El recordatorio de sueño cae dentro de tu horario silencioso. Cambia la hora para programarlo." }
        let content = UNMutableNotificationContent()
        content.title = "¿Cómo dormiste?"
        content.body = "Dedica un momento a registrar tu descanso en BioPulse."
        content.sound = .default
        content.userInfo = ["destination": "sleep-check-in", "accountID": userID.uuidString]
        var time = DateComponents()
        time.hour = hour
        time.minute = min(59, max(0, reminder.minute))
        let identifier = prefix + userID.uuidString.lowercased() + "." + token.uuidString
        activeRequest = identifier
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                       trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true)))
            // A sign-out or another account may have superseded this asynchronous request.
            if revision != token {
                center.removePendingNotificationRequests(withIdentifiers: [identifier])
            }
            return nil
        } catch {
            return "No se pudo programar el recordatorio. Inténtalo de nuevo desde Sueño."
        }
    }
}
