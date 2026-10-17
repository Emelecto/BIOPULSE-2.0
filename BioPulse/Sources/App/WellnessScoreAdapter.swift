import BioPulseDomain
import Foundation

@MainActor
extension HealthDataController {
    var wellnessValues: [WellnessValue] {
        let kinds: [(HealthMetric, MetricKind)] = [
            (.sleepAnalysis, .sleepDuration),
            (.heartRateVariabilitySDNN, .heartRateVariabilitySDNN),
            (.restingHeartRate, .restingHeartRate),
            (.activeEnergyBurned, .activeEnergyBurned)
        ]
        return kinds.flatMap { healthKind, domainKind in
            (dailyHistory[healthKind] ?? []).map { observation in
                WellnessValue(day: observation.day, metric: domainKind, value: observation.value)
            }
        }
    }
}
