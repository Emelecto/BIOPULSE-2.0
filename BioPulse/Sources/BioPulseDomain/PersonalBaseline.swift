import Foundation

public struct PersonalBaseline: Codable, Equatable, Sendable {
    public let metric: MetricKind
    public let unit: MetricUnit
    public let center: Double
    public let medianAbsoluteDeviation: Double
    public let eligibleSampleCount: Int
    public let windowSize: Int
    public let minimumCoverage: Double
    public let methodVersion: String
    public let computedAt: Date
}

public enum BaselineCalculator {
    public static func calculate(
        metric: MetricKind,
        snapshots: [DailySnapshot],
        minimumSamples: Int = 7,
        windowSize: Int = 28,
        minimumCoverage: Double = 0.8,
        includeTestFixtures: Bool = false,
        computedAt: Date = .now
    ) -> PersonalBaseline? {
        guard minimumSamples > 0, windowSize >= minimumSamples, (0...1).contains(minimumCoverage) else {
            return nil
        }

        let recentSnapshots = snapshots.sorted { $0.day < $1.day }.suffix(windowSize)
        let values = recentSnapshots.compactMap { snapshot -> Double? in
            guard let dailyMetric = snapshot.metric(metric) else { return nil }
            let allowsQuality = dailyMetricIsEligible(
                dailyMetric,
                includeTestFixtures: includeTestFixtures
            )
            guard dailyMetric.unit == metric.expectedUnit,
                  allowsQuality,
                  dailyMetric.coverage >= minimumCoverage,
                  (dailyMetric.source != .testFixture || includeTestFixtures),
                  dailyMetric.value.isFinite else {
                return nil
            }
            return dailyMetric.value
        }

        guard values.count >= minimumSamples else { return nil }

        let center = median(values)
        let deviations = values.map { abs($0 - center) }

        return PersonalBaseline(
            metric: metric,
            unit: metric.expectedUnit,
            center: center,
            medianAbsoluteDeviation: median(deviations),
            eligibleSampleCount: values.count,
            windowSize: windowSize,
            minimumCoverage: minimumCoverage,
            methodVersion: "median-mad-v1",
            computedAt: computedAt
        )
    }

    private static func dailyMetricIsEligible(
        _ metric: DailyMetric,
        includeTestFixtures: Bool
    ) -> Bool {
        return metric.quality.isEligibleForBaseline || (
            includeTestFixtures && metric.quality == .simulatedForTest
        )
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let midpoint = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }
}
