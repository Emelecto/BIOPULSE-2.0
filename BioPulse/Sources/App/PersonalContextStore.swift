import Combine
import Foundation

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

    private static let schemaVersion = 1
    private let fileURL: URL
    private let sleepTargetKey: String
    private var allowsWrites = true

    init(userID: UUID) {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            preconditionFailure("Application Support must be available on iOS.")
        }
        fileURL = baseURL
            .appendingPathComponent("BioPulse", isDirectory: true)
            .appendingPathComponent("Accounts", isDirectory: true)
            .appendingPathComponent(userID.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("personal-context-v1.json", isDirectory: false)
        sleepTargetKey = "BioPulse.sleepTarget.\(userID.uuidString.lowercased())"
        let storedTarget = UserDefaults.standard.integer(forKey: sleepTargetKey)
        if (360...600).contains(storedTarget) { sleepTargetMinutes = storedTarget }
        load()
    }

    func updateSleepTarget(_ minutes: Int) {
        guard (360...600).contains(minutes), minutes.isMultiple(of: 30) else { return }
        sleepTargetMinutes = minutes
        UserDefaults.standard.set(minutes, forKey: sleepTargetKey)
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
        } catch {
            allowsWrites = false
            persistenceMessage = "No se pudieron leer tus datos locales. BioPulse no los sobrescribirá."
        }
    }

    private func persist() {
        guard allowsWrites else { return }
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
                preferences: preferences
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(envelope).write(to: fileURL, options: [.atomic, .completeFileProtection])
            persistenceMessage = nil
        } catch {
            persistenceMessage = "No se pudo guardar en este dispositivo. Comprueba el espacio disponible e inténtalo otra vez."
        }
    }
}

private struct PersonalContextEnvelope: Codable {
    let schemaVersion: Int
    let checkIns: [PersonalCheckIn]
    let annotations: [PersonalAnnotation]
    let experiments: [PersonalExperiment]
    let preferences: PersonalizationPreferences
}
