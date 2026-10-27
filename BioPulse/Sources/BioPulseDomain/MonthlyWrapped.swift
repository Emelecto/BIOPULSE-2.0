import Foundation

public enum WrappedMetric: String, CaseIterable, Identifiable, Sendable {
    case sleep, steps, energy, hrv, restingHeartRate
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .sleep: "Sueño"
        case .steps: "Pasos"
        case .energy: "Energía activa"
        case .hrv: "HRV"
        case .restingHeartRate: "FC en reposo"
        }
    }
    public func formatted(_ value: Double?) -> String {
        guard let value, value.isFinite, value >= 0, value < 1e12 else { return "Sin registros" }
        let rounded = Int(value.rounded())
        switch self {
        case .sleep: return "\(rounded / 60) h \(rounded % 60) min"
        case .steps: return "\(rounded.formatted()) pasos"
        case .energy: return "\(rounded.formatted()) kcal"
        case .hrv: return "\(value.formatted(.number.precision(.fractionLength(0...1)))) ms"
        case .restingHeartRate: return "\(rounded) lpm"
        }
    }
}

public struct WrappedObservation: Sendable, Equatable {
    public let day: Date
    public let metric: WrappedMetric
    public let value: Double
    public let source: String
    public init(day: Date, metric: WrappedMetric, value: Double, source: String) {
        self.day = day; self.metric = metric; self.value = value; self.source = source
    }
}

public struct WrappedStatistics: Sendable, Equatable {
    public let count: Int
    public let mean: Double?
    public let total: Double?
    public let minimum: Double?
    public let maximum: Double?
}

public struct WrappedMoment: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let notes: String
    public let occurredAt: Date
    public init(id: String, title: String, notes: String, occurredAt: Date) {
        self.id = id; self.title = title; self.notes = notes; self.occurredAt = occurredAt
    }
}

/// Calendar-local monthly summaries. No interpolation, score calculation or network access.
public struct MonthlyWrapped: Sendable {
    public let month: Date
    public let days: [Date]
    public let observations: [WrappedObservation]
    public let entries: [JournalEntry]
    public let moments: [WrappedMoment]
    public let isPartial: Bool
    public let calendar: Calendar
    public var recordedDays: Int {
        Set(observations.map(\.day) + moments.map { calendar.startOfDay(for: $0.occurredAt) }).count
    }

    public init(month: Date, observations: [WrappedObservation], entries: [JournalEntry], additionalContext: [WrappedMoment] = [], now: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        let start = calendar.dateInterval(of: .month, for: month)?.start ?? calendar.startOfDay(for: month)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        self.month = start
        let today = calendar.startOfDay(for: now)
        self.isPartial = now >= start && now < end
        self.days = (0..<(calendar.range(of: .day, in: .month, for: start)?.count ?? 0)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        var byMetric: [WrappedMetric: [Date: WrappedObservation]] = [:]
        for point in observations where point.value.isFinite && point.value >= 0 && point.value < 1e12 {
            let day = calendar.startOfDay(for: point.day)
            guard day >= start, day < end, day <= today else { continue }
            byMetric[point.metric, default: [:]][day] = WrappedObservation(day: day, metric: point.metric, value: point.value, source: point.source)
        }
        self.observations = byMetric.values.flatMap { $0.values }.sorted { $0.day < $1.day }
        let filteredEntries = entries.filter { $0.occurredAt >= start && $0.occurredAt < end && $0.occurredAt <= now }.sorted { $0.occurredAt < $1.occurredAt }
        self.entries = filteredEntries
        self.moments = (filteredEntries.map { WrappedMoment(id: $0.id.uuidString, title: $0.title, notes: $0.notes, occurredAt: $0.occurredAt) } + additionalContext.filter { $0.occurredAt >= start && $0.occurredAt < end && $0.occurredAt <= now }).sorted { $0.occurredAt < $1.occurredAt }
    }

    public func series(_ metric: WrappedMetric) -> [WrappedObservation] { observations.filter { $0.metric == metric } }
    public func statistics(_ metric: WrappedMetric) -> WrappedStatistics {
        let values = series(metric).map(\.value)
        let total = values.reduce(0, +)
        return WrappedStatistics(count: values.count, mean: values.isEmpty ? nil : total / Double(values.count), total: values.isEmpty ? nil : total, minimum: values.min(), maximum: values.max())
    }
}
