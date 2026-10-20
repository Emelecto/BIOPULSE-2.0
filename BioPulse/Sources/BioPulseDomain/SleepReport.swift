import Foundation

public enum SleepFactor: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case stress, noise, discomfort, alcohol, caffeine, travel, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .stress: "Estrés"
        case .noise: "Ruido"
        case .discomfort: "Dolor o malestar"
        case .alcohol: "Alcohol"
        case .caffeine: "Cafeína"
        case .travel: "Viaje o cambio de horario"
        case .other: "Otro"
        }
    }
}

public enum SleepReportError: Error, LocalizedError {
    case invalidDuration, invalidRating, invalidAwakenings, futureDay
    public var errorDescription: String? {
        switch self {
        case .invalidDuration: "Escribe una duración entre 0 y 24 horas."
        case .invalidRating: "Elige el descanso y la calidad del sueño, de 1 a 5."
        case .invalidAwakenings: "Elige una cantidad válida de despertares."
        case .futureDay: "La noche registrada no puede terminar en una fecha futura."
        }
    }
}

/// A user's estimate, never a HealthKit measurement or a source of sleep stages.
/// The date is the local calendar date on which the person woke up.
public struct SleepReport: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let wakeDay: LocalDay
    public let durationMinutes: Int
    public let restfulness: Int
    public let quality: Int
    /// 3 represents three or more awakenings. nil means not answered.
    public let awakenings: Int?
    public let factors: [SleepFactor]
    public let note: String
    public let preferManual: Bool
    public let recordedAt: Date

    public init(id: UUID = UUID(), wakeDate: Date, durationMinutes: Int, restfulness: Int,
                quality: Int, awakenings: Int? = nil, factors: [SleepFactor] = [], note: String = "",
                preferManual: Bool = false, recordedAt: Date = .now, calendar: Calendar = .current) throws {
        guard (0...1440).contains(durationMinutes) else { throw SleepReportError.invalidDuration }
        guard (1...5).contains(restfulness), (1...5).contains(quality) else { throw SleepReportError.invalidRating }
        if let awakenings, !(0...3).contains(awakenings) { throw SleepReportError.invalidAwakenings }
        guard calendar.startOfDay(for: wakeDate) <= calendar.startOfDay(for: recordedAt) else { throw SleepReportError.futureDay }
        self.id = id
        self.wakeDay = LocalDay(date: wakeDate, timeZone: calendar.timeZone)
        self.durationMinutes = durationMinutes
        self.restfulness = restfulness
        self.quality = quality
        self.awakenings = awakenings
        self.factors = SleepFactor.allCases.filter { factors.contains($0) }
        self.note = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        self.preferManual = preferManual
        self.recordedAt = recordedAt
    }

    /// Keep the recorded civil date when the user travels to a different time zone.
    public func date(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: wakeDay.year, month: wakeDay.month, day: wakeDay.day))
    }

    public var isValid: Bool {
        (0...1440).contains(durationMinutes) && (1...5).contains(restfulness) && (1...5).contains(quality)
            && (awakenings.map { (0...3).contains($0) } ?? true)
    }

    private enum CodingKeys: String, CodingKey {
        case id, wakeDay, durationMinutes, restfulness, quality, awakenings, factors, note, preferManual, recordedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let day = try container.decode(LocalDay.self, forKey: .wakeDay)
        let validatedDay = try LocalDay(year: day.year, month: day.month, day: day.day, timeZoneIdentifier: day.timeZoneIdentifier)
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(identifier: validatedDay.timeZoneIdentifier) else {
            throw SleepReportError.futureDay
        }
        calendar.timeZone = zone
        guard let date = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else {
            throw SleepReportError.futureDay
        }
        try self.init(id: container.decode(UUID.self, forKey: .id), wakeDate: date,
                      durationMinutes: container.decode(Int.self, forKey: .durationMinutes),
                      restfulness: container.decode(Int.self, forKey: .restfulness),
                      quality: container.decode(Int.self, forKey: .quality),
                      awakenings: container.decodeIfPresent(Int.self, forKey: .awakenings),
                      factors: container.decode([SleepFactor].self, forKey: .factors),
                      note: container.decode(String.self, forKey: .note),
                      preferManual: container.decode(Bool.self, forKey: .preferManual),
                      recordedAt: container.decode(Date.self, forKey: .recordedAt), calendar: calendar)
    }
}

public struct ResolvedSleepValues: Sendable {
    public let values: [WellnessValue]
    public let reportedDays: Set<Date>

    public func includesSelfReport(on day: Date, calendar: Calendar = .current) -> Bool {
        let end = calendar.startOfDay(for: day)
        let start = calendar.date(byAdding: .day, value: -14, to: end) ?? end
        return reportedDays.contains { $0 >= start && $0 <= end }
    }

    public static func resolve(observed: [WellnessValue], reports: [SleepReport],
                               calendar: Calendar = .current) -> ResolvedSleepValues {
        var nights: [Date: WellnessValue] = [:]
        for value in observed where value.metric == .sleepDuration && value.isUsable {
            let day = calendar.startOfDay(for: value.day)
            nights[day] = WellnessValue(day: day, metric: .sleepDuration, value: value.value, source: value.source)
        }
        var latestReports: [Date: SleepReport] = [:]
        // The most recently saved report wins if a file contains duplicate dates.
        for report in reports.sorted(by: { $0.recordedAt < $1.recordedAt }) where report.isValid {
            guard let date = report.date(calendar: calendar) else { continue }
            let day = calendar.startOfDay(for: date)
            latestReports[day] = report
        }
        for (day, report) in latestReports {
            guard nights[day] == nil || report.preferManual else { continue }
            nights[day] = WellnessValue(day: day, metric: .sleepDuration, value: Double(report.durationMinutes), source: .selfReported)
        }
        return ResolvedSleepValues(values: observed.filter { $0.metric != .sleepDuration }
                                   + nights.keys.sorted().compactMap { nights[$0] },
                                   reportedDays: Set(nights.filter { $0.value.source == .selfReported }.keys))
    }
}

public struct ScoreHistoryRequirement: Identifiable, Sendable {
    public let metric: MetricKind
    public let available: Int
    public let required: Int
    public let windowDays: Int
    public var id: String { metric.rawValue }
    public var isReady: Bool { available >= required }
}

extension WellnessScores {
    public static func calibration(_ values: [WellnessValue], day: Date, includeBiometrics: Bool,
                                   calendar: Calendar = .current) -> [ScoreHistoryRequirement] {
        let kinds: [MetricKind] = includeBiometrics
            ? [.sleepDuration, .heartRateVariabilitySDNN, .restingHeartRate, .activeEnergyBurned] : [.sleepDuration]
        let end = calendar.startOfDay(for: day)
        return kinds.map { kind in
            let window = kind == .sleepDuration ? 14 : 28
            let start = calendar.date(byAdding: .day, value: -window, to: end) ?? end
            let days = Set(values.filter {
                $0.metric == kind && $0.day >= start && $0.day < end && $0.isUsable
            }.map { calendar.startOfDay(for: $0.day) })
            return ScoreHistoryRequirement(metric: kind, available: days.count,
                                           required: kind == .sleepDuration ? 7 : 14, windowDays: window)
        }
    }
}
