import Foundation
import Testing
@testable import BioPulseDomain

struct PersonalAnomalyForestTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let firstDay = Date(timeIntervalSince1970: 1_778_000_000)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: firstDay)!
    }

    private func normalHistory(count: Int = 40) -> [PersonalAnomalyObservation] {
        (0..<count).map { index in
            PersonalAnomalyObservation(
                day: day(index),
                hrvSDNNMilliseconds: 48 + Double(index % 5) * 0.5,
                restingHeartRateBPM: 58 + Double(index % 7) * 0.4,
                activeEnergyKilocalories: 380 + Double(index % 6) * 3
            )
        }
    }

    @Test func requiresThirtyPriorCompleteDaysAndTargetMetrics() {
        let tooLittleHistory = normalHistory(count: 29) + [
            PersonalAnomalyObservation(day: day(29), hrvSDNNMilliseconds: 49, restingHeartRateBPM: 59, activeEnergyKilocalories: 390)
        ]
        let insufficient = PersonalAnomalyForest.evaluate(tooLittleHistory, on: day(29), calendar: calendar)
        #expect(insufficient.value == nil)
        #expect(insufficient.trainingDays == 29)

        let missingTarget = PersonalAnomalyForest.evaluate(normalHistory(), on: day(40), calendar: calendar)
        #expect(missingTarget.value == nil)
        #expect(missingTarget.reason.contains("día evaluado"))
    }

    @Test func isolatesAnUnusualCombinationMoreThanAnInlier() {
        let history = normalHistory()
        let normalDay = PersonalAnomalyObservation(
            day: day(40), hrvSDNNMilliseconds: 49, restingHeartRateBPM: 59, activeEnergyKilocalories: 389
        )
        let unusualDay = PersonalAnomalyObservation(
            day: day(40), hrvSDNNMilliseconds: 120, restingHeartRateBPM: 120, activeEnergyKilocalories: 5_000
        )

        let inlier = PersonalAnomalyForest.evaluate(history + [normalDay], on: day(40), calendar: calendar)
        let outlier = PersonalAnomalyForest.evaluate(history + [unusualDay], on: day(40), calendar: calendar)

        #expect(inlier.value != nil)
        #expect(outlier.value != nil)
        #expect(outlier.value! > inlier.value!)
        #expect((0...100).contains(outlier.value!))
        #expect(outlier.reason.contains("no es una probabilidad"))
    }

    @Test func ignoresInvalidTrainingRowsAndUsesOnlyPriorDays() {
        let history = normalHistory()
        let invalid = PersonalAnomalyObservation(
            day: day(41), hrvSDNNMilliseconds: .nan, restingHeartRateBPM: 60, activeEnergyKilocalories: 400
        )
        let target = PersonalAnomalyObservation(
            day: day(40), hrvSDNNMilliseconds: 49, restingHeartRateBPM: 59, activeEnergyKilocalories: 389
        )
        let result = PersonalAnomalyForest.evaluate(history + [target, invalid], on: day(40), calendar: calendar)

        #expect(result.value != nil)
        #expect(result.trainingDays == 40)
    }

    @Test func constantPersonalHistoryProducesNeutralIsolationScore() {
        let history = (0..<40).map { index in
            PersonalAnomalyObservation(
                day: day(index),
                hrvSDNNMilliseconds: 50,
                restingHeartRateBPM: 60,
                activeEnergyKilocalories: 400
            )
        }
        let target = PersonalAnomalyObservation(
            day: day(40), hrvSDNNMilliseconds: 50, restingHeartRateBPM: 60, activeEnergyKilocalories: 400
        )

        let result = PersonalAnomalyForest.evaluate(history + [target], on: day(40), calendar: calendar)

        #expect(result.value == 50)
    }
}
