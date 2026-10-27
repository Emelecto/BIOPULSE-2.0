import Foundation
import Testing
@testable import BioPulseDomain

struct MonthlyWrappedTests {
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    private func date(_ day: Int, year: Int = 2026, month: Int = 10) -> Date { calendar.date(from: DateComponents(year: year, month: month, day: day))! }
    private func point(_ day: Int, _ value: Double) -> WrappedObservation { WrappedObservation(day: date(day), metric: .steps, value: value, source: "Test fixture") }

    @Test func deduplicatesDaysKeepsGapsAndExcludesFutureValues() {
        let summary = MonthlyWrapped(month: date(1), observations: [point(1, 100), point(1, 200), point(3, 400), point(27, 900), point(4, .nan), point(5, -5)], entries: [], now: date(26), calendar: calendar)
        #expect(summary.statistics(.steps).mean == 300)
        #expect(summary.statistics(.steps).total == 600)
        #expect(summary.statistics(.steps).count == 2)
        #expect(summary.recordedDays == 2)
        #expect(summary.days.count == 31)
        #expect(summary.series(.steps).contains { $0.day == date(2) } == false)
        #expect(summary.statistics(.sleep).mean == nil)
        #expect(summary.isPartial)
    }
    @Test func handlesLeapMonthsAndZeroWithoutInventingData() {
        let leap = date(29, year: 2024, month: 2)
        let summary = MonthlyWrapped(month: leap, observations: [WrappedObservation(day: leap, metric: .sleep, value: 0, source: "Registro manual")], entries: [], now: date(26), calendar: calendar)
        #expect(summary.days.count == 29)
        #expect(summary.statistics(.sleep).mean == 0)
        #expect(summary.statistics(.sleep).count == 1)
        #expect(!summary.isPartial)
        #expect(WrappedMetric.sleep.formatted(479.8) == "8 h 0 min")
    }
    @Test func monthBoundariesRespectTheProvidedCalendar() {
        var local = calendar; local.timeZone = TimeZone(identifier: "America/Bogota")!
        let boundary = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 2))!
        let summary = MonthlyWrapped(month: date(15), observations: [WrappedObservation(day: boundary, metric: .steps, value: 10, source: "Test fixture")], entries: [], now: date(2, year: 2026, month: 11), calendar: local)
        #expect(summary.statistics(.steps).count == 1)
        #expect(local.component(.day, from: summary.series(.steps)[0].day) == 31)
    }
    @Test func countsLocalContextWithoutDuplicatingCoveredDays() {
        let context = [WrappedMoment(id: "one", title: "Ejemplo", notes: "", occurredAt: date(1)), WrappedMoment(id: "two", title: "Ejemplo", notes: "", occurredAt: date(2)), WrappedMoment(id: "future", title: "Ejemplo", notes: "", occurredAt: date(27))]
        let summary = MonthlyWrapped(month: date(1), observations: [point(1, 100)], entries: [], additionalContext: context, now: date(26), calendar: calendar)
        #expect(summary.recordedDays == 2)
        #expect(summary.moments.count == 2)
    }
}
