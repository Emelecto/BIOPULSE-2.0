import Foundation

public struct MetricPeriodComparison: Equatable, Sendable {
    public let recentAverage: Double
    public let referenceMedian: Double
    public let absoluteDifference: Double
    public let recentObservationCount: Int
    public let referenceObservationCount: Int
}

public enum MetricPeriodComparisonResult: Equatable, Sendable {
    case available(MetricPeriodComparison)
    case insufficientData(recentObservationCount: Int, referenceObservationCount: Int)
}

/// Describes a recent window beside a personal reference window. It does not
/// infer why the values differ or whether a change is good or bad.
public enum MetricPeriodComparisonCalculator {
    public static func compare(
        recentValues: [Double],
        referenceValues: [Double],
        minimumRecentObservations: Int = 4,
        minimumReferenceObservations: Int = 7
    ) -> MetricPeriodComparisonResult {
        let recent = recentValues.filter { $0.isFinite }
        let reference = referenceValues.filter { $0.isFinite }

        guard minimumRecentObservations > 0,
              minimumReferenceObservations > 0,
              recent.count >= minimumRecentObservations,
              reference.count >= minimumReferenceObservations else {
            return .insufficientData(
                recentObservationCount: recent.count,
                referenceObservationCount: reference.count
            )
        }

        let recentAverage = recent.reduce(0, +) / Double(recent.count)
        let referenceMedian = median(reference)
        return .available(MetricPeriodComparison(
            recentAverage: recentAverage,
            referenceMedian: referenceMedian,
            absoluteDifference: recentAverage - referenceMedian,
            recentObservationCount: recent.count,
            referenceObservationCount: reference.count
        ))
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
