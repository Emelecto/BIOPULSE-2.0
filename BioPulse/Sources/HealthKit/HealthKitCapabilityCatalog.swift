import HealthKit

/// Maps the BioPulse metric catalog to readable HealthKit object types.
///
/// The catalog reports type availability and authorization-request status.
/// It intentionally does not claim that a read permission was denied: HealthKit
/// keeps that distinction private for read access.
@MainActor
final class HealthKitCapabilityCatalog {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func objectType(for metric: HealthMetric) -> HKObjectType? {
        switch metric {
        case .heartRate:
            HKObjectType.quantityType(forIdentifier: .heartRate)
        case .restingHeartRate:
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .heartRateVariabilitySDNN:
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .sleepAnalysis:
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .respiratoryRate:
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)
        case .oxygenSaturation:
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        case .wristTemperature:
            if #available(iOS 16.0, *) {
                HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
            } else {
                nil
            }
        case .stepCount:
            HKObjectType.quantityType(forIdentifier: .stepCount)
        case .walkingRunningDistance:
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .activeEnergyBurned:
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .appleExerciseTime:
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        case .flightsClimbed:
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)
        case .workout:
            HKObjectType.workoutType()
        case .vo2Max:
            HKObjectType.quantityType(forIdentifier: .vo2Max)
        case .heartRateRecoveryOneMinute:
            HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)
        }
    }

    func readTypes(for tier: HealthMetricTier) -> Set<HKObjectType> {
        Set(
            HealthMetric.allCases
                .filter { $0.tier == tier }
                .compactMap(objectType(for:))
        )
    }

    func capabilitySnapshot() -> [HealthMetricCapability] {
        guard isHealthDataAvailable else {
            return HealthMetric.allCases.map {
                HealthMetricCapability(metric: $0, state: .restricted, detail: "HealthKit no está disponible en este dispositivo.")
            }
        }

        return HealthMetric.allCases.map { metric in
            guard objectType(for: metric) != nil else {
                return HealthMetricCapability(metric: metric, state: .unsupported, detail: "El tipo no está disponible en el SDK o dispositivo actual.")
            }

            return HealthMetricCapability(
                metric: metric,
                state: .readAccessIndeterminate,
                detail: "Solicita acceso y consulta muestras reales para determinar cobertura."
            )
        }
    }

    func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        let types = Set(HealthMetric.allCases.compactMap(objectType(for:)))
        return await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: Set<HKSampleType>(), read: types) { status, _ in
                continuation.resume(returning: status)
            }
        }
    }
}
