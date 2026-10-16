import Testing
@testable import BioPulseDomain

struct MetricPeriodComparisonTests {
    @Test func comparesRecentMeanAgainstReferenceMedianWithoutInterpretingDirection() throws {
        let result = MetricPeriodComparisonCalculator.compare(
            recentValues: [10, 12, 14, 16],
            referenceValues: [2, 4, 6, 8, 10, 12, 100]
        )

        guard case let .available(comparison) = result else {
            Issue.record("Se esperaba una comparación con cobertura mínima.")
            return
        }

        #expect(comparison.recentAverage == 13)
        #expect(comparison.referenceMedian == 8)
        #expect(comparison.absoluteDifference == 5)
        #expect(comparison.recentObservationCount == 4)
        #expect(comparison.referenceObservationCount == 7)
    }

    @Test func filtersNonFiniteValuesAndRefusesToFillMissingObservations() {
        let result = MetricPeriodComparisonCalculator.compare(
            recentValues: [10, .nan, 12, .infinity, 14],
            referenceValues: [1, 2, 3, 4, 5, 6]
        )

        #expect(result == .insufficientData(recentObservationCount: 3, referenceObservationCount: 6))
    }

    @Test func requiresAtLeastFourRecentAndSevenReferenceDays() {
        let result = MetricPeriodComparisonCalculator.compare(
            recentValues: [1, 2, 3],
            referenceValues: [1, 2, 3, 4, 5, 6, 7]
        )

        #expect(result == .insufficientData(recentObservationCount: 3, referenceObservationCount: 7))
    }
}
