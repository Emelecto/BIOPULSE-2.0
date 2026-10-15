import Foundation
import Testing
@testable import BioPulseDomain

struct MetricTrendTests {
    @Test func comparesOnlyPastObservationsAgainstTheCurrentDay() throws {
        let history = try [40, 42, 44, 46, 48, 50, 52].enumerated().map { offset, value in
            try snapshot(day: offset + 1, hrv: Double(value))
        }
        let futureSnapshot = try snapshot(day: 9, hrv: 100)
        let current = try snapshot(day: 8, hrv: 60)

        let analysis = TrendCalculator.analyze(
            metric: .heartRateVariabilitySDNN,
            current: current,
            history: history + [futureSnapshot],
            includeTestFixtures: true,
            computedAt: Date(timeIntervalSince1970: 0)
        )

        guard case let .available(trend) = analysis else {
            Issue.record("Se esperaba una tendencia disponible.")
            return
        }

        #expect(trend.baseline.center == 46)
        #expect(trend.absoluteChangeFromBaseline == 14)
        #expect(trend.normalizedDeviation == 3.5)
        #expect(trend.direction == .abovePersonalReference)
        #expect(trend.referenceRangeMultiplier == 2)
        #expect(trend.methodVersion == "baseline-comparison-mad-threshold-v1")
    }

    @Test func reportsMissingCurrentMeasurementsWithoutCreatingAValue() throws {
        let current = try snapshot(day: 8, hrv: nil)

        let analysis = TrendCalculator.analyze(
            metric: .heartRateVariabilitySDNN,
            current: current,
            history: [],
            includeTestFixtures: true
        )

        let expectedDay = try LocalDay(year: 2026, month: 10, day: 8, timeZoneIdentifier: "America/Bogota")

        #expect(analysis == .unavailable(UnavailableMetricTrend(
            metric: .heartRateVariabilitySDNN,
            day: expectedDay,
            reason: .missingCurrentMeasurement
        )))
    }

    @Test func doesNotUseFixturesUnlessTheyAreExplicitlyIncluded() throws {
        let history = try [40, 42, 44, 46, 48, 50, 52].enumerated().map { offset, value in
            try snapshot(day: offset + 1, hrv: Double(value))
        }
        let current = try snapshot(day: 8, hrv: 60)

        let analysis = TrendCalculator.analyze(
            metric: .heartRateVariabilitySDNN,
            current: current,
            history: history
        )

        let expectedDay = try LocalDay(year: 2026, month: 10, day: 8, timeZoneIdentifier: "America/Bogota")

        #expect(analysis == .unavailable(UnavailableMetricTrend(
            metric: .heartRateVariabilitySDNN,
            day: expectedDay,
            reason: .testFixtureExcluded
        )))
    }

    private func snapshot(day: Int, hrv: Double?) throws -> DailySnapshot {
        let localDay = try LocalDay(year: 2026, month: 10, day: day, timeZoneIdentifier: "America/Bogota")
        guard let hrv else {
            return try DailySnapshot(day: localDay, metrics: [])
        }
        let metric = try DailyMetric(
            day: localDay,
            metric: .heartRateVariabilitySDNN,
            value: hrv,
            unit: .milliseconds,
            aggregation: .median,
            sampleCount: 1,
            coverage: 1,
            source: .testFixture,
            quality: .simulatedForTest,
            sourceReferences: ["simulated-test-only"]
        )
        return try DailySnapshot(day: localDay, metrics: [metric])
    }
}
