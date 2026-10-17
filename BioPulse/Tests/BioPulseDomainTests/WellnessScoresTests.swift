import Foundation
import Testing
@testable import BioPulseDomain

struct WellnessScoresTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_778_000_000)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start)!
    }
    private func values(days: Int = 23) -> [WellnessValue] {
        (0..<days).flatMap { index in
            [WellnessValue(day: day(index), metric: .sleepDuration, value: 480),
             WellnessValue(day: day(index), metric: .heartRateVariabilitySDNN, value: 50),
             WellnessValue(day: day(index), metric: .restingHeartRate, value: 60),
             WellnessValue(day: day(index), metric: .activeEnergyBurned, value: 400)]
        }
    }

    @Test func requiresPriorNights() {
        #expect(WellnessScores.sleep(values(days: 8), day: day(6), calendar: calendar).value == nil)
        #expect(WellnessScores.sleep(values(days: 8), day: day(7), calendar: calendar).value == 100)
    }

    @Test func computesSameReferenceCaseAsWeb() {
        let result = WellnessScores.bio(values(), day: day(22), calendar: calendar)
        #expect(result.value == 91)
        #expect(result.components["sleep"] == 100)
        #expect(result.components["recovery"] == 75)
    }

    @Test func requiresPersistenceForChange() {
        #expect(WellnessScores.change(values(), day: day(22), calendar: calendar).value == 0)
        let changed = values().map { item in
            if calendar.isDate(item.day, inSameDayAs: day(21)) || calendar.isDate(item.day, inSameDayAs: day(22)) {
                if item.metric == .sleepDuration { return WellnessValue(day: item.day, metric: item.metric, value: 240) }
                if item.metric == .heartRateVariabilitySDNN { return WellnessValue(day: item.day, metric: item.metric, value: 20) }
            }
            return item
        }
        #expect((WellnessScores.change(changed, day: day(22), calendar: calendar).value ?? 0) > 0)
    }
}
