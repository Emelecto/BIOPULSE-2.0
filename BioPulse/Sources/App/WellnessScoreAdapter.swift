import BioPulseDomain
import Foundation

@MainActor
extension HealthDataController {
    var personalAnomalyObservations: [PersonalAnomalyObservation] {
        let calendar = Calendar.current

        func values(for metric: HealthMetric) -> [Date: Double] {
            Dictionary(
                (dailyHistory[metric] ?? []).map { (calendar.startOfDay(for: $0.day), $0.value) },
                uniquingKeysWith: { _, latest in latest }
            )
        }

        let hrv = values(for: .heartRateVariabilitySDNN)
        let restingHeartRate = values(for: .restingHeartRate)
        let activeEnergy = values(for: .activeEnergyBurned)

        return hrv.keys.sorted().compactMap { day in
            guard let hrvValue = hrv[day],
                  let restingValue = restingHeartRate[day],
                  let energyValue = activeEnergy[day] else { return nil }
            return PersonalAnomalyObservation(
                day: day,
                hrvSDNNMilliseconds: hrvValue,
                restingHeartRateBPM: restingValue,
                activeEnergyKilocalories: energyValue
            )
        }
    }

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
