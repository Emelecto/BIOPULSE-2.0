import Foundation

public enum TrendDirection: String, Codable, Sendable {
    case abovePersonalReference
    case belowPersonalReference
    case withinExpectedVariation
    case baselineHasNoVariation
}

public struct AvailableMetricTrend: Codable, Equatable, Sendable {
    public let metric: MetricKind
    public let day: LocalDay
    public let currentValue: Double
    public let unit: MetricUnit
    public let baseline: PersonalBaseline
    public let absoluteChangeFromBaseline: Double
    public let normalizedDeviation: Double?
    public let direction: TrendDirection
    public let coverage: Double
    public let referenceRangeMultiplier: Double
    public let methodVersion: String
}

public enum TrendUnavailableReason: String, Codable, Sendable {
    case missingCurrentMeasurement
    case currentMeasurementIneligible
    case currentCoverageTooLow
    case testFixtureExcluded
    case insufficientHistoricalObservations
}

public struct UnavailableMetricTrend: Codable, Equatable, Sendable {
    public let metric: MetricKind
    public let day: LocalDay
    public let reason: TrendUnavailableReason
}

public enum MetricTrendAnalysis: Codable, Equatable, Sendable {
    case available(AvailableMetricTrend)
    case unavailable(UnavailableMetricTrend)
}

public enum TrendCalculator {
    public static func analyze(
        metric: MetricKind,
        current: DailySnapshot,
        history: [DailySnapshot],
        minimumBaselineSamples: Int = 7,
        baselineWindowSize: Int = 28,
        minimumCoverage: Double = 0.8,
        sensitivityMultiplier: Double = 2,
        includeTestFixtures: Bool = false,
        computedAt: Date = .now
    ) -> MetricTrendAnalysis {
        guard let currentMetric = current.metric(metric) else {
            return unavailable(metric: metric, day: current.day, reason: .missingCurrentMeasurement)
        }
        let currentQualityIsEligible = currentMetric.quality.isEligibleForBaseline || (
            includeTestFixtures && currentMetric.quality == .simulatedForTest
        )
        guard currentQualityIsEligible else {
            return unavailable(metric: metric, day: current.day, reason: .currentMeasurementIneligible)
        }
        guard currentMetric.coverage >= minimumCoverage else {
            return unavailable(metric: metric, day: current.day, reason: .currentCoverageTooLow)
        }
        guard currentMetric.source != .testFixture || includeTestFixtures else {
            return unavailable(metric: metric, day: current.day, reason: .testFixtureExcluded)
        }
        guard sensitivityMultiplier > 0 else {
            return unavailable(metric: metric, day: current.day, reason: .insufficientHistoricalObservations)
        }

        let pastSnapshots = history.filter {
            $0.day < current.day && $0.day.timeZoneIdentifier == current.day.timeZoneIdentifier
        }
        guard let baseline = BaselineCalculator.calculate(
            metric: metric,
            snapshots: pastSnapshots,
            minimumSamples: minimumBaselineSamples,
            windowSize: baselineWindowSize,
            minimumCoverage: minimumCoverage,
            includeTestFixtures: includeTestFixtures,
            computedAt: computedAt
        ) else {
            return unavailable(metric: metric, day: current.day, reason: .insufficientHistoricalObservations)
        }

        let absoluteChange = currentMetric.value - baseline.center
        let normalizedDeviation = normalizedDeviation(
            absoluteChange: absoluteChange,
            medianAbsoluteDeviation: baseline.medianAbsoluteDeviation
        )
        let direction = trendDirection(
            absoluteChange: absoluteChange,
            medianAbsoluteDeviation: baseline.medianAbsoluteDeviation,
            sensitivityMultiplier: sensitivityMultiplier
        )

        return .available(AvailableMetricTrend(
            metric: metric,
            day: current.day,
            currentValue: currentMetric.value,
            unit: currentMetric.unit,
            baseline: baseline,
            absoluteChangeFromBaseline: absoluteChange,
            normalizedDeviation: normalizedDeviation,
            direction: direction,
            coverage: currentMetric.coverage,
            referenceRangeMultiplier: sensitivityMultiplier,
            methodVersion: "baseline-comparison-mad-threshold-v1"
        ))
    }

    private static func unavailable(
        metric: MetricKind,
        day: LocalDay,
        reason: TrendUnavailableReason
    ) -> MetricTrendAnalysis {
        .unavailable(UnavailableMetricTrend(metric: metric, day: day, reason: reason))
    }

    private static func normalizedDeviation(
        absoluteChange: Double,
        medianAbsoluteDeviation: Double
    ) -> Double? {
        guard medianAbsoluteDeviation > 0 else { return nil }
        return absoluteChange / medianAbsoluteDeviation
    }

    private static func trendDirection(
        absoluteChange: Double,
        medianAbsoluteDeviation: Double,
        sensitivityMultiplier: Double
    ) -> TrendDirection {
        guard medianAbsoluteDeviation > 0 else { return .baselineHasNoVariation }

        let threshold = medianAbsoluteDeviation * sensitivityMultiplier
        if absoluteChange > threshold { return .abovePersonalReference }
        if absoluteChange < -threshold { return .belowPersonalReference }
        return .withinExpectedVariation
    }
}
