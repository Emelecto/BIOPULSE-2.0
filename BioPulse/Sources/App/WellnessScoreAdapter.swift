import BioPulseDomain
import Foundation

@MainActor
extension HealthDataController {
    func sleepScoreData(using personal: PersonalContextStore) -> ResolvedSleepValues {
        // A CSV can belong to someone else. Never blend it with this account's reports.
        ResolvedSleepValues.resolve(observed: wellnessValues, reports: isCSVImported ? [] : personal.sleepReports)
    }

    var bioScoreDay: Date {
        isCSVImported ? displayedDataDay
            : (Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now)
    }

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
