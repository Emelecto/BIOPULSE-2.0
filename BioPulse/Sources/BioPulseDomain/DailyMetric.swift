import Foundation

public enum MeasurementSource: String, Codable, Sendable {
    case healthKit
    case csvImport
    case testFixture
}

public enum MeasurementQuality: String, Codable, Sendable {
    case observed
    case partial
    case estimated
    case simulatedForTest
    case invalid

    public var isEligibleForBaseline: Bool {
        self == .observed || self == .partial
    }
}

public struct LocalDay: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let timeZoneIdentifier: String

    public init(year: Int, month: Int, day: Int, timeZoneIdentifier: String) throws {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw DomainValidationError.invalidLocalDay(year: year, month: month, day: day, timeZoneIdentifier: timeZoneIdentifier)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else {
            throw DomainValidationError.invalidLocalDay(year: year, month: month, day: day, timeZoneIdentifier: timeZoneIdentifier)
        }
        let resolvedComponents = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolvedComponents.year == year, resolvedComponents.month == month, resolvedComponents.day == day else {
            throw DomainValidationError.invalidLocalDay(year: year, month: month, day: day, timeZoneIdentifier: timeZoneIdentifier)
        }

        self.year = year
        self.month = month
        self.day = day
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
        self.timeZoneIdentifier = timeZone.identifier
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        return lhs.timeZoneIdentifier < rhs.timeZoneIdentifier
    }
}

public struct DailyMetric: Codable, Equatable, Sendable {
    public let day: LocalDay
    public let metric: MetricKind
    public let value: Double
    public let unit: MetricUnit
    public let aggregation: MetricAggregation
    public let sampleCount: Int
    public let coverage: Double
    public let source: MeasurementSource
    public let quality: MeasurementQuality
    public let sourceReferences: [String]

    public init(
        day: LocalDay,
        metric: MetricKind,
        value: Double,
        unit: MetricUnit,
        aggregation: MetricAggregation,
        sampleCount: Int,
        coverage: Double,
        source: MeasurementSource,
        quality: MeasurementQuality,
        sourceReferences: [String] = []
    ) throws {
        guard value.isFinite else { throw DomainValidationError.nonFiniteValue(metric: metric) }
        guard unit == metric.expectedUnit else {
            throw DomainValidationError.unitMismatch(metric: metric, expected: metric.expectedUnit, received: unit)
        }
        guard sampleCount > 0 else { throw DomainValidationError.invalidSampleCount(metric: metric, sampleCount: sampleCount) }
        guard (0...1).contains(coverage) else { throw DomainValidationError.invalidCoverage(metric: metric, coverage: coverage) }
        guard quality != .invalid else { throw DomainValidationError.invalidQuality(metric: metric) }

        self.day = day
        self.metric = metric
        self.value = value
        self.unit = unit
        self.aggregation = aggregation
        self.sampleCount = sampleCount
        self.coverage = coverage
        self.source = source
        self.quality = quality
        self.sourceReferences = sourceReferences
    }
}

public struct DailySnapshot: Codable, Equatable, Sendable {
    public let day: LocalDay
    public let metrics: [MetricKind: DailyMetric]

    public init(day: LocalDay, metrics: [DailyMetric]) throws {
        var indexedMetrics: [MetricKind: DailyMetric] = [:]

        for metric in metrics {
            guard metric.day == day else {
                throw DomainValidationError.metricDayMismatch(metric: metric.metric)
            }
            guard indexedMetrics[metric.metric] == nil else {
                throw DomainValidationError.duplicateMetric(metric: metric.metric)
            }
            indexedMetrics[metric.metric] = metric
        }

        self.day = day
        self.metrics = indexedMetrics
    }

    public func metric(_ kind: MetricKind) -> DailyMetric? {
        metrics[kind]
    }
}

public enum DomainValidationError: Error, Equatable, Sendable {
    case invalidLocalDay(year: Int, month: Int, day: Int, timeZoneIdentifier: String)
    case nonFiniteValue(metric: MetricKind)
    case unitMismatch(metric: MetricKind, expected: MetricUnit, received: MetricUnit)
    case invalidSampleCount(metric: MetricKind, sampleCount: Int)
    case invalidCoverage(metric: MetricKind, coverage: Double)
    case invalidQuality(metric: MetricKind)
    case metricDayMismatch(metric: MetricKind)
    case duplicateMetric(metric: MetricKind)
}
