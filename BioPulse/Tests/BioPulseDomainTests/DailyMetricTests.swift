import Foundation
import Testing
@testable import BioPulseDomain

struct DailyMetricTests {
    @Test func rejectsAnImpossibleLocalDay() {
        #expect(throws: DomainValidationError.self) {
            try LocalDay(year: 2026, month: 2, day: 31, timeZoneIdentifier: "America/Bogota")
        }
    }

    @Test func rejectsAnUnexpectedUnit() throws {
        let day = try LocalDay(year: 2026, month: 10, day: 13, timeZoneIdentifier: "America/Bogota")

        do {
            try DailyMetric(
                day: day,
                metric: .heartRateVariabilitySDNN,
                value: 42,
                unit: .beatsPerMinute,
                aggregation: .median,
                sampleCount: 1,
                coverage: 1,
                source: .testFixture,
                quality: .simulatedForTest
            )
            Issue.record("Se esperaba un error por unidad incompatible.")
        } catch let error as DomainValidationError {
            #expect(error == .unitMismatch(
                metric: .heartRateVariabilitySDNN,
                expected: .milliseconds,
                received: .beatsPerMinute
            ))
        } catch {
            Issue.record("Se recibió un error inesperado: \(error)")
        }
    }

    @Test func keepsAnAbsentMetricAbsentFromTheSnapshot() throws {
        let day = try LocalDay(year: 2026, month: 10, day: 13, timeZoneIdentifier: "America/Bogota")
        let steps = try DailyMetric(
            day: day,
            metric: .stepCount,
            value: 8_421,
            unit: .count,
            aggregation: .sum,
            sampleCount: 1,
            coverage: 1,
            source: .testFixture,
            quality: .simulatedForTest
        )
        let snapshot = try DailySnapshot(day: day, metrics: [steps])

        #expect(snapshot.metric(.stepCount)?.value == 8_421)
        #expect(snapshot.metric(.sleepDuration) == nil)
    }
}
