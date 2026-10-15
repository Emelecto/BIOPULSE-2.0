import Foundation
import Testing
@testable import BioPulseDomain

struct PersonalBaselineTests {
    @Test func requiresEnoughEligibleObservations() throws {
        let snapshots = try [40, 42, 44, 46, 48, 50].enumerated().map { offset, value in
            try snapshot(day: offset + 1, hrv: Double(value), quality: .observed, coverage: 1)
        }

        let baseline = BaselineCalculator.calculate(metric: .heartRateVariabilitySDNN, snapshots: snapshots)

        #expect(baseline == nil)
    }

    @Test func usesOnlyObservedOrPartialValuesWithEnoughCoverage() throws {
        let validValues = [40, 42, 44, 46, 48, 50, 52, 54]
        var snapshots = try validValues.enumerated().map { offset, value in
            try snapshot(day: offset + 1, hrv: Double(value), quality: .observed, coverage: 1)
        }
        snapshots.append(try snapshot(day: 9, hrv: 90, quality: .estimated, coverage: 1))
        snapshots.append(try snapshot(day: 10, hrv: 100, quality: .partial, coverage: 0.5))

        let baseline = try #require(BaselineCalculator.calculate(
            metric: .heartRateVariabilitySDNN,
            snapshots: snapshots,
            windowSize: 10,
            includeTestFixtures: true,
            computedAt: Date(timeIntervalSince1970: 0)
        ))

        #expect(baseline.center == 47)
        #expect(baseline.medianAbsoluteDeviation == 4)
        #expect(baseline.eligibleSampleCount == 8)
        #expect(baseline.methodVersion == "median-mad-v1")
    }

    private func snapshot(
        day: Int,
        hrv: Double,
        quality: MeasurementQuality,
        coverage: Double
    ) throws -> DailySnapshot {
        let localDay = try LocalDay(year: 2026, month: 10, day: day, timeZoneIdentifier: "America/Bogota")
        let metric = try DailyMetric(
            day: localDay,
            metric: .heartRateVariabilitySDNN,
            value: hrv,
            unit: .milliseconds,
            aggregation: .median,
            sampleCount: 1,
            coverage: coverage,
            source: .testFixture,
            quality: quality,
            sourceReferences: ["simulated-test-only"]
        )
        return try DailySnapshot(day: localDay, metrics: [metric])
    }
}
